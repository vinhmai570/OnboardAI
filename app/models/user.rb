class User < ApplicationRecord
  has_secure_password

  # Associations
  has_many :documents, dependent: :destroy
  has_many :progresses, dependent: :destroy
  has_many :courses, foreign_key: :admin_id, dependent: :destroy

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
end
