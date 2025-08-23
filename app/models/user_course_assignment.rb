class UserCourseAssignment < ApplicationRecord
  belongs_to :user
  belongs_to :course
  belongs_to :assigned_by, class_name: "User"

  # Validations
  validates :user_id, uniqueness: { scope: :course_id, message: "is already assigned to this course" }
  validates :assigned_at, presence: true

  # Scopes
  scope :for_user, ->(user) { where(user: user) }
  scope :for_course, ->(course) { where(course: course) }
  scope :recent, -> { order(assigned_at: :desc) }

  # Set assigned_at before creation if not already set
  before_create :set_assigned_at

  private

  def set_assigned_at
    self.assigned_at ||= Time.current
  end
end
