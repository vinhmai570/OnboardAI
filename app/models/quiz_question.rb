class QuizQuestion < ApplicationRecord
  belongs_to :quiz
  has_many :quiz_question_options, dependent: :destroy
  has_many :quiz_responses, dependent: :destroy

  validates :question_text, presence: true
  validates :question_type, presence: true, inclusion: { in: %w[multiple_choice true_false short_answer] }
  validates :points, presence: true, numericality: { greater_than: 0 }
  validates :order_position, presence: true, numericality: { greater_than: 0 }

  scope :ordered, -> { order(:order_position) }

  enum :question_type, {
    multiple_choice: 'multiple_choice',
    true_false: 'true_false',
    short_answer: 'short_answer'
  }

  def correct_options
    quiz_question_options.where(is_correct: true)
  end

  def correct_option_ids
    correct_options.pluck(:id)
  end

  def has_single_correct_answer?
    correct_options.count == 1
  end

  def has_multiple_correct_answers?
    correct_options.count > 1
  end

  def check_answer(selected_option_ids)
    return false if selected_option_ids.blank?

    case question_type
    when 'multiple_choice'
      selected_ids = Array(selected_option_ids).map(&:to_i)
      correct_ids = correct_option_ids

      # For multiple choice, all correct options must be selected and no incorrect ones
      selected_ids.sort == correct_ids.sort
    when 'true_false'
      selected_id = selected_option_ids.to_i
      correct_option_ids.include?(selected_id)
    else
      false # Short answer requires manual grading
    end
  end

  def check_short_answer(answer_text)
    return false unless question_type == 'short_answer'
    return false if answer_text.blank?

    # Simple text comparison - in a real system you might want more sophisticated matching
    correct_options.any? { |option| option.option_text.strip.downcase == answer_text.strip.downcase }
  end

  def user_response_for_attempt(quiz_attempt)
    quiz_responses.find_by(quiz_attempt: quiz_attempt)
  end

  def response_summary_for_attempt(quiz_attempt)
    response = user_response_for_attempt(quiz_attempt)
    return nil unless response

    case question_type
    when 'multiple_choice', 'true_false'
      {
        selected_options: response.quiz_question_option&.option_text,
        is_correct: response.is_correct,
        points_earned: response.points_earned
      }
    when 'short_answer'
      {
        answer_text: response.response_text,
        is_correct: response.is_correct,
        points_earned: response.points_earned
      }
    end
  end
end
