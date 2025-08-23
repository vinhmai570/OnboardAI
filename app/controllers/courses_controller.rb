class CoursesController < ApplicationController
  before_action :set_course, only: [:show, :enroll, :complete_step]

  def index
    @courses = Course.published.includes(:admin)
  end

  def show
    @progress = current_user.progresses.find_or_initialize_by(course: @course)
    @steps = @course.steps.ordered
    @current_step = @steps[@progress.completed_steps] || @steps.first
  end

  def enroll
    @progress = current_user.progresses.find_or_create_by(course: @course)
    redirect_to course_path(@course), notice: 'Successfully enrolled in course!'
  end

  def complete_step
    @progress = current_user.progresses.find_by!(course: @course)

    if params[:step_id].to_i == (@progress.completed_steps + 1)
      @progress.increment!(:completed_steps)
      redirect_to course_path(@course), notice: 'Step completed!'
    else
      redirect_to course_path(@course), alert: 'Invalid step completion.'
    end
  end

  private

  def set_course
    @course = Course.find(params[:id])
  end
end
