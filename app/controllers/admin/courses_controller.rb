class Admin::CoursesController < ApplicationController
  before_action :require_admin
  before_action :set_course, only: [ :show, :edit, :update, :destroy, :generate_tasks, :generate_details, :publish ]

  def index
    @courses = Course.includes(:admin).order(created_at: :desc)
  end

  def new
    @course = current_user.courses.build
  end

  def create
    @course = current_user.courses.build(course_params)

    if @course.save
      redirect_to admin_course_path(@course), notice: "Course was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @steps = @course.steps.ordered
  end

  def edit
  end

  def update
    if @course.update(course_params)
      redirect_to admin_course_path(@course), notice: "Course was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @course.destroy
    redirect_to admin_courses_path, notice: "Course was successfully deleted."
  end

  def generate_tasks
    # This would use AI to generate task list
    redirect_to admin_course_path(@course), notice: "Task generation feature coming soon!"
  end

  def generate_details
    # This would use AI to generate detailed content
    redirect_to admin_course_path(@course), notice: "Content generation feature coming soon!"
  end

  def publish
    @course.update!(structure: { published: true })
    redirect_to admin_course_path(@course), notice: "Course was successfully published."
  end

  private

  def set_course
    @course = Course.find(params[:id])
  end

  def course_params
    params.require(:course).permit(:title, :prompt)
  end
end
