class Document < ApplicationRecord
  belongs_to :user
  has_many :document_chunks, dependent: :destroy

  # File attachment
  has_one_attached :file

  # Validations
  validates :title, presence: true
  validates :file, presence: true

  # Callbacks
  after_create :process_document

  private

  def process_document
    DocumentProcessingJob.perform_later(self)
  end
end
