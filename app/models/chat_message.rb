class ChatMessage < ApplicationRecord
  belongs_to :conversation

  enum :message_type, {
    user_prompt: 'user_prompt',
    ai_overview: 'ai_overview',
    ai_detailed: 'ai_detailed',
    system_message: 'system_message'
  }

  validates :message_type, presence: true
  validates :content, presence: true

  scope :chronological, -> { order(:created_at) }
  scope :user_messages, -> { where(message_type: 'user_prompt') }
  scope :ai_messages, -> { where(message_type: ['ai_overview', 'ai_detailed']) }

  def display_content
    case message_type
    when 'user_prompt'
      user_prompt.presence || content
    when 'ai_overview', 'ai_detailed'
      ai_response.presence || content
    else
      content
    end
  end

  def user_message?
    message_type == 'user_prompt'
  end

  def ai_message?
    message_type.in?(['ai_overview', 'ai_detailed'])
  end
end
