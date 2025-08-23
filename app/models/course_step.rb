class CourseStep < ApplicationRecord
  belongs_to :course_module
  has_one :quiz, dependent: :destroy
  has_many :user_progresses, dependent: :destroy

  validates :title, presence: true
  validates :step_type, presence: true, inclusion: { in: %w[lesson exercise assessment reading] }
  validates :duration_minutes, presence: true, numericality: { greater_than: 0 }
  validates :order_position, presence: true, uniqueness: { scope: :course_module_id }

  scope :ordered, -> { order(:order_position) }
  scope :by_type, ->(type) { where(step_type: type) }

  before_validation :set_order_position, on: :create

  def lesson?
    step_type == 'lesson'
  end

  def assessment?
    step_type == 'assessment'
  end

  def exercise?
    step_type == 'exercise'
  end

  def reading?
    step_type == 'reading'
  end

  def icon
    case step_type
    when 'lesson' then '📖'
    when 'exercise' then '🏋️'
    when 'assessment' then '📊'
    when 'reading' then '📚'
    else '📝'
    end
  end

  def parsed_resources
    resources.present? ? JSON.parse(resources) : []
  rescue JSON::ParserError
    resources.to_s.split(',').map(&:strip)
  end

  def resources=(value)
    super(value.is_a?(Array) ? value.to_json : value)
  end

  def has_quiz?
    quiz.present?
  end

  def quiz_completed_by?(user)
    return false unless has_quiz?
    quiz.user_completed?(user)
  end

  def progress_for_user(user)
    user_progresses.find_by(user: user)
  end

  def completed_by?(user)
    progress_for_user(user)&.completed?
  end

  def started_by?(user)
    progress = progress_for_user(user)
    progress&.in_progress? || progress&.completed?
  end

  def move_up
    return false if order_position <= 1

    other_step = course_module.course_steps.where(order_position: order_position - 1).first
    return false unless other_step

    CourseStep.transaction do
      other_step.update!(order_position: order_position)
      self.update!(order_position: order_position - 1)
    end
  end

  def move_down
    max_position = course_module.course_steps.maximum(:order_position)
    return false if order_position >= max_position

    other_step = course_module.course_steps.where(order_position: order_position + 1).first
    return false unless other_step

    CourseStep.transaction do
      other_step.update!(order_position: order_position)
      self.update!(order_position: order_position + 1)
    end
  end

  private

  def set_order_position
    self.order_position ||= (course_module&.course_steps&.maximum(:order_position) || 0) + 1
  end
end
