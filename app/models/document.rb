class Document < ApplicationRecord
  belongs_to :user
  has_many :document_chunks, dependent: :destroy

  # File attachment
  has_one_attached :file

  # Validations
  validates :title, presence: true
  validates :file, presence: true
  validate :acceptable_file

  # Callbacks - Use after_commit to ensure file is fully attached
  after_commit :process_document, on: :create

  # Instance methods
  def processing_complete?
    document_chunks.any?
  end

  def processing_status
    return "completed" if processing_complete?
    return "processing" if created_at > 1.minute.ago
    return "failed" if created_at < 5.minutes.ago && !processing_complete?
    "processing"
  end

  def processing_failed?
    processing_status == "failed"
  end

  def embeddings_complete?
    return false unless processing_complete?
    document_chunks.where(embedding: nil).empty?
  end

  def embeddings_progress
    return 0 if document_chunks.empty?
    chunks_with_embeddings = document_chunks.where.not(embedding: nil).count
    total_chunks = document_chunks.count
    (chunks_with_embeddings.to_f / total_chunks * 100).round(1)
  end

  def ai_ready?
    processing_complete? && embeddings_complete?
  end

  def file_size_human
    return unless file.attached?
    number_to_human_size(file.byte_size)
  end

  def file_type
    return unless file.attached?
    case file.content_type
    when "application/pdf"
      "PDF"
    when "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      "Word Document"
    when "application/msword"
      "Word Document (Legacy)"
    when "text/plain"
      "Plain Text"
    when "text/markdown"
      "Markdown"
    else
      "Unknown"
    end
  end

  private

  def acceptable_file
    return unless file.attached?

    acceptable_types = [ "application/pdf", "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                        "application/msword", "text/plain", "text/markdown" ]

    unless acceptable_types.include?(file.content_type)
      errors.add(:file, "must be a PDF, Word document, plain text, or markdown file")
    end

    if file.byte_size > 10.megabytes
      errors.add(:file, "must be less than 10MB")
    end
  end

  def process_document
    return unless file.attached?

    Rails.logger.info "Starting processing for document: #{title} (ID: #{id})"
    DocumentProcessingJob.perform_later(self)
  rescue => e
    Rails.logger.error "Failed to queue document processing for #{title}: #{e.message}"
  end

  def number_to_human_size(size)
    return "0 Bytes" if size == 0
    k = 1024
    sizes = [ "Bytes", "KB", "MB", "GB" ]
    i = (Math.log(size) / Math.log(k)).floor
    (size / (k ** i)).round(2).to_s + " " + sizes[i]
  end
end
