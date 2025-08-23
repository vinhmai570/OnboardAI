class Course < ApplicationRecord
  belongs_to :admin, class_name: 'User'
  has_many :steps, dependent: :destroy
  has_many :progresses, dependent: :destroy
  has_many :users, through: :progresses

  # Validations
  validates :title, presence: true
  validates :prompt, presence: true

  # Scopes
  scope :published, -> { where.not(structure: nil) }
  scope :draft, -> { where(structure: nil) }

  def published?
    structure.present?
  end

  def draft?
    !published?
  end
end
