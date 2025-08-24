class Admin::ProgressAnalyticsController < ApplicationController
  before_action :require_admin

  def index
    # Overall platform analytics
    @analytics = {
      total_enrolled_users: total_enrolled_users,
      total_course_completions: total_course_completions,
      average_completion_rate: average_completion_rate,
      active_users_this_month: active_users_this_month,
      courses_with_progress: courses_with_progress
    }

    # Course-specific analytics
    @course_analytics = Course.published.includes(:user_course_assignments, course_modules: { course_steps: :user_progresses })
                              .map { |course| course_analytics_data(course) }
                              .sort_by { |data| -data[:completion_rate] }

    # User performance analytics
    @user_analytics = User.users.includes(:user_progresses, :user_course_assignments)
                          .map { |user| user_analytics_data(user) }
                          .reject { |data| data[:total_courses].zero? }
                          .sort_by { |data| -data[:overall_completion_percentage] }

    # Recent activity
    @recent_completions = UserProgress.completed
                                     .includes(:user, course_step: { course_module: :course })
                                     .order(completed_at: :desc)
                                     .limit(20)

    # Progress over time data for charts
    @progress_over_time_data = progress_over_time_data
    @course_completion_distribution = course_completion_distribution
    @user_engagement_data = user_engagement_data
  end

  def course_details
    @course = Course.find(params[:course_id])
    @course_modules = @course.course_modules.includes(course_steps: :user_progresses).ordered

    # Detailed course analytics
    @course_analytics = {
      total_assigned: @course.user_course_assignments.count,
      total_started: users_who_started_course(@course).count,
      total_completed: users_who_completed_course(@course).count,
      average_completion_time: average_completion_time_for_course(@course),
      completion_rate: course_completion_rate(@course),
      drop_off_analysis: course_drop_off_analysis(@course)
    }

    # Step-by-step analytics
    @step_analytics = @course.course_modules.flat_map(&:course_steps).map do |step|
      {
        step: step,
        completion_rate: UserProgress.completion_rate_for_course_step(step),
        average_score: UserProgress.average_score_for_course_step(step),
        average_time: UserProgress.average_time_for_course_step(step),
        users_struggling: users_struggling_with_step(step)
      }
    end

    # User progress details for this course
    @user_progress_details = user_progress_for_course(@course)
  end

  def user_details
    @user = User.find(params[:user_id])
    @user_courses = @user.user_course_assignments.includes(:course).map(&:course)

    # User analytics
    @user_analytics = {
      total_courses_assigned: @user_courses.count,
      completed_courses: @user_courses.select { |course| @user.course_completed?(course) }.count,
      in_progress_courses: @user_courses.reject { |course| @user.course_completed?(course) }.count,
      overall_completion_percentage: calculate_user_overall_completion(@user),
      average_quiz_score: @user.average_quiz_score,
      total_time_spent: total_time_spent_by_user(@user),
      learning_streak: calculate_learning_streak(@user)
    }

    # Course-by-course progress
    @course_progress = @user_courses.map do |course|
      progress_data = @user.progress_for_course(course)
      {
        course: course,
        completion_percentage: progress_data[:completion_percentage],
        completed_steps: progress_data[:completed_steps],
        total_steps: progress_data[:total_steps],
        in_progress_steps: progress_data[:in_progress_steps],
        estimated_completion_time: estimate_completion_time(@user, course),
        recent_activity: recent_activity_for_user_course(@user, course)
      }
    end

    # Learning timeline
    @learning_timeline = @user.user_progresses.completed
                              .includes(course_step: { course_module: :course })
                              .order(completed_at: :desc)
                              .limit(50)
  end

  def export_analytics
    # Export analytics data as CSV or JSON
    respond_to do |format|
      format.csv { send_data generate_csv_export, filename: "progress_analytics_#{Date.current}.csv" }
      format.json { render json: export_data }
    end
  end

  private

  def total_enrolled_users
    User.joins(:user_course_assignments).distinct.count
  end

  def total_course_completions
    # Simplified approach - count users who have completed at least one full course
    completed_users = []

    Course.published.includes(course_modules: :course_steps).each do |course|
      total_steps = course.course_modules.sum { |m| m.course_steps.count }
      next if total_steps.zero?

      completed_count = User.joins(user_progresses: { course_step: { course_module: :course }})
                           .where(courses: { id: course.id }, user_progresses: { status: 'completed' })
                           .group('users.id')
                           .having('COUNT(user_progresses.id) = ?', total_steps)
                           .count

      completed_users.concat(completed_count.keys)
    end

    completed_users.uniq.count
  end

  def average_completion_rate
    total_assignments = UserCourseAssignment.count
    return 0 if total_assignments.zero?

    # Simplified approach - calculate completion rate by checking each assignment individually
    completed_assignments = 0

    UserCourseAssignment.includes(user: :user_progresses, course: { course_modules: :course_steps }).each do |assignment|
      user = assignment.user
      course = assignment.course
      total_steps = course.course_modules.sum { |m| m.course_steps.count }
      next if total_steps.zero?

      completed_steps = user.user_progresses.joins(course_step: { course_module: :course })
                           .where(courses: { id: course.id }, status: 'completed')
                           .count

      completed_assignments += 1 if completed_steps == total_steps
    end

    (completed_assignments.to_f / total_assignments * 100).round(2)
  end

  def active_users_this_month
    User.joins(:user_progresses)
        .where(user_progresses: { updated_at: 1.month.ago..Time.current })
        .distinct
        .count
  end

  def courses_with_progress
    Course.joins(course_modules: { course_steps: :user_progresses }).distinct.count
  end

  def course_analytics_data(course)
    total_assigned = course.user_course_assignments.count
    return default_course_data(course) if total_assigned.zero?

    completed_users = users_who_completed_course(course).count
    started_users = users_who_started_course(course).count

    {
      course: course,
      total_assigned: total_assigned,
      started_users: started_users,
      completed_users: completed_users,
      completion_rate: total_assigned.zero? ? 0 : (completed_users.to_f / total_assigned * 100).round(2),
      start_rate: total_assigned.zero? ? 0 : (started_users.to_f / total_assigned * 100).round(2),
      average_progress: calculate_average_progress_for_course(course),
      total_steps: course.course_modules.sum { |m| m.course_steps.count },
      estimated_duration: course.course_modules.sum { |m| m.course_steps.sum(&:duration_minutes) } || 0
    }
  end

  def user_analytics_data(user)
    assigned_courses = user.user_course_assignments.includes(:course).map(&:course)
    return default_user_data(user) if assigned_courses.empty?

    completed_courses = assigned_courses.select { |course| user.course_completed?(course) }

    {
      user: user,
      total_courses: assigned_courses.count,
      completed_courses: completed_courses.count,
      in_progress_courses: assigned_courses.count - completed_courses.count,
      overall_completion_percentage: calculate_user_overall_completion(user),
      average_quiz_score: user.average_quiz_score,
      recent_activity_days: days_since_last_activity(user),
      learning_velocity: calculate_learning_velocity(user)
    }
  end

  def default_course_data(course)
    {
      course: course,
      total_assigned: 0,
      started_users: 0,
      completed_users: 0,
      completion_rate: 0,
      start_rate: 0,
      average_progress: 0,
      total_steps: course.course_modules.sum { |m| m.course_steps.count },
      estimated_duration: course.course_modules.sum { |m| m.course_steps.sum(&:duration_minutes) } || 0
    }
  end

  def default_user_data(user)
    {
      user: user,
      total_courses: 0,
      completed_courses: 0,
      in_progress_courses: 0,
      overall_completion_percentage: 0,
      average_quiz_score: 0,
      recent_activity_days: nil,
      learning_velocity: 0
    }
  end

  def users_who_completed_course(course)
    total_steps = course.course_modules.sum { |m| m.course_steps.count }
    return [] if total_steps.zero?
    
    # Find users who have completed all steps for this course
    user_ids = User.joins(user_progresses: { course_step: { course_module: :course } })
                   .where(courses: { id: course.id }, user_progresses: { status: 'completed' })
                   .group('users.id')
                   .having('COUNT(DISTINCT user_progresses.course_step_id) = ?', total_steps)
                   .pluck('users.id')
    
    User.where(id: user_ids)
  end

  def users_who_started_course(course)
    User.joins(user_progresses: { course_step: { course_module: :course } })
        .where(courses: { id: course.id })
        .where.not(user_progresses: { status: 'not_started' })
        .distinct
  end

  def calculate_average_progress_for_course(course)
    assigned_users = course.user_course_assignments.includes(:user).map(&:user)
    return 0 if assigned_users.empty?

    total_progress = assigned_users.sum { |user| user.course_completion_percentage(course) }
    (total_progress.to_f / assigned_users.count).round(2)
  end

  def calculate_user_overall_completion(user)
    assigned_courses = user.user_course_assignments.includes(:course).map(&:course)
    return 0 if assigned_courses.empty?

    total_percentage = assigned_courses.sum { |course| user.course_completion_percentage(course) }
    (total_percentage.to_f / assigned_courses.count).round(2)
  end

  def days_since_last_activity(user)
    last_activity = user.user_progresses.maximum(:updated_at)
    return nil unless last_activity

    (Time.current - last_activity).to_i / 1.day
  end

  def calculate_learning_velocity(user)
    # Steps completed per week over the last month
    completed_last_month = user.user_progresses.completed
                              .where(completed_at: 1.month.ago..Time.current)
                              .count

    (completed_last_month.to_f / 4).round(2) # per week
  end

  def progress_over_time_data
    # Get completion data for the last 3 months
    3.months.ago.to_date.upto(Date.current).map do |date|
      completions = UserProgress.completed
                                .where(completed_at: date.beginning_of_day..date.end_of_day)
                                .count
      [date.to_s, completions]
    end
  end

  def course_completion_distribution
    completion_ranges = [
      { range: '0%', count: 0 },
      { range: '1-25%', count: 0 },
      { range: '26-50%', count: 0 },
      { range: '51-75%', count: 0 },
      { range: '76-99%', count: 0 },
      { range: '100%', count: 0 }
    ]

    User.joins(:user_course_assignments).distinct.find_each do |user|
      avg_completion = calculate_user_overall_completion(user)

      case avg_completion
      when 0
        completion_ranges[0][:count] += 1
      when 0.01..25
        completion_ranges[1][:count] += 1
      when 25.01..50
        completion_ranges[2][:count] += 1
      when 50.01..75
        completion_ranges[3][:count] += 1
      when 75.01..99.99
        completion_ranges[4][:count] += 1
      when 100
        completion_ranges[5][:count] += 1
      end
    end

    completion_ranges
  end

  def user_engagement_data
    {
      daily_active: User.joins(:user_progresses)
                       .where(user_progresses: { updated_at: 1.day.ago..Time.current })
                       .distinct.count,
      weekly_active: User.joins(:user_progresses)
                        .where(user_progresses: { updated_at: 1.week.ago..Time.current })
                        .distinct.count,
      monthly_active: User.joins(:user_progresses)
                         .where(user_progresses: { updated_at: 1.month.ago..Time.current })
                         .distinct.count
    }
  end

  # Additional helper methods would go here...
  # (course_completion_rate, course_drop_off_analysis, etc.)
end
