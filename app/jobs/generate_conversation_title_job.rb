class GenerateConversationTitleJob < ApplicationJob
  queue_as :default

  def perform(conversation_id)
    Rails.logger.info "Starting title generation for conversation #{conversation_id}"

    conversation = Conversation.find_by(id: conversation_id)
    unless conversation
      Rails.logger.error "Conversation #{conversation_id} not found for title generation"
      return
    end

    # Only generate title if conversation has messages and still has default title
    unless should_generate_title?(conversation)
      Rails.logger.info "Skipping title generation for conversation #{conversation_id} - conditions not met"
      Rails.logger.info "  - Has messages: #{conversation.chat_messages.exists?}"
      Rails.logger.info "  - Has default title: #{conversation.has_default_title?}"
      Rails.logger.info "  - Has AI response: #{conversation.chat_messages.where(message_type: ['ai_overview', 'ai_detailed']).exists?}"
      Rails.logger.info "  - Current title: '#{conversation.title}'"
      return
    end

    # Generate the title using OpenAI
    generated_title = OpenaiService.generate_conversation_title(conversation)

    if generated_title.present?
      conversation.update!(title: generated_title)
      Rails.logger.info "Updated conversation #{conversation_id} title to: '#{generated_title}'"

      # Broadcast the update to the frontend if needed
      broadcast_title_update(conversation)
    else
      Rails.logger.warn "Failed to generate title for conversation #{conversation_id}"
    end

  rescue => e
    Rails.logger.error "Title generation job failed for conversation #{conversation_id}: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
  end

  private

    def should_generate_title?(conversation)
    # Check if conversation has messages
    return false unless conversation.chat_messages.exists?

    # Check if title looks like default format (contains timestamp or "New Conversation")
    default_title_patterns = [
      /^New Conversation \d+\/\d+/,        # "New Conversation 08/23 08:49"
      /^Course Generation \d+\/\d+/        # "Course Generation 08/23 08:49"
    ]

    has_default_title = default_title_patterns.any? { |pattern| conversation.title.match?(pattern) }

    # Also check if conversation has progressed (has AI response)
    has_ai_response = conversation.chat_messages.where(message_type: ['ai_overview', 'ai_detailed']).exists?

    has_default_title && has_ai_response
  end

    def broadcast_title_update(conversation)
    # Broadcast individual conversation update to provide real-time title updates
    current_user_id = conversation.user_id

    Rails.logger.info "Broadcasting title update for conversation #{conversation.id} to user #{current_user_id}"

    # Update individual conversation item (more efficient than updating entire list)
    Turbo::StreamsChannel.broadcast_replace_to(
      "course_generator",
      target: "conversation-#{conversation.id}",
      partial: "admin/course_generator/conversation_item",
      locals: { conversation: conversation }
    )

    # Also update the conversation title text directly for immediate feedback
    Turbo::StreamsChannel.broadcast_update_to(
      "course_generator",
      target: "conversation-title-#{conversation.id}",
      html: conversation.title
    )

    # Show a subtle notification that the title has been updated
    broadcast_title_notification(conversation)

    Rails.logger.info "Title update broadcast completed for conversation #{conversation.id}"
  rescue => e
    Rails.logger.error "Failed to broadcast title update: #{e.message}"
    Rails.logger.error e.backtrace.first(3).join("\n")
    # Don't fail the job if broadcast fails
  end

  def broadcast_title_notification(conversation)
    # Show a brief notification when a title is updated
    notification_html = %{
      <div class="fixed top-4 right-4 z-50 bg-green-50 border border-green-200 rounded-lg px-4 py-2 shadow-lg">
        <div class="flex items-center space-x-2">
          <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
          </svg>
          <span class="text-sm text-green-800 font-medium">Conversation title updated</span>
        </div>
        <div class="text-xs text-green-600 mt-1">"#{conversation.title}"</div>
      </div>
      <script>
        setTimeout(() => {
          const notification = document.querySelector('.fixed.top-4.right-4');
          if (notification) {
            notification.style.transition = 'opacity 0.3s ease';
            notification.style.opacity = '0';
            setTimeout(() => notification.remove(), 300);
          }
        }, 3000);
      </script>
    }.strip

    Rails.logger.info "Broadcasting title notification for conversation #{conversation.id}"

    Turbo::StreamsChannel.broadcast_append_to(
      "course_generator",
      target: "body",
      html: notification_html
    )
  rescue => e
    Rails.logger.warn "Title notification broadcast failed: #{e.message}"
    # This is optional functionality, don't fail the job
  end
end
