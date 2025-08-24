class ProgressController < ApplicationController
  before_action :require_user_role
  before_action :set_course, only: [:course_progress]
  before_action :set_course_step, only: [:start_step, :complete_step]

  def index
    @user_courses = courses_with_progress
    @overall_stats = calculate_overall_stats
  end

  def course_progress
    @course_progress = current_user.progress_for_course(@course)
    @modules_with_progress = @course.course_modules.ordered.map do |course_module|
      {
        module: course_module,
        steps_progress: course_module.course_steps.ordered.map do |step|
          progress = step.user_progresses.find_by(user: current_user)
          quiz_attempt = step.quiz&.best_attempt_for_user(current_user)

          {
            step: step,
            progress: progress,
            quiz_attempt: quiz_attempt,
            status: progress&.status || 'not_started',
            score: quiz_attempt&.percentage_score
          }
        end
      }
    end

    @quiz_summary = calculate_quiz_summary
  end

  def start_step
    progress = @course_step.user_progresses.find_or_create_by(user: current_user)

    if progress.start!
      render json: {
        success: true,
        message: 'Step started successfully',
        status: progress.status,
        started_at: progress.started_at
      }
    else
      render json: {
        success: false,
        message: 'Failed to start step',
        errors: progress.errors.full_messages
      }
    end
  end

  def complete_step
    progress = @course_step.user_progresses.find_by(user: current_user)

    unless progress
      render json: { success: false, message: 'Step not started yet' }
      return
    end

    score = params[:score]&.to_i

    if progress.complete!(score)
      # Check if this completes the entire course
      course_progress = current_user.progress_for_course(@course_step.course_module.course)
      course_completed = course_progress[:completion_percentage] >= 100

      render json: {
        success: true,
        message: 'Step completed successfully',
        status: progress.status,
        completed_at: progress.completed_at,
        score: progress.score,
        course_completed: course_completed
      }
    else
      render json: {
        success: false,
        message: 'Failed to complete step',
        errors: progress.errors.full_messages
      }
    end
  end

  def dashboard
    # Admin-only comprehensive dashboard
    unless admin?
      redirect_to progress_index_path, alert: 'Access denied.'
      return
    end

    @total_users = User.count
    @total_courses = Course.count
    @total_quizzes = Quiz.count

    # Recent activity
    @recent_completions = UserProgress.completed
                                     .includes(:user, course_step: { course_module: :course })
                                     .order(completed_at: :desc)
                                     .limit(10)

    @recent_quiz_attempts = QuizAttempt.completed
                                      .includes(:user, quiz: { course_step: { course_module: :course } })
                                      .order(completed_at: :desc)
                                      .limit(10)

    # Course performance overview
    @course_stats = Course.all.map do |course|
      enrolled_users = User.joins(user_progresses: { course_step: { course_module: :course } })
                          .where(courses: { id: course.id })
                          .distinct
                          .count

      completed_users = User.joins(user_progresses: { course_step: { course_module: :course } })
                           .where(courses: { id: course.id })
                           .group('users.id')
                           .having('COUNT(CASE WHEN user_progresses.status = ? THEN 1 END) = COUNT(course_steps.id)', 'completed')
                           .count
                           .keys
                           .length

      avg_quiz_score = QuizAttempt.joins(quiz: { course_step: { course_module: :course } })
                                 .where(courses: { id: course.id }, status: 'completed')
                                 .where.not(score: nil, total_points: nil)
                                 .average('(quiz_attempts.score::float / quiz_attempts.total_points::float * 100)')
                                 &.round(2) || 0

      {
        course: course,
        enrolled_users: enrolled_users,
        completed_users: completed_users,
        completion_rate: enrolled_users.zero? ? 0 : (completed_users.to_f / enrolled_users * 100).round(2),
        avg_quiz_score: avg_quiz_score,
        total_steps: course.course_steps.count,
        total_quizzes: Quiz.joins(course_step: { course_module: :course }).where(courses: { id: course.id }).count
      }
    end

    # User leaderboard
    @top_learners = User.joins(:quiz_attempts)
                       .where(quiz_attempts: { status: 'completed' })
                       .group('users.id', 'users.name', 'users.email')
                       .order('AVG(quiz_attempts.score::float / quiz_attempts.total_points::float * 100) DESC')
                       .limit(10)
                       .select('users.*, AVG(quiz_attempts.score::float / quiz_attempts.total_points::float * 100) as avg_score')
  end

  private



  def set_course
    @course = Course.find(params[:course_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to progress_index_path, alert: 'Course not found.'
  end

  def set_course_step
    @course_step = CourseStep.find(params[:course_step_id])
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, message: 'Course step not found' }
  end

  def courses_with_progress
    # Use select with distinct on id to avoid JSON column equality issues
    course_ids = Course.joins(course_modules: { course_steps: :user_progresses })
                      .where(user_progresses: { user: current_user })
                      .select('DISTINCT courses.id')
                      .pluck(:id)
    
    Course.where(id: course_ids)
          .includes(course_modules: :course_steps)
          .map do |course|
            progress_data = current_user.progress_for_course(course)
            quiz_completion_rate = current_user.quiz_completion_rate_for_course(course)

            {
              course: course,
              progress_percentage: progress_data[:completion_percentage],
              completed_steps: progress_data[:completed_steps],
              total_steps: progress_data[:total_steps],
              quiz_completion_rate: quiz_completion_rate,
              last_activity: UserProgress.where(
                user: current_user,
                course_step: CourseStep.joins(course_module: :course).where(courses: { id: course.id })
              ).maximum(:updated_at)
            }
          end
  end

  def calculate_overall_stats
    # Use distinct on id to avoid JSON column equality issues
    total_courses = Course.joins(course_modules: { course_steps: :user_progresses })
                         .where(user_progresses: { user: current_user })
                         .select('DISTINCT courses.id')
                         .count

    completed_courses = current_user.total_courses_completed

    total_quizzes_taken = current_user.quiz_attempts.completed.count
    avg_quiz_score = current_user.average_quiz_score

    total_time_spent = UserProgress.where(user: current_user, status: 'completed')
                                  .where.not(started_at: nil, completed_at: nil)
                                  .sum { |p| ((p.completed_at - p.started_at) / 3600).round(2) } # in hours

    {
      courses_enrolled: total_courses,
      courses_completed: completed_courses,
      completion_rate: total_courses.zero? ? 0 : (completed_courses.to_f / total_courses * 100).round(2),
      quizzes_taken: total_quizzes_taken,
      avg_quiz_score: avg_quiz_score,
      total_time_spent_hours: total_time_spent,
      total_steps_completed: UserProgress.where(user: current_user, status: 'completed').count
    }
  end

  def calculate_quiz_summary
    return {} unless @course

    quiz_attempts = current_user.quiz_attempts_for_course(@course).completed

    return {} if quiz_attempts.empty?

    {
      total_quizzes: Quiz.joins(course_step: { course_module: :course }).where(courses: { id: @course.id }).count,
      completed_quizzes: quiz_attempts.count,
      avg_score: quiz_attempts.average('quiz_attempts.score::float / quiz_attempts.total_points::float * 100')&.round(2) || 0,
      best_score: quiz_attempts.maximum('quiz_attempts.score::float / quiz_attempts.total_points::float * 100')&.round(2) || 0,
      total_time_spent: quiz_attempts.sum(&:time_spent_minutes),
      recent_attempts: quiz_attempts.includes(:quiz).order(completed_at: :desc).limit(5)
    }
  end
end
