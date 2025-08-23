class DocumentProcessingJob < ApplicationJob
  queue_as :default

  def perform(document)
    DocumentProcessingService.process(document)
  end
end
