class Admin::CourseModulesController < ApplicationController
  before_action :require_admin
  before_action :set_course
  before_action :set_course_module, only: [:edit, :update, :destroy, :move_up, :move_down]

  def index
    @course_modules = @course.course_modules.includes(:course_steps).ordered
  end

  def new
    @course_module = @course.course_modules.build
  end

    def create
    @course_module = @course.course_modules.build(course_module_params)

    if @course_module.save
      respond_to do |format|
        format.json { render json: { success: true, module: course_module_json(@course_module) } }
        format.html { redirect_to admin_course_course_modules_path(@course), notice: 'Module was successfully created.' }
      end
    else
      respond_to do |format|
        format.json { render json: { success: false, errors: @course_module.errors.full_messages } }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

    def update
    if @course_module.update(course_module_params)
      respond_to do |format|
        format.json { render json: { success: true, module: course_module_json(@course_module) } }
        format.html { redirect_to admin_course_course_modules_path(@course), notice: 'Module was successfully updated.' }
      end
    else
      respond_to do |format|
        format.json { render json: { success: false, errors: @course_module.errors.full_messages } }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @course_module.destroy
    respond_to do |format|
      format.json { render json: { success: true } }
      format.html { redirect_to admin_course_course_modules_path(@course), notice: 'Module was successfully deleted.' }
    end
  end

  def move_up
    @course_module.move_up
    respond_to do |format|
      format.json { render json: { success: true } }
      format.html { redirect_to admin_course_course_modules_path(@course) }
    end
  end

  def move_down
    @course_module.move_down
    respond_to do |format|
      format.json { render json: { success: true } }
      format.html { redirect_to admin_course_course_modules_path(@course) }
    end
  end

  private

  def set_course
    @course = Course.find(params[:course_id])
  end

  def set_course_module
    @course_module = @course.course_modules.find(params[:id])
  end

  def course_module_params
    params.require(:course_module).permit(:title, :description, :duration_hours, :order_position)
  end

  def course_module_json(course_module)
    {
      id: course_module.id,
      title: course_module.title,
      description: course_module.description,
      duration_hours: course_module.duration_hours,
      order_position: course_module.order_position,
      steps_count: course_module.course_steps.count,
      steps: course_module.course_steps.ordered.map { |step| course_step_json(step) }
    }
  end

  def course_step_json(step)
    {
      id: step.id,
      title: step.title,
      content: step.content,
      step_type: step.step_type,
      duration_minutes: step.duration_minutes,
      order_position: step.order_position,
      icon: step.icon
    }
  end
end
