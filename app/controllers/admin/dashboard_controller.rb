class Admin::DashboardController < ApplicationController
  before_action :require_admin

  def index
    # Admin dashboard overview
    @total_users = User.users.count
    @total_courses = Course.count
    @total_documents = Document.count
    @recent_courses = Course.includes(:admin).order(created_at: :desc).limit(5)
    @recent_users = User.users.order(created_at: :desc).limit(5)

    # Progress Analytics Summary
    @progress_summary = {
      total_enrolled_users: total_enrolled_users,
      active_users_this_week: active_users_this_week,
      average_completion_rate: average_completion_rate,
      courses_with_progress: courses_with_progress,
      recent_completions_count: recent_completions_count
    }

    # Top performing courses
    @top_courses = Course.published
                         .joins(:user_course_assignments)
                         .group('courses.id')
                         .order('COUNT(user_course_assignments.id) DESC')
                         .limit(5)
                         .includes(:course_modules)

    # Users needing attention (low progress, inactive)
    @users_needing_attention = users_needing_attention.first(10)

    # Recent learning activity
    @recent_activity = UserProgress.includes(:user, course_step: { course_module: :course })
                                  .where(updated_at: 1.week.ago..Time.current)
                                  .order(updated_at: :desc)
                                  .limit(10)

    # Course completion trends (for charts)
    @completion_trends = completion_trends_data

    respond_to do |format|
      format.html # Regular HTML view
      format.json {
        render json: {
          stats: {
            total_users: @total_users,
            total_courses: @total_courses,
            total_documents: @total_documents
          },
          progress_summary: @progress_summary,
          recent_courses: @recent_courses.map do |course|
            {
              id: course.id,
              title: course.title,
              admin_email: course.admin.email,
              created_at: course.created_at.strftime('%b %d, %Y'),
              modules_count: course.course_modules.count
            }
          end,
          recent_users: @recent_users.map do |user|
            {
              id: user.id,
              email: user.email,
              created_at: user.created_at.strftime('%b %d, %Y')
            }
          end,
          completion_trends: @completion_trends,
          top_courses: @top_courses.map do |course|
            {
              id: course.id,
              title: course.title,
              assignments_count: course.user_course_assignments.count
            }
          end
        }
      }
    end
  end

  private

  def total_enrolled_users
    User.joins(:user_course_assignments).distinct.count
  end

  def active_users_this_week
    User.joins(:user_progresses)
        .where(user_progresses: { updated_at: 1.week.ago..Time.current })
        .distinct
        .count
  end

  def average_completion_rate
    total_assignments = UserCourseAssignment.count
    return 0 if total_assignments.zero?

    # Calculate users who completed all steps in their assigned courses
    # Simplified approach to avoid complex subqueries
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

  def courses_with_progress
    Course.joins(course_modules: { course_steps: :user_progresses }).select('DISTINCT courses.id').count
  end

  def recent_completions_count
    UserProgress.completed.where(completed_at: 1.week.ago..Time.current).count
  end

  def users_needing_attention
    # Users who haven't made progress in the last 2 weeks
    inactive_users = User.joins(:user_course_assignments)
                        .left_joins(:user_progresses)
                        .where('user_progresses.updated_at < ? OR user_progresses.updated_at IS NULL', 2.weeks.ago)
                        .distinct

    # Users with low completion rates
    low_performers = User.joins(:user_course_assignments, :user_progresses)
                        .group('users.id')
                        .having('AVG(CASE WHEN user_progresses.status = ? THEN 100 ELSE 0 END) < 30', 'completed')

    (inactive_users + low_performers).uniq
  end

  def completion_trends_data
    # Get completion data for the last 30 days
    30.days.ago.to_date.upto(Date.current).map do |date|
      completions = UserProgress.completed
                                .where(completed_at: date.beginning_of_day..date.end_of_day)
                                .count
      {
        date: date.strftime('%m/%d'),
        completions: completions
      }
    end
  end
end
