class EmbeddingGenerationJob < ApplicationJob
  queue_as :default

  def perform(document_chunk)
    return unless ENV['OPENAI_ACCESS_TOKEN'].present?

    embedding = OpenaiService.generate_embedding(document_chunk.content)

    if embedding
      document_chunk.update!(embedding: embedding)
      Rails.logger.info "Generated embedding for chunk #{document_chunk.id}"
    else
      Rails.logger.error "Failed to generate embedding for chunk #{document_chunk.id}"
    end
  end
end
