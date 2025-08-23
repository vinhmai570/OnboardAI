namespace :conversations do
  desc "Generate titles for conversations with default names"
  task generate_titles: :environment do
    puts "🔍 Finding conversations with default titles..."

    conversations = Conversation.all.select(&:has_default_title?)
    puts "Found #{conversations.count} conversations with default titles"

    conversations.each do |conversation|
      puts "\n📝 Conversation #{conversation.id}: '#{conversation.title}'"
      puts "   - Messages: #{conversation.chat_messages.count}"
      puts "   - AI responses: #{conversation.chat_messages.where(message_type: ['ai_overview', 'ai_detailed']).count}"
      puts "   - User messages: #{conversation.chat_messages.where(message_type: 'user_prompt').count}"

      if conversation.should_generate_title?
        puts "   ✅ Eligible for title generation - scheduling job"
        GenerateConversationTitleJob.perform_later(conversation.id)
      else
        puts "   ❌ Not eligible for title generation"
      end
    end

    puts "\n🎯 Title generation jobs scheduled for eligible conversations!"
  end

    desc "Test title generation for a specific conversation"
  task :test_title, [:conversation_id] => :environment do |t, args|
    conversation_id = args[:conversation_id]

    unless conversation_id
      puts "❌ Please provide a conversation ID: rake conversations:test_title[123]"
      exit
    end

    conversation = Conversation.find_by(id: conversation_id)
    unless conversation
      puts "❌ Conversation #{conversation_id} not found"
      exit
    end

    puts "🔍 Testing title generation for conversation #{conversation_id}"
    puts "   Current title: '#{conversation.title}'"
    puts "   Has default title: #{conversation.has_default_title?}"
    puts "   Should generate: #{conversation.should_generate_title?}"
    puts "   Messages: #{conversation.chat_messages.count}"
    puts "   AI messages: #{conversation.chat_messages.where(message_type: ['ai_overview', 'ai_detailed']).count}"

    if conversation.should_generate_title?
      puts "\n🚀 Generating title and broadcasting update..."
      title = OpenaiService.generate_conversation_title(conversation)
      if title.present?
        old_title = conversation.title
        conversation.update!(title: title)

        # Simulate the real-time broadcast
        puts "📡 Broadcasting title update via Turbo Streams..."
        GenerateConversationTitleJob.new.send(:broadcast_title_update, conversation)

        puts "✅ Title updated and broadcast!"
        puts "   Before: '#{old_title}'"
        puts "   After: '#{title}'"
        puts "   🎯 Check the web interface for real-time updates!"
      else
        puts "❌ Failed to generate title"
      end
    else
      puts "\n❌ Conversation is not eligible for title generation"
    end
  end

  desc "Test real-time broadcasting for all conversations"
  task test_broadcast: :environment do
    puts "📡 Testing Turbo Stream broadcasts for conversation title updates..."

    conversations = Conversation.all.limit(5)
    puts "Found #{conversations.count} conversations to test"

    conversations.each do |conversation|
      puts "\n🔄 Broadcasting update for conversation #{conversation.id}: '#{conversation.title}'"

      begin
        job = GenerateConversationTitleJob.new
        job.send(:broadcast_title_update, conversation)
        puts "   ✅ Broadcast sent successfully"
      rescue => e
        puts "   ❌ Broadcast failed: #{e.message}"
      end
    end

    puts "\n🎯 Check the web interface for real-time updates!"
  end
end
