class CourseModule < ApplicationRecord
  belongs_to :course
  has_many :course_steps, -> { order(:order_position) }, dependent: :destroy

  validates :title, presence: true
  validates :duration_hours, presence: true, numericality: { greater_than: 0 }
  validates :order_position, presence: true, uniqueness: { scope: :course_id }

  scope :ordered, -> { order(:order_position) }

  before_validation :set_order_position, on: :create

  def total_steps
    course_steps.count
  end

  def total_duration_minutes
    course_steps.sum(:duration_minutes)
  end

  def duration_minutes
    (duration_hours * 60).to_i
  end

  # Mark all steps in this module as completed for a specific user
  def complete_all_steps_for_user!(user, score = nil)
    CourseStep.transaction do
      course_steps.each do |step|
        progress = step.user_progresses.find_or_create_by(user: user)
        
        # Start the step if it hasn't been started yet
        progress.start! if progress.not_started?
        
        # Mark as completed with optional score
        progress.complete!(score)
      end
    end
    
    Rails.logger.info "Module '#{title}' - All #{course_steps.count} steps marked as completed for #{user.email}"
  end

  # Check if all steps in module are completed by user
  def completed_by?(user)
    return false if course_steps.empty?
    
    course_steps.all? { |step| step.completed_by?(user) }
  end

  # Get completion percentage for this module for a specific user
  def completion_percentage_for_user(user)
    return 0 if course_steps.empty?
    
    completed_count = course_steps.count { |step| step.completed_by?(user) }
    (completed_count.to_f / course_steps.count * 100).round(2)
  end

  def move_up
    return false if order_position <= 1

    other_module = course.course_modules.where(order_position: order_position - 1).first
    return false unless other_module

    CourseModule.transaction do
      other_module.update!(order_position: order_position)
      self.update!(order_position: order_position - 1)
    end
  end

  def move_down
    max_position = course.course_modules.maximum(:order_position)
    return false if order_position >= max_position

    other_module = course.course_modules.where(order_position: order_position + 1).first
    return false unless other_module

    CourseModule.transaction do
      other_module.update!(order_position: order_position)
      self.update!(order_position: order_position + 1)
    end
  end

  private

  def set_order_position
    self.order_position ||= (course&.course_modules&.maximum(:order_position) || 0) + 1
  end
end
