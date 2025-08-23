class QuizQuestionOption < ApplicationRecord
  belongs_to :quiz_question
  has_many :quiz_responses, dependent: :destroy

  validates :option_text, presence: true
  validates :order_position, presence: true, numericality: { greater_than: 0 }
  validates :is_correct, inclusion: { in: [true, false] }

  scope :ordered, -> { order(:order_position) }
  scope :correct, -> { where(is_correct: true) }
  scope :incorrect, -> { where(is_correct: false) }

  def correct?
    is_correct
  end

  def incorrect?
    !is_correct
  end

  def selection_count_for_quiz
    quiz_responses.joins(:quiz_attempt)
                  .where(quiz_attempts: { quiz: quiz_question.quiz, status: 'completed' })
                  .count
  end

  def selection_percentage_for_quiz
    total_attempts = quiz_question.quiz.quiz_attempts.where(status: 'completed').count
    return 0 if total_attempts.zero?

    selections = selection_count_for_quiz
    (selections.to_f / total_attempts * 100).round(2)
  end
end
