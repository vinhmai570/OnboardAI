class Course < ApplicationRecord
  belongs_to :admin, class_name: "User"
  belongs_to :conversation, optional: true
  has_many :steps, dependent: :destroy
  has_many :progresses, dependent: :destroy
  has_many :users, through: :progresses

  # New structured relationships
  has_many :course_modules, -> { order(:order_position) }, dependent: :destroy
  has_many :course_steps, through: :course_modules

  # Validations
  validates :title, presence: true
  validates :prompt, presence: true

  # Scopes
  scope :published, -> { where.not(structure: nil) }
  scope :draft, -> { where(structure: nil) }
  scope :with_modules, -> { includes(course_modules: :course_steps) }

  def published?
    structure.present? || course_modules.any?
  end

  def draft?
    !published?
  end

  def total_modules
    course_modules.count
  end

  def total_steps
    course_steps.count
  end

  def total_duration_hours
    course_modules.sum(:duration_hours)
  end

  def total_duration_minutes
    course_steps.sum(:duration_minutes)
  end

  def structured?
    course_modules.any?
  end
end
