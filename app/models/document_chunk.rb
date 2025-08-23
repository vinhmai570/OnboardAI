class DocumentChunk < ApplicationRecord
  belongs_to :document

  # Vector search configuration
  has_neighbors :embedding

  # Validations
  validates :content, presence: true
  validates :chunk_order, presence: true, uniqueness: { scope: :document_id }

  # Scopes
  scope :ordered, -> { order(:chunk_order) }

  # Class method for semantic search
  def self.search_similar(query_embedding, limit: 5)
    nearest_neighbors(:embedding, query_embedding, distance: "cosine").limit(limit)
  end
end
