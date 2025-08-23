class DocumentProcessingService
  CHUNK_SIZE = 1000 # characters
  CHUNK_OVERLAP = 200 # characters

  def self.process(document)
    new(document).process
  end

  def initialize(document)
    @document = document
  end

  def process
    text = extract_text_from_file
    return if text.blank?

    chunks = split_into_chunks(text)
    create_document_chunks(chunks)
  end

  private

  def extract_text_from_file
    case @document.file.content_type
    when "application/pdf"
      extract_pdf_text
    when "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      extract_docx_text
    when "text/plain", "text/markdown"
      extract_text_file
    else
      Rails.logger.error "Unsupported file type: #{@document.file.content_type}"
      nil
    end
  end

  def extract_pdf_text
    require "pdf-reader"

    reader = PDF::Reader.new(@document.file.download)
    text = reader.pages.map(&:text).join("\n\n")
    text.strip
  rescue => e
    Rails.logger.error "PDF extraction error: #{e.message}"
    nil
  end

  def extract_docx_text
    require "docx"

    # Save the file temporarily since docx gem needs a file path
    temp_file = Tempfile.new([ "document", ".docx" ])
    temp_file.binmode
    temp_file.write(@document.file.download)
    temp_file.close

    doc = Docx::Document.open(temp_file.path)
    text = doc.paragraphs.map(&:text).join("\n\n")

    temp_file.unlink
    text.strip
  rescue => e
    Rails.logger.error "DOCX extraction error: #{e.message}"
    temp_file&.unlink
    nil
  end

  def extract_text_file
    @document.file.download.force_encoding("UTF-8")
  rescue => e
    Rails.logger.error "Text file extraction error: #{e.message}"
    nil
  end

  def split_into_chunks(text)
    chunks = []
    sentences = text.split(/[.!?]+/).map(&:strip).reject(&:empty?)

    current_chunk = ""
    chunk_order = 1

    sentences.each do |sentence|
      # Add sentence to current chunk if it fits
      potential_chunk = current_chunk.empty? ? sentence : "#{current_chunk}. #{sentence}"

      if potential_chunk.length <= CHUNK_SIZE
        current_chunk = potential_chunk
      else
        # Save current chunk and start new one
        if current_chunk.present?
          chunks << {
            content: current_chunk.strip,
            order: chunk_order
          }
          chunk_order += 1
        end

        # Handle overlap - take last part of previous chunk
        if current_chunk.length > CHUNK_OVERLAP
          overlap = current_chunk.last(CHUNK_OVERLAP)
          current_chunk = "#{overlap} #{sentence}"
        else
          current_chunk = sentence
        end
      end
    end

    # Add the last chunk
    if current_chunk.present?
      chunks << {
        content: current_chunk.strip,
        order: chunk_order
      }
    end

    chunks
  end

  def create_document_chunks(chunks)
    Rails.logger.info "Creating #{chunks.length} chunks for document: #{@document.title}"

    created_chunks = 0
    failed_chunks = 0

    chunks.each do |chunk_data|
      chunk = @document.document_chunks.build(
        content: chunk_data[:content],
        chunk_order: chunk_data[:order]
      )

      if chunk.save
        created_chunks += 1
        Rails.logger.info "✅ Created chunk #{chunk_data[:order]} for document #{@document.id}"

        # Generate embedding asynchronously
        EmbeddingGenerationJob.perform_later(chunk)
        Rails.logger.info "🚀 Queued embedding generation for chunk #{chunk.id}"
      else
        failed_chunks += 1
        Rails.logger.error "❌ Failed to save chunk #{chunk_data[:order]}: #{chunk.errors.full_messages}"
      end
    end

    Rails.logger.info "📊 Document processing summary - Created: #{created_chunks}, Failed: #{failed_chunks}"
  end
end
