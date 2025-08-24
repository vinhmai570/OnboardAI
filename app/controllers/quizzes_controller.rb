class QuizzesController < ApplicationController
  before_action :set_quiz, only: [:show, :start, :submit, :results, :save_progress]
  before_action :set_quiz_attempt, only: [:show, :submit, :results, :save_progress]

  def show
    @course = @quiz.course_step.course_module.course
    @course_step = @quiz.course_step
    @course_module = @course_step.course_module

    # Check if user has access to this course (basic check)
    unless user_has_access_to_course?(@course)
      respond_to do |format|
        format.html { redirect_to courses_path, alert: 'You do not have access to this course.' }
        format.json { render json: { error: 'You do not have access to this course.' }, status: :forbidden }
      end
      return
    end

    # Get or create current attempt
    @current_attempt = current_quiz_attempt

    # Debug logging
    Rails.logger.info "Quiz show for quiz #{@quiz.id}, user #{current_user&.id}"
    Rails.logger.info "Current attempt found: #{@current_attempt&.id || 'none'}"
    Rails.logger.info "All attempts for user: #{@quiz.quiz_attempts.where(user: current_user).pluck(:id, :status)}"

    if @current_attempt
      # Resume existing attempt
      Rails.logger.info "Showing quiz-taking interface for attempt #{@current_attempt.id}"
      @questions = @quiz.quiz_questions.ordered.includes(:quiz_question_options)
      @responses = @current_attempt.quiz_responses.includes(:quiz_question, :quiz_question_option)
      @response_by_question = @responses.index_by(&:quiz_question_id)

      # Check time limit
      if @current_attempt.time_limit_exceeded?
        @current_attempt.abandon!
        respond_to do |format|
          format.html { redirect_to quiz_results_path(@quiz), notice: 'Quiz time limit exceeded. Your attempt has been saved.' }
          format.json { render json: { error: 'Quiz time limit exceeded.' }, status: :bad_request }
        end
        return
      end
    else
      # Show quiz introduction
      Rails.logger.info "Showing quiz introduction screen"
      @best_attempt = @quiz.best_attempt_for_user(current_user)
      @user_attempts = @quiz.attempts_for_user(current_user).recent.limit(5)
    end

    respond_to do |format|
      format.html # Regular HTML view
      format.json {
        if @current_attempt
          # Return quiz taking data
          responses_data = {}
          @response_by_question.each do |question_id, response|
            responses_data[question_id] = {
              selected_option_id: response.quiz_question_option_id,
              answer_text: response.response_text
            }
          end

          render json: {
            quiz: quiz_json_data,
            current_attempt: {
              id: @current_attempt.id,
              status: @current_attempt.status,
              remaining_time_minutes: @current_attempt.remaining_time_minutes
            },
            questions: @questions.map { |q| question_json_data(q) },
            responses: responses_data
          }
        else
          # Return quiz introduction data
          questions = @quiz.quiz_questions.ordered.includes(:quiz_question_options)
          render json: {
            quiz: quiz_json_data,
            current_attempt: nil,
            questions: questions.map { |q| question_json_data(q) },
            best_attempt: @best_attempt ? attempt_json_data(@best_attempt) : nil,
            user_attempts: @user_attempts.map { |a| attempt_json_data(a) }
          }
        end
      }
    end
  end

  def start
    # Handle GET requests by redirecting to quiz show page
    if request.get?
      respond_to do |format|
        format.html { redirect_to quiz_path(@quiz), notice: 'Please use the "Start Quiz" button to begin.' }
        format.json { render json: { success: false, message: 'Use POST to start quiz' }, status: :method_not_allowed }
      end
      return
    end

    # Check if user already has an active attempt
    active_attempt = @quiz.quiz_attempts.where(user: current_user, status: 'in_progress').first

    if active_attempt
      respond_to do |format|
        format.html { redirect_to quiz_path(@quiz), notice: 'Resuming your quiz attempt.' }
        format.json { render json: { success: true, message: 'Resuming quiz attempt', attempt_id: active_attempt.id } }
      end
      return
    end

    begin
      # Create new attempt
      @quiz_attempt = @quiz.quiz_attempts.create!(
        user: current_user,
        status: 'in_progress',
        started_at: Time.current
      )

      # Log for debugging
      Rails.logger.info "Created quiz attempt #{@quiz_attempt.id} for user #{current_user.id} on quiz #{@quiz.id}"

      # Initialize progress tracking for the course step
      progress = @quiz.course_step.user_progresses.find_or_create_by(user: current_user)
      progress.start! if progress.not_started?

      # Ensure attempt is saved and reload
      @quiz_attempt.reload

      respond_to do |format|
        format.html { redirect_to quiz_path(@quiz), notice: 'Quiz started! Good luck!' }
        format.json { render json: { success: true, message: 'Quiz started successfully!', attempt_id: @quiz_attempt.id } }
      end
    rescue StandardError => e
      Rails.logger.error "Failed to start quiz: #{e.message}"
      respond_to do |format|
        format.html { redirect_to quiz_path(@quiz), alert: 'Failed to start quiz. Please try again.' }
        format.json { render json: { success: false, message: 'Failed to start quiz. Please try again.' }, status: :unprocessable_entity }
      end
    end
  end

  def submit
    unless @current_attempt&.in_progress?
      respond_to do |format|
        format.html { redirect_to quiz_path(@quiz), alert: 'No active quiz attempt found.' }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("quiz-container", html: "<div class='bg-red-50 border border-red-200 rounded-lg p-6 text-center'><h3 class='text-red-800 font-bold mb-2'>Error</h3><p class='text-red-700'>No active quiz attempt found.</p></div>") }
        format.json { render json: { success: false, message: 'No active quiz attempt found.' }, status: :bad_request }
      end
      return
    end

    begin
      # Process submitted answers
      questions_data = params[:questions] || {}

      questions_data.each do |question_id, answer_data|
        question = @quiz.quiz_questions.find_by(id: question_id)
        next unless question

        case question.question_type
        when 'multiple_choice', 'true_false'
          selected_option_id = answer_data[:selected_option_id]
          @current_attempt.answer_question!(question, selected_option_id) if selected_option_id.present?

        when 'short_answer'
          answer_text = answer_data[:answer_text]
          @current_attempt.answer_question!(question, nil, answer_text) if answer_text.present?
        end
      end

      # Complete the attempt
      @current_attempt.complete!

      # Update course step progress
      progress = @quiz.course_step.user_progresses.find_or_create_by(user: current_user)

      # Start the step if it hasn't been started yet
      progress.start! if progress.not_started?

            # NEW LOGIC: Mark ALL steps in the module as completed if quiz is passed
      if @current_attempt.passed?
        # Get the module that contains this quiz step
        course_module = @quiz.course_step.course_module
        course = course_module.course

        # Mark ALL steps in this module as completed for the user
        course_module.complete_all_steps_for_user!(current_user, @current_attempt.percentage_score)

        # Update legacy Progress model if it exists
        course_progress_data = current_user.progress_for_course(course)
        legacy_progress = current_user.progresses.find_by(course: course)
        if legacy_progress
          legacy_progress.update!(
            completed_steps: course_progress_data[:completed_steps],
            quiz_scores: legacy_progress.quiz_scores.merge(@quiz.id => @current_attempt.percentage_score)
          )
        end

        Rails.logger.info "Quiz passed! Module '#{course_module.title}' completed - #{course_module.course_steps.count} steps marked complete. Overall course progress: #{course_progress_data[:completion_percentage]}% (#{course_progress_data[:completed_steps]}/#{course_progress_data[:total_steps]} steps)"
      else
        # Even if quiz is failed, ensure step is marked as in_progress (user has attempted it)
        progress.start! if progress.not_started?
        Rails.logger.info "Quiz not passed (#{@current_attempt.percentage_score}%), step remains in progress. Module completion not triggered."
      end

      respond_to do |format|
        format.html { redirect_to quiz_results_path(@quiz), notice: 'Quiz submitted successfully!' }
        format.turbo_stream {
          Rails.logger.info "Rendering turbo stream response for quiz #{@quiz.id}"

          # Prepare results data for turbo stream
          @completed_attempt = @current_attempt
          @questions_with_responses = @quiz.quiz_questions.ordered.map do |question|
            response = @completed_attempt.quiz_responses.find_by(quiz_question: question)
            {
              question: question,
              response: response,
              user_answer: response&.response_text_display,
              correct_answer: question.correct_options.map(&:option_text).join(', '),
              is_correct: response&.is_correct || false,
              points_earned: response&.points_earned || 0,
              explanation: question.explanation
            }
          end

          Rails.logger.info "Quiz results: score=#{@completed_attempt.percentage_score}%, passed=#{@completed_attempt.passed?}"

          render turbo_stream: turbo_stream.replace("quiz-container", partial: "quiz_results", locals: {
            quiz: @quiz,
            attempt: @completed_attempt,
            questions_with_responses: @questions_with_responses,
            course: @quiz.course_step.course_module.course,
            course_step: @quiz.course_step
          })
        }
        format.json { render json: { success: true, message: 'Quiz submitted successfully!', attempt_id: @current_attempt.id } }
      end
    rescue StandardError => e
      Rails.logger.error "Failed to submit quiz: #{e.message}"
      respond_to do |format|
        format.html { redirect_to quiz_path(@quiz), alert: 'Failed to submit quiz. Please try again.' }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("quiz-container", html: "<div class='bg-red-50 border border-red-200 rounded-lg p-6 text-center'><h3 class='text-red-800 font-bold mb-2'>Error</h3><p class='text-red-700'>Failed to submit quiz. Please try again.</p></div>") }
        format.json { render json: { success: false, message: 'Failed to submit quiz. Please try again.' }, status: :unprocessable_entity }
      end
    end
  end

  def results
    @completed_attempt = @quiz.quiz_attempts
                             .where(user: current_user, status: 'completed')
                             .order(created_at: :desc)
                             .first

    unless @completed_attempt
      respond_to do |format|
        format.html { redirect_to quiz_path(@quiz), alert: 'No completed quiz attempt found.' }
        format.json { render json: { error: 'No completed quiz attempt found.' }, status: :not_found }
      end
      return
    end

    @course = @quiz.course_step.course_module.course
    @course_step = @quiz.course_step
    @questions_with_responses = @quiz.quiz_questions.ordered.map do |question|
      response = @completed_attempt.quiz_responses.find_by(quiz_question: question)
      {
        question: question,
        response: response,
        user_answer: response&.response_text_display,
        correct_answer: question.correct_options.map(&:option_text).join(', '),
        is_correct: response&.is_correct || false,
        points_earned: response&.points_earned || 0,
        explanation: question.explanation
      }
    end

    @all_user_attempts = @quiz.attempts_for_user(current_user).completed.recent

    respond_to do |format|
      format.html # Regular HTML view
      format.json {
        render json: {
          attempt: {
            id: @completed_attempt.id,
            score: @completed_attempt.score,
            total_points: @completed_attempt.total_points,
            percentage_score: @completed_attempt.percentage_score,
            passed: @completed_attempt.passed?,
            time_spent_minutes: @completed_attempt.time_spent_minutes,
            completed_at: @completed_attempt.completed_at
          },
          questions_with_responses: @questions_with_responses.map do |item|
            {
              question_id: item[:question].id,
              question_text: item[:question].question_text,
              question_type: item[:question].question_type,
              points: item[:question].points,
              user_answer: item[:user_answer],
              correct_answer: item[:correct_answer],
              is_correct: item[:is_correct],
              points_earned: item[:points_earned],
              explanation: item[:explanation]
            }
          end
        }
      }
    end
  end

  def save_progress
    unless @current_attempt&.in_progress?
      render json: { success: false, message: 'No active quiz attempt found.' }, status: :bad_request
      return
    end

    begin
      # Process submitted answers for auto-save
      questions_data = params[:questions] || {}

      questions_data.each do |question_id, answer_data|
        question = @quiz.quiz_questions.find_by(id: question_id)
        next unless question

        # Find or create response for this question
        response = @current_attempt.quiz_responses.find_or_initialize_by(quiz_question: question)

        case question.question_type
        when 'multiple_choice', 'true_false'
          selected_option_id = answer_data[:selected_option_id]
          if selected_option_id.present?
            option = question.quiz_question_options.find_by(id: selected_option_id)
            if option
              response.quiz_question_option = option
              response.response_text = nil
              response.points_earned = 0  # Set to 0 for progress saving, will be calculated on submission
              response.save!
            end
          end

        when 'short_answer'
          answer_text = answer_data[:answer_text]
          if answer_text.present? && answer_text.strip.length > 0
            response.quiz_question_option = nil
            response.response_text = answer_text.strip
            response.points_earned = 0  # Set to 0 for progress saving, will be calculated on submission
            response.save!
          elsif response.persisted?
            # Delete existing response if answer is now empty
            response.destroy
          end
        end
      end

      render json: { success: true, message: 'Progress saved successfully!' }
    rescue StandardError => e
      Rails.logger.error "Failed to save quiz progress: #{e.message}"
      render json: { success: false, message: 'Failed to save progress.' }, status: :unprocessable_entity
    end
  end

  def check_answer
    unless @current_attempt&.in_progress?
      render json: { success: false, message: 'No active quiz attempt found.' }, status: :bad_request
      return
    end

    question_id = params[:question_id]
    question = @quiz.quiz_questions.find_by(id: question_id)

    unless question
      render json: { success: false, message: 'Question not found.' }, status: :not_found
      return
    end

    begin
      feedback = case question.question_type
      when 'multiple_choice', 'true_false'
        selected_option_id = params[:selected_option_id]
        if selected_option_id.present?
          selected_option = question.quiz_question_options.find_by(id: selected_option_id)
          if selected_option
            is_correct = selected_option.is_correct
            correct_options = question.quiz_question_options.where(is_correct: true)

            {
              is_correct: is_correct,
              feedback_type: is_correct ? 'correct' : 'incorrect',
              message: is_correct ? 'Correct!' : 'Incorrect.',
              correct_answer: correct_options.pluck(:option_text).join(', '),
              selected_answer: selected_option.option_text,
              explanation: question.explanation,
              points_earned: is_correct ? question.points : 0,
              total_points: question.points
            }
          else
            { success: false, message: 'Selected option not found.' }
          end
        else
          { success: false, message: 'No option selected.' }
        end

      when 'short_answer'
        answer_text = params[:answer_text]&.strip
        if answer_text.present?
          # For short answer, we'll do a simple check against expected answers
          # This could be enhanced with more sophisticated matching
          is_correct = question.check_short_answer(answer_text)

          {
            is_correct: is_correct,
            feedback_type: is_correct ? 'correct' : 'needs_review',
            message: is_correct ? 'Great answer!' : 'Your answer has been recorded and will be reviewed.',
            your_answer: answer_text,
            explanation: question.explanation,
            points_earned: is_correct ? question.points : 0,
            total_points: question.points
          }
        else
          { success: false, message: 'No answer provided.' }
        end
      else
        { success: false, message: 'Unknown question type.' }
      end

      if feedback[:success] == false
        render json: feedback, status: :bad_request
      else
        render json: { success: true, feedback: feedback }
      end

    rescue StandardError => e
      Rails.logger.error "Failed to check answer: #{e.message}"
      render json: { success: false, message: 'Failed to check answer.' }, status: :unprocessable_entity
    end
  end

  private

  def set_quiz
    @quiz = Quiz.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to courses_path, alert: 'Quiz not found.'
  end

  def set_quiz_attempt
    @current_attempt = current_quiz_attempt
  end

  def current_quiz_attempt
    return nil unless @quiz && current_user

    # Force reload from database to avoid caching issues
    @quiz.quiz_attempts.where(user: current_user, status: 'in_progress').reload.first
  end





  def user_has_access_to_course?(course)
    # Basic access check - you might want to implement more sophisticated logic
    # For now, allow all logged-in users to access all courses
    true
  end

  def quiz_json_data
    {
      id: @quiz.id,
      title: @quiz.title || @quiz.course_step.title,
      course_title: @quiz.course_step.course_module.course.title,
      question_count: @quiz.quiz_questions.count,
      total_points: @quiz.quiz_questions.sum(:points),
      time_limit_minutes: @quiz.time_limit_minutes
    }
  end

  def question_json_data(question)
    {
      id: question.id,
      question_text: question.question_text,
      question_type: question.question_type,
      points: question.points,
      options: question.quiz_question_options.ordered.map do |option|
        {
          id: option.id,
          option_text: option.option_text,
          is_correct: option.is_correct
        }
      end
    }
  end

  def attempt_json_data(attempt)
    {
      id: attempt.id,
      score: attempt.score,
      total_points: attempt.total_points,
      percentage_score: attempt.percentage_score,
      passed: attempt.passed?,
      completed_at: attempt.completed_at,
      time_spent_minutes: attempt.time_spent_minutes
    }
  end
end
