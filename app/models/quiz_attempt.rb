class QuizAttempt < ApplicationRecord
  belongs_to :user
  belongs_to :quiz
  has_many :quiz_responses, dependent: :destroy

  validates :started_at, presence: true
  validates :status, presence: true, inclusion: { in: %w[in_progress completed abandoned] }

  scope :completed, -> { where(status: 'completed') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :recent, -> { order(created_at: :desc) }

  enum :status, {
    in_progress: 'in_progress',
    completed: 'completed',
    abandoned: 'abandoned'
  }

  def complete!
    return false if completed?

    # Score all responses before calculating total score
    score_all_responses!
    calculate_score!
    update!(
      status: 'completed',
      completed_at: Time.current,
      time_spent_minutes: calculate_time_spent
    )
  end

  def abandon!
    return false if completed?

    update!(
      status: 'abandoned',
      completed_at: Time.current,
      time_spent_minutes: calculate_time_spent
    )
  end

  def score_all_responses!
    quiz_responses.each do |response|
      response.calculate_points_earned!
    end
  end

  def calculate_score!
    total_points = 0
    earned_points = 0

    quiz.quiz_questions.each do |question|
      total_points += question.points

      response = quiz_responses.find_by(quiz_question: question)
      earned_points += response&.points_earned || 0
    end

    update_columns(
      score: earned_points,
      total_points: total_points
    )

    earned_points
  end

  def percentage_score
    return 0 if total_points.to_i.zero?
    (score.to_f / total_points * 100).round(2)
  end

  def passed?(passing_score = 70)
    percentage_score >= passing_score
  end

  def time_limit_exceeded?
    return false unless quiz.time_limit_minutes
    return false unless started_at

    time_spent = calculate_time_spent
    time_spent > quiz.time_limit_minutes
  end

  def remaining_time_minutes
    return nil unless quiz.time_limit_minutes
    return 0 unless started_at
    return 0 if completed?

    elapsed_minutes = calculate_time_spent
    remaining = quiz.time_limit_minutes - elapsed_minutes
    [remaining, 0].max
  end

  def progress_percentage
    total_questions = quiz.quiz_questions.count
    return 0 if total_questions.zero?

    answered_questions = quiz_responses.count
    (answered_questions.to_f / total_questions * 100).round(2)
  end

  def all_questions_answered?
    quiz_responses.count == quiz.quiz_questions.count
  end

  def can_submit?
    in_progress? && all_questions_answered?
  end

  def response_for_question(question)
    quiz_responses.find_by(quiz_question: question)
  end

  def answer_question!(question, selected_option_ids = nil, answer_text = nil)
    raise ArgumentError, "Question does not belong to this quiz" unless question.quiz == quiz

    # Remove existing response for this question
    quiz_responses.where(quiz_question: question).destroy_all

    case question.question_type
    when 'multiple_choice', 'true_false'
      return false if selected_option_ids.blank?

      selected_option = question.quiz_question_options.find_by(id: selected_option_ids)
      return false unless selected_option

      is_correct = question.check_answer(selected_option_ids)
      points_earned = is_correct ? question.points : 0

      quiz_responses.create!(
        quiz_question: question,
        quiz_question_option: selected_option,
        is_correct: is_correct,
        points_earned: points_earned
      )

    when 'short_answer'
      return false if answer_text.blank?

      is_correct = question.check_short_answer(answer_text)
      points_earned = is_correct ? question.points : 0

      quiz_responses.create!(
        quiz_question: question,
        response_text: answer_text,
        is_correct: is_correct,
        points_earned: points_earned
      )
    end

    true
  end

  private

  def calculate_time_spent
    return 0 unless started_at

    end_time = completed_at || Time.current
    ((end_time - started_at) / 60).round
  end
end
