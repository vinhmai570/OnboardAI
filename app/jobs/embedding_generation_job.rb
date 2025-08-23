class EmbeddingGenerationJob < ApplicationJob
  queue_as :default

  def perform(document_chunk)
    Rails.logger.info "Starting embedding generation for chunk #{document_chunk.id} (document: #{document_chunk.document.title})"

    # Check if chunk already has embedding
    if document_chunk.embedding.present?
      Rails.logger.info "Chunk #{document_chunk.id} already has embedding - skipping"
      return
    end

    embedding = OpenaiService.generate_embedding(document_chunk.content)

    if embedding && embedding.is_a?(Array)
      document_chunk.update!(embedding: embedding)
      Rails.logger.info "✅ Successfully generated and saved embedding for chunk #{document_chunk.id} (#{embedding.length} dimensions)"
    else
      Rails.logger.error "❌ Failed to generate embedding for chunk #{document_chunk.id} - received: #{embedding.class}"
      # Optionally retry later
      raise "Embedding generation failed" if embedding.nil?
    end

  rescue => e
    Rails.logger.error "❌ Embedding generation failed for chunk #{document_chunk.id}: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    raise e # Re-raise to allow job retry mechanisms
  end
end
