class Conversation < ApplicationRecord
  belongs_to :user
  has_many :chat_messages, dependent: :destroy
  has_many :courses, dependent: :destroy

  validates :title, presence: true
  validates :session_id, presence: true

  scope :recent, -> { order(updated_at: :desc) }

  def last_message_at
    chat_messages.maximum(:created_at) || created_at
  end

  def message_count
    chat_messages.count
  end

  def generate_title_from_prompt(prompt)
    # Generate a title from the first user prompt
    title = prompt.strip.truncate(50, omission: '...')
    title = title.gsub(/@\w+/, '').strip # Remove document references
    title.present? ? title : "Course Generation #{Time.current.strftime('%m/%d %H:%M')}"
  end

  # Check if conversation has a default/generic title that should be replaced
  def has_default_title?
    default_title_patterns = [
      /^New Conversation \d+\/\d+/,        # "New Conversation 08/23 08:49"
      /^Course Generation \d+\/\d+/        # "Course Generation 08/23 08:49"
    ]

    default_title_patterns.any? { |pattern| title.match?(pattern) }
  end

  # Trigger automatic title generation if conditions are met
  def generate_title_if_needed
    return unless should_generate_title?

    Rails.logger.info "Scheduling title generation for conversation #{id}"
    GenerateConversationTitleJob.perform_later(id)
  end

  # Schedule title generation with a delay to allow for message completion
  def schedule_title_generation(delay: 10.seconds)
    return unless should_generate_title?

    Rails.logger.info "Scheduling delayed title generation for conversation #{id}"
    GenerateConversationTitleJob.set(wait: delay).perform_later(id)
  end

  private

    def should_generate_title?
    # Only generate if:
    # 1. Conversation has messages
    # 2. Current title looks like a default title
    # 3. Has at least one AI response (conversation has progressed)
    chat_messages.exists? &&
    has_default_title? &&
    chat_messages.where(message_type: ['ai_overview', 'ai_detailed']).exists?
  end
end
