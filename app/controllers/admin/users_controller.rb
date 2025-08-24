class Admin::UsersController < ApplicationController
  before_action :require_admin
  before_action :set_user, only: [ :show, :edit, :update, :destroy, :assign_course, :unassign_course ]

  def index
    @users = User.all.includes(:assigned_courses).order(created_at: :desc)
  end

  def show
    @assigned_courses = @user.assigned_courses.includes(:admin)
    @available_courses = Course.published.where.not(id: @assigned_courses.pluck(:id))
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to admin_users_path, notice: "User was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    # Handle password update - only update if password is provided
    if user_params[:password].present?
      if @user.update(user_params)
        redirect_to admin_users_path, notice: "User was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    else
      # Update without password
      if @user.update(user_params.except(:password))
        redirect_to admin_users_path, notice: "User was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def destroy
    @user.destroy
    redirect_to admin_users_path, notice: "User was successfully deleted."
  end

  def assign_course
    course = Course.find(params[:course_id])

    unless @user.assigned_courses.include?(course)
      @user.user_course_assignments.create!(
        course: course,
        assigned_by: current_user,
        assigned_at: Time.current
      )

      # Create UserProgress records for all course steps
      course.course_modules.includes(:course_steps).each do |course_module|
        course_module.course_steps.each do |step|
          step.user_progresses.find_or_create_by(user: @user) do |progress|
            progress.status = 'not_started'
          end
        end
      end

      redirect_to admin_user_path(@user), notice: "Course '#{course.title}' successfully assigned to #{@user.email}."
    else
      redirect_to admin_user_path(@user), alert: "Course is already assigned to this user."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_user_path(@user), alert: "Failed to assign course: #{e.message}"
  end

  def unassign_course
    course = Course.find(params[:course_id])
    assignment = @user.user_course_assignments.find_by(course: course)

    if assignment
      assignment.destroy
      redirect_to admin_user_path(@user), notice: "Course '#{course.title}' successfully unassigned from #{@user.email}."
    else
      redirect_to admin_user_path(@user), alert: "Course is not assigned to this user."
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email, :role, :password)
  end
end
