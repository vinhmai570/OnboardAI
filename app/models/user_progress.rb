class UserProgress < ApplicationRecord
  belongs_to :user
  belongs_to :course_step

  validates :user, presence: true
  validates :course_step, presence: true
  validates :status, presence: true, inclusion: { in: %w[not_started in_progress completed] }

  # Ensure one progress record per user per course step
  validates :course_step_id, uniqueness: { scope: :user_id }

  # Callbacks to ensure course progress tracking
  after_update :update_course_progress_tracking, if: :saved_change_to_status?

  scope :completed, -> { where(status: 'completed') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :not_started, -> { where(status: 'not_started') }
  scope :recent, -> { order(updated_at: :desc) }

  enum :status, {
    not_started: 'not_started',
    in_progress: 'in_progress',
    completed: 'completed'
  }

  def course
    course_step.course_module.course
  end

  def course_module
    course_step.course_module
  end

  def start!
    return false unless not_started?

    update!(
      status: 'in_progress',
      started_at: Time.current
    )
  end

  def complete!(score = nil)
    return false if completed?

    update!(
      status: 'completed',
      completed_at: Time.current,
      score: score
    )
  end

  def time_spent
    return 0 unless started_at

    end_time = completed_at || Time.current
    ((end_time - started_at) / 60).round # in minutes
  end

  def overdue?
    return false unless started_at
    return false if completed?

    # Consider a step overdue if it's been in progress for more than expected duration + 50%
    expected_duration = course_step.duration_minutes || 30
    max_duration = expected_duration * 1.5

    time_spent > max_duration
  end

  def completion_percentage
    case status
    when 'not_started'
      0
    when 'in_progress'
      50 # Arbitrary middle point for in-progress
    when 'completed'
      100
    end
  end

  def passed?(passing_score = 70)
    return false unless completed?
    return true unless score # If no score recorded, assume passed

    score >= passing_score
  end

  # Class methods for progress analytics
  def self.completion_rate_for_course_step(course_step)
    total_users = where(course_step: course_step).count
    return 0 if total_users.zero?

    completed_users = where(course_step: course_step, status: 'completed').count
    (completed_users.to_f / total_users * 100).round(2)
  end

  def self.average_score_for_course_step(course_step)
    completed_progress = where(course_step: course_step, status: 'completed')
                        .where.not(score: nil)

    return 0 if completed_progress.empty?

    completed_progress.average(:score).to_f.round(2)
  end

  def self.average_time_for_course_step(course_step)
    completed_progress = where(course_step: course_step, status: 'completed')
                        .where.not(started_at: nil, completed_at: nil)

    return 0 if completed_progress.empty?

    total_time = completed_progress.sum do |progress|
      ((progress.completed_at - progress.started_at) / 60).round
    end

    (total_time.to_f / completed_progress.count).round(2)
  end

  # Get user's progress for an entire course
  def self.course_progress_for_user(user, course)
    course_steps = CourseStep.joins(course_module: :course)
                            .where(courses: { id: course.id })

    progress_records = where(user: user, course_step: course_steps)
                      .includes(:course_step)

    {
      total_steps: course_steps.count,
      completed_steps: progress_records.completed.count,
      in_progress_steps: progress_records.in_progress.count,
      completion_percentage: course_steps.count.zero? ? 0 : (progress_records.completed.count.to_f / course_steps.count * 100).round(2),
      progress_by_step: progress_records.index_by(&:course_step_id)
    }
  end

  private

  def update_course_progress_tracking
    # Log the progress change for debugging
    course = course_step.course_module.course
    course_progress = self.class.course_progress_for_user(user, course)

    Rails.logger.info "UserProgress updated for #{user.email}: #{course.title} - Step '#{course_step.title}' now #{status}. Overall progress: #{course_progress[:completion_percentage]}%"

    # Update legacy Progress model if it exists
    legacy_progress = user.progresses.find_by(course: course)
    if legacy_progress && status == 'completed'
      legacy_progress.update!(
        completed_steps: course_progress[:completed_steps]
      )
    end
  end
end
