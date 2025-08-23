class Admin::DocumentsController < ApplicationController
  before_action :require_admin
  before_action :set_document, only: [:show, :edit, :update, :destroy, :process_document]

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
    @document.destroy
    redirect_to admin_documents_path, notice: 'Document was successfully deleted.'
  end

  def process_document
    DocumentProcessingJob.perform_later(@document)
    redirect_to admin_documents_path, notice: 'Document processing started.'
  end

  private

  def set_document
    @document = Document.find(params[:id])
  end

  def document_params
    params.require(:document).permit(:title, :file)
  end
end
