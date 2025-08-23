class Progress < ApplicationRecord
  belongs_to :user
  belongs_to :course

  # Validations
  validates :user_id, uniqueness: { scope: :course_id }
  validates :completed_steps, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Initialize with defaults
  after_initialize :set_defaults, if: :new_record?

  def completion_percentage
    return 0 if course.steps.count == 0
    (completed_steps.to_f / course.steps.count * 100).round(2)
  end

  def completed?
    completed_steps >= course.steps.count
  end

  private

  def set_defaults
    self.completed_steps ||= 0
    self.quiz_scores ||= {}
  end
end
