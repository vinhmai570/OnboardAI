class DocumentProcessingJob < ApplicationJob
  queue_as :default

  def perform(document)
    Rails.logger.info "Processing document: #{document.title} (ID: #{document.id})"

    unless document.file.attached?
      Rails.logger.error "No file attached to document #{document.id}"
      return
    end

    result = DocumentProcessingService.process(document)

    if document.document_chunks.any?
      Rails.logger.info "Successfully processed document #{document.id}: created #{document.document_chunks.count} chunks"
    else
      Rails.logger.warn "Document processing completed but no chunks created for document #{document.id}"
    end

    result
  rescue => e
    Rails.logger.error "Document processing failed for #{document.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e # Re-raise to allow job retry mechanisms
  end
end
