class QuizResponse < ApplicationRecord
  belongs_to :quiz_attempt
  belongs_to :quiz_question
  belongs_to :quiz_question_option, optional: true

  validates :quiz_attempt, presence: true
  validates :quiz_question, presence: true
  validates :points_earned, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Validate that quiz_question belongs to the same quiz as quiz_attempt
  validate :question_belongs_to_quiz

  # Validate that either option or text response is provided based on question type
  validate :appropriate_response_type

  scope :correct, -> { where(is_correct: true) }
  scope :incorrect, -> { where(is_correct: false) }

  def user
    quiz_attempt.user
  end

  def quiz
    quiz_attempt.quiz
  end

  def question_text
    quiz_question.question_text
  end

  def question_type
    quiz_question.question_type
  end

  def selected_option_text
    quiz_question_option&.option_text
  end

  def correct_answer_text
    case quiz_question.question_type
    when 'multiple_choice', 'true_false'
      quiz_question.correct_options.map(&:option_text).join(', ')
    when 'short_answer'
      quiz_question.correct_options.first&.option_text
    end
  end

  def response_text_display
    case quiz_question.question_type
    when 'multiple_choice', 'true_false'
      selected_option_text
    when 'short_answer'
      response_text
    end
  end

  def partial_credit?
    points_earned > 0 && points_earned < quiz_question.points
  end

  def full_credit?
    points_earned == quiz_question.points
  end

  def no_credit?
    points_earned == 0
  end

  def calculate_points_earned!
    points = case quiz_question.question_type
             when 'multiple_choice', 'true_false'
               calculate_multiple_choice_points
             when 'short_answer'
               calculate_short_answer_points
             else
               0
             end

    update_columns(
      points_earned: points,
      is_correct: points > 0
    )

    points
  end

  private

  def calculate_multiple_choice_points
    return 0 unless quiz_question_option

    if quiz_question_option.is_correct?
      quiz_question.points
    else
      0
    end
  end

  def calculate_short_answer_points
    return 0 if response_text.blank?

    # For short answer questions, check against correct answer options
    correct_answers = quiz_question.correct_options.map(&:option_text).map(&:downcase)
    user_answer = response_text.strip.downcase

    if correct_answers.any? { |correct| user_answer.include?(correct) || correct.include?(user_answer) }
      quiz_question.points
    else
      0 # In a real system, this might involve more sophisticated matching or manual grading
    end
  end

  def question_belongs_to_quiz
    return unless quiz_question && quiz_attempt

    unless quiz_question.quiz_id == quiz_attempt.quiz_id
      errors.add(:quiz_question, "must belong to the same quiz as the attempt")
    end
  end

  def appropriate_response_type
    return unless quiz_question

    case quiz_question.question_type
    when 'multiple_choice', 'true_false'
      if quiz_question_option.blank?
        errors.add(:quiz_question_option, "must be selected for #{quiz_question.question_type} questions")
      end

      if quiz_question_option && quiz_question_option.quiz_question != quiz_question
        errors.add(:quiz_question_option, "must belong to the same question")
      end

    when 'short_answer'
      if response_text.blank?
        errors.add(:response_text, "must be provided for short answer questions")
      end

      if quiz_question_option.present?
        errors.add(:quiz_question_option, "should not be provided for short answer questions")
      end
    end
  end
end
