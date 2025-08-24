class Course < ApplicationRecord
  belongs_to :admin, class_name: "User"
  belongs_to :conversation, optional: true
  has_many :steps, dependent: :destroy
  has_many :progresses, dependent: :destroy
  has_many :users, through: :progresses

  # New structured relationships
  has_many :course_modules, -> { order(:order_position) }, dependent: :destroy
  has_many :course_steps, through: :course_modules

  # Course assignment relationships
  has_many :user_course_assignments, dependent: :destroy
  has_many :assigned_users, through: :user_course_assignments, source: :user

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

  def status
    published? ? 'published' : 'draft'
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

  def full_content_generated?
    full_content_generated == true
  end

  def content_generation_progress
    return 0 if course_modules.empty?

    total_items = course_modules.count + course_steps.count
    generated_modules = course_modules.where(content_generated: true).count
    generated_steps = course_steps.where(content_generated: true).count

    ((generated_modules + generated_steps).to_f / total_items * 100).round
  end

  def quiz_count
    course_steps.where(step_type: 'assessment').count
  end

  def module_progress_for_user(user)
    return { total_modules: 0, completed_modules: 0, completion_percentage: 0, module_progress: [] } if course_modules.empty?
    
    total_modules = course_modules.count
    completed_modules = 0
    module_progress = []
    
    course_modules.includes(:course_steps).each do |course_module|
      is_completed = course_module.completed_by?(user)
      completion_percentage = course_module.completion_percentage_for_user(user)
      
      completed_modules += 1 if is_completed
      
      module_progress << {
        module: course_module,
        completed: is_completed,
        completion_percentage: completion_percentage,
        total_steps: course_module.course_steps.count,
        completed_steps: course_module.course_steps.count { |step| step.completed_by?(user) }
      }
    end
    
    overall_completion = total_modules > 0 ? (completed_modules.to_f / total_modules * 100).round(2) : 0
    
    {
      total_modules: total_modules,
      completed_modules: completed_modules,
      completion_percentage: overall_completion,
      module_progress: module_progress
    }
  end

  def description
    # Return the prompt as description, but make it more user-friendly
    # Remove any system-specific instructions and keep it concise
    return nil if prompt.blank?

    # For now, just return the prompt - could be enhanced to extract
    # description from structure JSON or other fields
    prompt
  end
end
