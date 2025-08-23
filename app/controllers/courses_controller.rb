class CoursesController < ApplicationController
  before_action :require_login
  before_action :set_course, only: [:show, :enroll, :complete_step]

  def index
    # Show different courses based on user role
    if current_user.admin?
      # Admins can see all published courses
      @courses = Course.includes(:course_modules, :admin).published.order(created_at: :desc)
    else
      # Regular users only see courses assigned to them
      @courses = current_user.assigned_courses.includes(:course_modules, :admin).published.order(created_at: :desc)
    end

    # If user is logged in, get their progress data for each course
    if current_user
      @user_progress_by_course = {}
      @courses.each do |course|
        @user_progress_by_course[course.id] = current_user.progress_for_course(course)
      end
    end

    respond_to do |format|
      format.html # Regular HTML view
      format.json {
        render json: {
          courses: @courses.map do |course|
            {
              id: course.id,
              title: course.title,
              description: course.description,
              status: course.status,
              total_modules: course.course_modules.count,
              user_progress: current_user ? @user_progress_by_course[course.id] : nil
            }
          end
        }
      }
    end
  end

  def show
    # Check if user has access to this course
    unless can_access_course?(@course)
      redirect_to courses_path, alert: "You don't have access to this course."
      return
    end

    # Get user progress data if logged in
    @progress_data = current_user&.progress_for_course(@course)

    # Load course structure with the same data as admin view
    @course_modules = @course.course_modules.includes(:course_steps).ordered
  end

  def enroll
    # Check if user has access to this course
    unless can_access_course?(@course)
      redirect_to courses_path, alert: "You don't have access to this course."
      return
    end

    # Create initial progress records for all course steps
    @course.course_modules.includes(:course_steps).each do |course_module|
      course_module.course_steps.each do |step|
        step.user_progresses.find_or_create_by(user: current_user) do |progress|
          progress.status = 'not_started'
        end
      end
    end

    redirect_to @course, notice: 'Successfully enrolled in course!'
  end

  def complete_step
    # Check if user has access to this course
    unless can_access_course?(@course)
      render json: { success: false, message: "You don't have access to this course." }
      return
    end

    @course_step = CourseStep.find(params[:step_id])
    @progress = @course_step.user_progresses.find_or_create_by(user: current_user)

    if @progress.complete!
      render json: { success: true, message: 'Step completed successfully!' }
    else
      render json: { success: false, message: 'Failed to complete step', errors: @progress.errors.full_messages }
    end
  end

  def step_content
    step = CourseStep.find(params[:id])
    course_module = step.course_module

    # Check if user has access to this course
    unless can_access_course?(course_module.course)
      render json: { error: "Access denied" }, status: :forbidden
      return
    end

    render json: {
      id: step.id,
      title: step.title,
      step_type: step.step_type,
      content: step.content,
      detailed_content: step.detailed_content,
      duration_minutes: step.duration_minutes,
      module_title: course_module.title,
      content_generated: step.content_generated?,
      icon: step.icon
    }
  end

  def quiz_check
    course = Course.find(params[:course_id])
    course_module = course.course_modules.find(params[:course_module_id])
    course_step = course_module.course_steps.find(params[:step_id])

    # Check if user has access to this course
    unless can_access_course?(course)
      render json: { error: "Access denied" }, status: :forbidden
      return
    end

    quiz = course_step.quiz

    respond_to do |format|
      format.json do
        if quiz
          render json: {
            has_quiz: true,
            quiz_id: quiz.id,
            quiz_title: quiz.title,
            question_count: quiz.quiz_questions.count
          }
        else
          render json: {
            has_quiz: false,
            step_type: course_step.step_type,
            step_title: course_step.title
          }
        end
      end
    end
  end

  private

  def set_course
    @course = Course.find(params[:id])
  end

  def require_login
    redirect_to new_session_path unless current_user
  end

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end

  def can_access_course?(course)
    return true if current_user.admin?
    current_user.assigned_courses.include?(course)
  end
end
