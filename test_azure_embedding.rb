#!/usr/bin/env ruby
# Test Azure OpenAI embedding integration

puts "🧪 Testing Azure OpenAI Embedding Integration"
puts "=" * 50

# Check environment configuration
puts "\n📋 Environment Configuration:"
puts "   AZURE_OPENAI_ENDPOINT: #{ENV['AZURE_OPENAI_ENDPOINT']&.slice(0, 30)}#{'...' if ENV['AZURE_OPENAI_ENDPOINT']&.length.to_i > 30}"
puts "   AZURE_OPENAI_API_KEY: #{ENV['AZURE_OPENAI_API_KEY'] ? '✅ Set' : '❌ Not set'}"
puts "   AZURE_OPENAI_EMBEDDINGS_DEPLOYMENT: #{ENV['AZURE_OPENAI_EMBEDDINGS_DEPLOYMENT'] || 'Not set'}"
puts "   OPENAI_ACCESS_TOKEN: #{ENV['OPENAI_ACCESS_TOKEN'] ? '✅ Set (fallback)' : '❌ Not set'}"

azure_configured = ENV['AZURE_OPENAI_ENDPOINT']&.present? && ENV['AZURE_OPENAI_API_KEY']&.present?
openai_configured = ENV['OPENAI_ACCESS_TOKEN']&.present?

puts "\n🔍 Configuration Status:"
puts "   Azure OpenAI: #{azure_configured ? '✅ Configured' : '❌ Not configured'}"
puts "   Regular OpenAI: #{openai_configured ? '✅ Configured' : '❌ Not configured'}"

if azure_configured
  puts "   Priority: 🔵 Using Azure OpenAI for embeddings"
elsif openai_configured
  puts "   Priority: 🟢 Using Regular OpenAI for embeddings"
else
  puts "   Priority: ⚠️ No embedding service configured"
  exit 1
end

# Test client creation
puts "\n🔧 Testing Client Creation:"
begin
  require_relative 'config/environment'

  # Test Azure client
  if azure_configured
    azure_client = OpenaiService.azure_embedding_client
    puts "   Azure OpenAI Client: ✅ Created successfully"
  end

  # Test regular client
  regular_client = OpenaiService.client
  puts "   Regular OpenAI Client: ✅ Created successfully"

rescue => e
  puts "   ❌ Client creation failed: #{e.message}"
  exit 1
end

# Test embedding generation
puts "\n🎯 Testing Embedding Generation:"
test_text = "This is a test document for Azure OpenAI embedding generation."

begin
  embedding = OpenaiService.generate_embedding(test_text)

  if embedding && embedding.is_a?(Array)
    puts "   ✅ Embedding generated successfully"
    puts "   📊 Dimensions: #{embedding.length}"
    puts "   🔢 Sample values: [#{embedding[0..2].map { |v| v.round(4) }.join(', ')}...]"
  else
    puts "   ❌ Embedding generation failed - invalid response format"
    puts "   📥 Received: #{embedding.class}"
  end

rescue => e
  puts "   ❌ Embedding generation failed: #{e.message}"
  puts "   🔍 Error details: #{e.class}"
end

puts "\n✨ Test completed!"
puts "=" * 50
