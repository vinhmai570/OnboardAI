class Quiz < ApplicationRecord
  belongs_to :course_step
  has_many :quiz_questions, dependent: :destroy
  has_many :quiz_attempts, dependent: :destroy

  validates :title, presence: true
  validates :total_points, presence: true, numericality: { greater_than: 0 }

  scope :ordered, -> { order(:created_at) }

  def has_questions?
    quiz_questions.exists?
  end

  def question_count
    quiz_questions.count
  end

  def average_score
    completed_attempts = quiz_attempts.where(status: 'completed')
    return 0 if completed_attempts.empty?

    completed_attempts.average(:score).to_f.round(2)
  end

  def completion_rate
    total_attempts = quiz_attempts.count
    return 0 if total_attempts.zero?

    completed_attempts = quiz_attempts.where(status: 'completed').count
    (completed_attempts.to_f / total_attempts * 100).round(2)
  end

  def attempts_for_user(user)
    quiz_attempts.where(user: user).order(created_at: :desc)
  end

  def best_attempt_for_user(user)
    attempts_for_user(user).where(status: 'completed').order(score: :desc).first
  end

  def user_completed?(user)
    attempts_for_user(user).where(status: 'completed').exists?
  end
end
