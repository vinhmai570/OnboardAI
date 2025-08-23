class DashboardController < ApplicationController
  def index
    # User dashboard - show enrolled courses and progress
    @enrolled_courses = current_user.progresses.includes(:course)
    @available_courses = Course.published.where.not(id: @enrolled_courses.pluck(:course_id))
  end
end
