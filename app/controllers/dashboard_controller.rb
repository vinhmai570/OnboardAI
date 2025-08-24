class DashboardController < ApplicationController
  def index
    # User dashboard - show assigned courses and progress

    # Get assigned courses
    @assigned_courses = current_user.user_course_assignments
                                   .includes(course: [:course_modules])
                                   .recent

    # Ensure UserProgress records exist for all assigned courses
    @assigned_courses.each do |assignment|
      course = assignment.course
      course.course_modules.includes(:course_steps).each do |course_module|
        course_module.course_steps.each do |step|
          step.user_progresses.find_or_create_by(user: current_user) do |progress|
            progress.status = 'not_started'
          end
        end
      end
    end

    # Get courses with progress (self-enrolled or assigned)
    courses_with_progress_ids = UserProgress.where(user: current_user)
                                           .joins(course_step: { course_module: :course })
                                           .pluck(Arel.sql('DISTINCT courses.id'))

    courses_with_progress = Course.where(id: courses_with_progress_ids)
                                 .includes(:course_modules)

    @enrolled_courses = courses_with_progress

    # Available courses (published courses not yet assigned or enrolled)
    assigned_course_ids = @assigned_courses.pluck(:course_id)
    enrolled_course_ids = @enrolled_courses.pluck(:id)
    all_taken_course_ids = (assigned_course_ids + enrolled_course_ids).uniq

    @available_courses = Course.published.where.not(id: all_taken_course_ids)

    # Calculate progress metrics for the user
    @progress_metrics = calculate_user_metrics
  end

  private

  def calculate_user_metrics
    total_assigned = @assigned_courses.count
    completed_courses = 0
    total_completion = 0.0
    total_quiz_scores = []

    # Calculate metrics for each assigned course using step-based progress display
    @assigned_courses.each do |assignment|
      course = assignment.course
      progress_data = current_user.progress_for_course(course)
      completion_percentage = progress_data[:completion_percentage]
      
      total_completion += completion_percentage
      completed_courses += 1 if completion_percentage >= 100

      # Get quiz scores for this course
      quiz_attempts = current_user.quiz_attempts_for_course(course).completed
      quiz_attempts.each do |attempt|
        total_quiz_scores << attempt.percentage_score if attempt.percentage_score
      end
    end

    # Also calculate for enrolled courses using step-based progress display
    @enrolled_courses.each do |course|
      next if @assigned_courses.any? { |a| a.course_id == course.id } # Skip if already counted in assigned
      
      progress_data = current_user.progress_for_course(course)
      completion_percentage = progress_data[:completion_percentage]
      
      total_completion += completion_percentage
      completed_courses += 1 if completion_percentage >= 100
    end

    assigned_course_ids = @assigned_courses.pluck(:course_id)
    total_courses = total_assigned + @enrolled_courses.where.not(id: assigned_course_ids).count

    {
      total_courses_assigned: total_assigned,
      total_courses_enrolled: total_courses,
      courses_completed: completed_courses,
      average_completion: total_courses > 0 ? (total_completion / total_courses).round(2) : 0,
      average_quiz_score: total_quiz_scores.any? ? (total_quiz_scores.sum / total_quiz_scores.count).round(2) : 0,
      recent_activity_count: current_user.user_progresses.where(updated_at: 1.week.ago..Time.current).count
    }
  end
end
