class Admin::QuizzesController < ApplicationController
  before_action :ensure_admin
  before_action :set_quiz, only: [:show, :edit, :update, :destroy, :analytics, :regenerate]

  def index
    @quizzes = Quiz.includes(course_step: { course_module: :course })
                   .joins(course_step: { course_module: :course })
                   .order('courses.title, course_modules.order_position, course_steps.order_position')

    # Filter by course if specified
    if params[:course_id].present?
      @quizzes = @quizzes.where(courses: { id: params[:course_id] })
      @selected_course = Course.find(params[:course_id])
    end

    @courses = Course.joins(course_modules: { course_steps: :quiz }).distinct
  end

  def show
    @course = @quiz.course_step.course_module.course
    @course_step = @quiz.course_step
    @course_module = @course_step.course_module

    @questions = @quiz.quiz_questions.ordered.includes(:quiz_question_options)
    @recent_attempts = @quiz.quiz_attempts.includes(:user).completed.recent.limit(10)

    # Quiz statistics
    @stats = {
      total_attempts: @quiz.quiz_attempts.count,
      completed_attempts: @quiz.quiz_attempts.completed.count,
      average_score: @quiz.average_score,
      completion_rate: @quiz.completion_rate,
      average_time: average_completion_time
    }
  end

  def edit
    @course = @quiz.course_step.course_module.course
    @course_step = @quiz.course_step
    @questions = @quiz.quiz_questions.ordered.includes(:quiz_question_options)
  end

  def update
    if @quiz.update(quiz_params)
      redirect_to admin_quiz_path(@quiz), notice: 'Quiz updated successfully.'
    else
      @course = @quiz.course_step.course_module.course
      @course_step = @quiz.course_step
      @questions = @quiz.quiz_questions.ordered.includes(:quiz_question_options)
      render :edit
    end
  end

  def destroy
    course_id = @quiz.course_step.course_module.course.id
    @quiz.destroy
    redirect_to admin_quizzes_path(course_id: course_id), notice: 'Quiz deleted successfully.'
  end

  def analytics
    @course = @quiz.course_step.course_module.course
    @course_step = @quiz.course_step

    # Comprehensive analytics
    @analytics = {
      # Basic stats
      total_attempts: @quiz.quiz_attempts.count,
      unique_users: @quiz.quiz_attempts.distinct.count(:user_id),
      completed_attempts: @quiz.quiz_attempts.completed.count,
      abandoned_attempts: @quiz.quiz_attempts.where(status: 'abandoned').count,

      # Score analytics
      average_score: @quiz.average_score,
      highest_score: @quiz.quiz_attempts.completed.maximum(:score) || 0,
      lowest_score: @quiz.quiz_attempts.completed.minimum(:score) || 0,
      passing_rate: passing_rate,

      # Time analytics
      average_time: average_completion_time,
      fastest_time: fastest_completion_time,
      slowest_time: slowest_completion_time,

      # Question analytics
      question_difficulty: question_difficulty_analysis,
      most_missed_questions: most_missed_questions,

      # User performance
      top_performers: top_performers,
      users_needing_help: users_needing_help
    }

    @recent_attempts = @quiz.quiz_attempts.includes(:user)
                           .completed
                           .order(completed_at: :desc)
                           .limit(20)

    # Data for charts (you can use this with Chart.js)
    @score_distribution = score_distribution_data
    @completion_over_time = completion_over_time_data
  end

  def regenerate
    # Regenerate quiz using AI - useful if content has been updated
    course_module = @quiz.course_step.course_module

    # Get document context
    course = course_module.course
    conversation = course.conversation
    document_context = extract_document_context(conversation) if conversation

    # Generate new quiz data
    quiz_data = OpenaiService.generate_quiz_json(course_module, document_context&.dig(:chunks) || [])

    if quiz_data && quiz_data['quiz']
      # Remove old questions
      @quiz.quiz_questions.destroy_all

      # Update quiz properties
      quiz_info = quiz_data['quiz']
      @quiz.update!(
        title: quiz_info['title'] || @quiz.title,
        description: quiz_info['description'] || @quiz.description,
        total_points: quiz_info['total_points'] || @quiz.total_points,
        time_limit_minutes: quiz_info['time_limit_minutes'] || @quiz.time_limit_minutes
      )

      # Create new questions
      questions_created = create_quiz_questions_from_json(@quiz, quiz_info['questions'])

      if questions_created > 0
        redirect_to admin_quiz_path(@quiz), notice: "Quiz regenerated successfully with #{questions_created} new questions."
      else
        redirect_to admin_quiz_path(@quiz), alert: 'Quiz regeneration failed - no questions were created.'
      end
    else
      redirect_to admin_quiz_path(@quiz), alert: 'Quiz regeneration failed - could not generate new content.'
    end
  end

  private

  def set_quiz
    @quiz = Quiz.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_quizzes_path, alert: 'Quiz not found.'
  end

  def ensure_admin
    unless current_user&.admin?
      redirect_to root_path, alert: 'Access denied. Admin privileges required.'
    end
  end

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end

  def quiz_params
    params.require(:quiz).permit(:title, :description, :total_points, :time_limit_minutes)
  end

  def average_completion_time
    completed_attempts = @quiz.quiz_attempts.completed
                             .where.not(started_at: nil, completed_at: nil)

    return 0 if completed_attempts.empty?

    total_minutes = completed_attempts.sum do |attempt|
      ((attempt.completed_at - attempt.started_at) / 60).round
    end

    (total_minutes.to_f / completed_attempts.count).round(1)
  end

  def fastest_completion_time
    @quiz.quiz_attempts.completed
         .where.not(started_at: nil, completed_at: nil)
         .minimum('EXTRACT(EPOCH FROM (completed_at - started_at))')
         &./(60)
         &.round(1) || 0
  end

  def slowest_completion_time
    @quiz.quiz_attempts.completed
         .where.not(started_at: nil, completed_at: nil)
         .maximum('EXTRACT(EPOCH FROM (completed_at - started_at))')
         &./(60)
         &.round(1) || 0
  end

  def passing_rate
    total_completed = @quiz.quiz_attempts.completed.count
    return 0 if total_completed.zero?

    passed = @quiz.quiz_attempts.completed.where('(score::float / total_points::float * 100) >= 70').count
    (passed.to_f / total_completed * 100).round(2)
  end

  def question_difficulty_analysis
    @quiz.quiz_questions.map do |question|
      total_responses = question.quiz_responses
                               .joins(:quiz_attempt)
                               .where(quiz_attempts: { status: 'completed' })
                               .count

      correct_responses = question.quiz_responses
                                 .joins(:quiz_attempt)
                                 .where(quiz_attempts: { status: 'completed' }, is_correct: true)
                                 .count

      success_rate = total_responses.zero? ? 0 : (correct_responses.to_f / total_responses * 100).round(2)

      {
        question_id: question.id,
        question_text: question.question_text.truncate(60),
        success_rate: success_rate,
        difficulty: case success_rate
                   when 0..30 then 'Very Hard'
                   when 31..50 then 'Hard'
                   when 51..70 then 'Medium'
                   when 71..85 then 'Easy'
                   else 'Very Easy'
                   end,
        total_responses: total_responses
      }
    end
  end

  def most_missed_questions
    question_difficulty_analysis.sort_by { |q| q[:success_rate] }.first(3)
  end

  def top_performers
    @quiz.quiz_attempts
         .joins(:user)
         .completed
         .order(score: :desc)
         .limit(5)
         .map { |attempt| { user: attempt.user, score: attempt.percentage_score, completed_at: attempt.completed_at } }
  end

  def users_needing_help
    @quiz.quiz_attempts
         .joins(:user)
         .completed
         .where('(score::float / total_points::float * 100) < 70')
         .order(score: :asc)
         .limit(5)
         .map { |attempt| { user: attempt.user, score: attempt.percentage_score, completed_at: attempt.completed_at } }
  end

  def score_distribution_data
    score_ranges = ['0-20%', '21-40%', '41-60%', '61-80%', '81-100%']
    completed_attempts = @quiz.quiz_attempts.completed.where.not(score: nil, total_points: nil)

    score_ranges.map do |range|
      case range
      when '0-20%'
        count = completed_attempts.where('(score::float / total_points::float * 100) <= 20').count
      when '21-40%'
        count = completed_attempts.where('(score::float / total_points::float * 100) > 20 AND (score::float / total_points::float * 100) <= 40').count
      when '41-60%'
        count = completed_attempts.where('(score::float / total_points::float * 100) > 40 AND (score::float / total_points::float * 100) <= 60').count
      when '61-80%'
        count = completed_attempts.where('(score::float / total_points::float * 100) > 60 AND (score::float / total_points::float * 100) <= 80').count
      when '81-100%'
        count = completed_attempts.where('(score::float / total_points::float * 100) > 80').count
      end

      { range: range, count: count }
    end
  end

  def completion_over_time_data
    # Get completions by day for the last 30 days
    30.downto(0).map do |days_ago|
      date = days_ago.days.ago.to_date
      count = @quiz.quiz_attempts
                   .completed
                   .where(completed_at: date.beginning_of_day..date.end_of_day)
                   .count

      { date: date.strftime('%m/%d'), count: count }
    end
  end

  def extract_document_context(conversation)
    return { documents: [], chunks: [] } unless conversation

    # Extract document mentions from conversation messages
    mentioned_document_ids = Set.new
    conversation.chat_messages.where(message_type: 'user_prompt').each do |message|
      document_ids = extract_document_mentions(message.content)
      mentioned_document_ids.merge(document_ids)
    end

    return { documents: [], chunks: [] } if mentioned_document_ids.empty?

    # Load documents and their chunks
    documents = Document.where(id: mentioned_document_ids.to_a)
    chunks = DocumentChunk.where(document: documents).order(:chunk_index)

    { documents: documents, chunks: chunks }
  end

  def extract_document_mentions(text)
    document_ids = []

    # Find @filename mentions and match to documents
    mentions = text.scan(/@([a-zA-Z0-9_\-\.]+)/)
    mentions.each do |match|
      filename = match[0]

      # Try to find document by name (flexible matching)
      doc = Document.where("name ILIKE ?", "%#{filename}%").first
      document_ids << doc.id if doc
    end

    document_ids
  end

  def create_quiz_questions_from_json(quiz, questions_data)
    return 0 unless questions_data.is_a?(Array)

    questions_created = 0

    questions_data.each_with_index do |question_data, index|
      begin
        question = quiz.quiz_questions.create!(
          question_text: question_data['question_text'],
          question_type: question_data['question_type'],
          points: question_data['points'] || 10,
          order_position: question_data['order_position'] || (index + 1),
          explanation: question_data['explanation']
        )

        if question_data['options'].is_a?(Array)
          question_data['options'].each do |option_data|
            question.quiz_question_options.create!(
              option_text: option_data['option_text'],
              is_correct: option_data['is_correct'],
              order_position: option_data['order_position'] || 1
            )
          end
        end

        questions_created += 1
      rescue => e
        Rails.logger.error "Error creating question #{index + 1}: #{e.message}"
        next
      end
    end

    questions_created
  end
end
