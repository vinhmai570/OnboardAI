class Step < ApplicationRecord
  belongs_to :course

  # Validations
  validates :order, presence: true, uniqueness: { scope: :course_id }
  validates :content, presence: true

  # Scopes
  scope :ordered, -> { order(:order) }

  def quiz_present?
    quiz_questions.present? && quiz_questions.any?
  end
end
