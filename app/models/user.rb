class User < ApplicationRecord
  has_secure_password

  # Associations
  has_many :documents, dependent: :destroy
  has_many :progresses, dependent: :destroy
  has_many :courses, foreign_key: :admin_id, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :quiz_attempts, dependent: :destroy
  has_many :user_progresses, dependent: :destroy

  # Validations
  validates :email, presence: true, uniqueness: true
  validates :role, presence: true, inclusion: { in: %w[admin user] }

  # Scopes
  scope :admins, -> { where(role: "admin") }
  scope :users, -> { where(role: "user") }

  def admin?
    role == "admin"
  end

  def user?
    role == "user"
  end

  def name
    # Return email as display name since we don't have a separate name field
    email
  end

  # Quiz-related methods
  def quiz_attempts_for_course(course)
    quiz_attempts.joins(quiz: { course_step: { course_module: :course } })
                 .where(courses: { id: course.id })
  end

  def completed_quizzes_for_course(course)
    quiz_attempts_for_course(course).completed
  end

  def quiz_completion_rate_for_course(course)
    total_quizzes = Quiz.joins(course_step: { course_module: :course })
                       .where(courses: { id: course.id })
                       .count
    return 0 if total_quizzes.zero?

    completed_count = completed_quizzes_for_course(course).count
    (completed_count.to_f / total_quizzes * 100).round(2)
  end

  # Progress-related methods
  def progress_for_course(course)
    UserProgress.course_progress_for_user(self, course)
  end

  def completed_steps_for_course(course)
    user_progresses.joins(course_step: { course_module: :course })
                   .where(courses: { id: course.id }, status: 'completed')
  end

  def course_completion_percentage(course)
    progress_data = progress_for_course(course)
    progress_data[:completion_percentage]
  end

  def course_completed?(course)
    course_completion_percentage(course) >= 100
  end

  # Overall learning metrics
  def total_courses_enrolled
    # Count courses where user has made progress
    Course.joins(course_modules: { course_steps: :user_progresses })
          .where(user_progresses: { user: self })
          .distinct
          .count
  end

  def total_courses_completed
    Course.joins(course_modules: { course_steps: :user_progresses })
          .where(user_progresses: { user: self })
          .group('courses.id')
          .having('COUNT(CASE WHEN user_progresses.status = ? THEN 1 END) = COUNT(course_steps.id)', 'completed')
          .count
          .keys
          .length
  end

  def average_quiz_score
    completed_attempts = quiz_attempts.completed.where.not(score: nil, total_points: nil)
    return 0 if completed_attempts.empty?

    total_percentage = completed_attempts.sum do |attempt|
      attempt.percentage_score
    end

    (total_percentage / completed_attempts.count).round(2)
  end
end
