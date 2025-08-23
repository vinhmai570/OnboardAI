class Admin::CoursesController < ApplicationController
  before_action :require_admin
  before_action :set_course, only: [ :show, :edit, :update, :destroy, :generate_tasks, :generate_details, :publish ]

  def index
    # Base query with includes for efficiency
    @courses = Course.includes(:admin, :course_modules, :assigned_users).order(created_at: :desc)

    # Apply filters
    if params[:status].present?
      case params[:status]
      when 'published'
        @courses = @courses.published
      when 'draft'
        @courses = @courses.draft
      end
    end

    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @courses = @courses.where("title ILIKE ? OR prompt ILIKE ?", search_term, search_term)
    end

    if params[:admin_id].present?
      @courses = @courses.where(admin_id: params[:admin_id])
    end

    # Pagination (if needed)
    @courses = @courses.limit(50) unless params[:show_all]

    # Statistics for dashboard
    @stats = {
      total_courses: Course.count,
      published_courses: Course.published.count,
      draft_courses: Course.draft.count,
      total_assignments: UserCourseAssignment.count
    }

    # Admin options for filter
    @admins = User.admins.order(:email)

    respond_to do |format|
      format.html
      format.json { render json: courses_json }
    end
  end

  def show
    # Load course structure with the new course modules system
    @course_modules = @course.course_modules.includes(:course_steps).ordered

    # Get assignment statistics
    @assigned_users = @course.assigned_users.includes(:user_progresses)
    @assignment_stats = {
      total_assigned: @assigned_users.count,
      completed_users: @assigned_users.joins(:user_progresses)
                                     .where(user_progresses: { status: 'completed' })
                                     .distinct.count,
      in_progress_users: @assigned_users.joins(:user_progresses)
                                       .where(user_progresses: { status: 'in_progress' })
                                       .distinct.count
    }

    # Course analytics
    @course_stats = {
      total_modules: @course.total_modules,
      total_steps: @course.total_steps,
      total_duration: @course.total_duration_minutes,
      quiz_count: @course.quiz_count,
      completion_rate: calculate_completion_rate
    }

    # Available users for assignment (not already assigned)
    @available_users = User.users.where.not(id: @assigned_users.pluck(:id)).order(:email)
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
    course_title = @course.title

    if @course.destroy
      redirect_to admin_courses_path, notice: "Course '#{course_title}' was successfully deleted."
    else
      redirect_to admin_courses_path, alert: "Failed to delete course. It may have dependent records."
    end
  end

  # User assignment management
  def assign_users
    user_ids = params[:user_ids] || []
    assigned_count = 0

    user_ids.each do |user_id|
      user = User.find(user_id)
      unless @course.assigned_users.include?(user)
        @course.user_course_assignments.create!(
          user: user,
          assigned_by: current_user,
          assigned_at: Time.current
        )
        assigned_count += 1
      end
    end

    if assigned_count > 0
      redirect_to admin_course_path(@course),
                  notice: "Successfully assigned course to #{assigned_count} user(s)."
    else
      redirect_to admin_course_path(@course),
                  alert: "No new users were assigned (they may already have access)."
    end
  rescue => e
    redirect_to admin_course_path(@course),
                alert: "Error assigning users: #{e.message}"
  end

  def unassign_user
    user = User.find(params[:user_id])
    assignment = @course.user_course_assignments.find_by(user: user)

    if assignment&.destroy
      redirect_to admin_course_path(@course),
                  notice: "Successfully removed #{user.email} from course."
    else
      redirect_to admin_course_path(@course),
                  alert: "Failed to remove user from course."
    end
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
    if @course.course_modules.any?
      @course.update!(structure: { published: true, published_at: Time.current })
      redirect_to admin_course_path(@course), notice: "Course was successfully published."
    else
      redirect_to admin_course_path(@course),
                  alert: "Cannot publish course without modules and content."
    end
  end

  private

  def set_course
    @course = Course.find(params[:id])
  end

  def course_params
    params.require(:course).permit(:title, :prompt)
  end

  def calculate_completion_rate
    return 0 if @assigned_users.empty?

    completed_count = @assigned_users.select do |user|
      user.progress_for_course(@course)[:percentage] == 100
    end.count

    (completed_count.to_f / @assigned_users.count * 100).round(1)
  end

  def courses_json
    {
      courses: @courses.map do |course|
        {
          id: course.id,
          title: course.title,
          status: course.status,
          admin: course.admin.email,
          total_modules: course.total_modules,
          total_steps: course.total_steps,
          assigned_users_count: course.assigned_users.count,
          created_at: course.created_at.strftime('%b %d, %Y')
        }
      end,
      stats: @stats
    }
  end
end
