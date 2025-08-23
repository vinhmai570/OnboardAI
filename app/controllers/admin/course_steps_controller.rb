class Admin::CourseStepsController < ApplicationController
  before_action :require_admin
  before_action :set_course_and_module
  before_action :set_course_step, only: [:edit, :update, :destroy, :move_up, :move_down]

  def index
    @course_steps = @course_module.course_steps.ordered
  end

  def new
    @course_step = @course_module.course_steps.build
  end

    def create
    @course_step = @course_module.course_steps.build(course_step_params)

    if @course_step.save
      respond_to do |format|
        format.json { render json: { success: true, step: course_step_json(@course_step) } }
        format.html { redirect_to admin_course_course_module_course_steps_path(@course, @course_module), notice: 'Step was successfully created.' }
      end
    else
      respond_to do |format|
        format.json { render json: { success: false, errors: @course_step.errors.full_messages } }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

    def update
    if @course_step.update(course_step_params)
      respond_to do |format|
        format.json { render json: { success: true, step: course_step_json(@course_step) } }
        format.html { redirect_to admin_course_course_module_course_steps_path(@course, @course_module), notice: 'Step was successfully updated.' }
      end
    else
      respond_to do |format|
        format.json { render json: { success: false, errors: @course_step.errors.full_messages } }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @course_step.destroy
    respond_to do |format|
      format.json { render json: { success: true } }
      format.html { redirect_to admin_course_course_module_course_steps_path(@course, @course_module), notice: 'Step was successfully deleted.' }
    end
  end

  def move_up
    @course_step.move_up
    respond_to do |format|
      format.json { render json: { success: true } }
      format.html { redirect_to admin_course_course_module_course_steps_path(@course, @course_module) }
    end
  end

  def move_down
    @course_step.move_down
    respond_to do |format|
      format.json { render json: { success: true } }
      format.html { redirect_to admin_course_course_module_course_steps_path(@course, @course_module) }
    end
  end

  private

  def set_course_and_module
    @course = Course.find(params[:course_id])
    @course_module = @course.course_modules.find(params[:course_module_id])
  end

  def set_course_step
    @course_step = @course_module.course_steps.find(params[:id])
  end

  def course_step_params
    params.require(:course_step).permit(:title, :content, :step_type, :duration_minutes, :order_position, resources: [])
  end

  def course_step_json(step)
    {
      id: step.id,
      title: step.title,
      content: step.content,
      step_type: step.step_type,
      duration_minutes: step.duration_minutes,
      order_position: step.order_position,
      icon: step.icon,
      resources: step.parsed_resources
    }
  end
end
