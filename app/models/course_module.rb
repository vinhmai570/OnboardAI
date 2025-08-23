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
