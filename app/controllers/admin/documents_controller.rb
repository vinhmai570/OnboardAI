class Admin::DocumentsController < ApplicationController
  before_action :require_admin
  before_action :set_document, only: [:edit, :update, :destroy, :process_document]

  def index
    @documents = Document.includes(:user).order(created_at: :desc)
  end

  def new
    @document = current_user.documents.build
  end

  def create
    @document = current_user.documents.build(document_params)

    if @document.save
      redirect_to admin_documents_path, notice: 'Document was successfully uploaded and is being processed.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @document.update(document_params)
      redirect_to admin_documents_path, notice: 'Document was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    document_title = @document.title
    chunks_count = @document.document_chunks.count

    begin
      # Delete the document (this will also delete associated chunks due to dependent: :destroy)
      @document.destroy!
      Rails.logger.info "Successfully deleted document '#{document_title}' with #{chunks_count} chunks"

      redirect_to admin_documents_path,
                  notice: "Document '#{document_title}' and its #{chunks_count} chunks were successfully deleted."
    rescue => e
      Rails.logger.error "Failed to delete document '#{document_title}': #{e.message}"
      redirect_to admin_documents_path,
                  alert: "Failed to delete document '#{document_title}'. Please try again."
    end
  end

  def process_document
    DocumentProcessingJob.perform_later(@document)
    redirect_to admin_documents_path, notice: 'Document processing started.'
  end

  def bulk_delete
    document_ids = params[:document_ids]&.reject(&:blank?)

    if document_ids.blank?
      redirect_to admin_documents_path, alert: 'No documents selected for deletion.'
      return
    end

    documents = Document.where(id: document_ids)
    total_documents = documents.count
    total_chunks = documents.joins(:document_chunks).count

    begin
      documents.destroy_all
      Rails.logger.info "Bulk deleted #{total_documents} documents with #{total_chunks} total chunks"

      redirect_to admin_documents_path,
                  notice: "Successfully deleted #{total_documents} documents and #{total_chunks} associated chunks."
    rescue => e
      Rails.logger.error "Bulk delete failed: #{e.message}"
      redirect_to admin_documents_path,
                  alert: "Failed to delete some documents. Please try again."
    end
  end

  private

  def set_document
    @document = Document.find(params[:id])
  end

  def document_params
    params.require(:document).permit(:title, :file)
  end
end
