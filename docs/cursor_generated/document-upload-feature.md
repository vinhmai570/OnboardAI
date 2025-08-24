# Document Upload Feature Documentation

## Overview

The Document Upload feature allows administrators to upload documents that will be processed for AI-powered course generation and content creation. This feature is a core component of the OnboardAI platform's document management system.

## Key Features

### 📁 **Supported File Formats**
- **PDF Documents** (.pdf)
- **Microsoft Word** (.docx, .doc)
- **Plain Text** (.txt)
- **Markdown** (.md)

### 📏 **File Specifications**
- **Maximum File Size**: 10 MB
- **File Validation**: Automatic validation of file type and size
- **Secure Storage**: Files stored using Rails Active Storage

### 🚀 **User Experience Features**
- **Drag & Drop Upload**: Users can drag files directly onto the upload area
- **File Preview**: Shows selected file name and size before upload
- **Visual Feedback**: Interactive upload area with hover effects
- **Error Handling**: Clear error messages for invalid files
- **Progress Tracking**: Visual indicators for processing status

### 🤖 **AI Processing Pipeline**
1. **File Upload**: Document stored securely using Active Storage
2. **Text Extraction**: Automatic parsing of PDF, Word, and text files
3. **Content Chunking**: Document split into manageable segments
4. **Embedding Generation**: AI embeddings created for semantic search (when OpenAI key configured)
5. **Database Storage**: Processed content stored for course generation

## Technical Implementation

### Models
- **Document Model**: Core document management with file attachments
- **DocumentChunk Model**: Stores processed text segments with embeddings
- **Background Jobs**: Async processing for heavy operations

### Controllers
- **Admin::DocumentsController**: Full CRUD operations for document management
- **DocumentProcessingJob**: Background job for file processing
- **EmbeddingGenerationJob**: AI embedding generation

### Routes
```ruby
namespace :admin do
  resources :documents do
    member do
      post :process_document
    end
  end
end
```

## User Guide

### For Administrators

#### Uploading Documents

1. **Access Upload Form**
   - Login as admin (admin@onboardai.com / password)
   - Navigate to Admin Dashboard → Manage Documents
   - Click "Upload Document"

2. **Fill Document Information**
   - **Title**: Enter a descriptive title for the document
   - **File**: Select or drag & drop your file

3. **Upload Methods**
   - **Click Upload**: Click "Upload a file" to browse and select
   - **Drag & Drop**: Drag files directly onto the upload area
   - **File Preview**: Selected file name and size will be displayed

4. **Validation**
   - File type must be PDF, Word, Text, or Markdown
   - File size must be under 10 MB
   - Title is required

5. **Processing**
   - Document automatically queued for processing
   - Processing status visible in documents list
   - "Processing..." shows during processing
   - Green badge with chunk count shows when complete

#### Managing Documents

1. **View Documents**
   - All uploaded documents listed with metadata
   - File type, size, upload date, and uploader information
   - Processing status indicators

2. **Edit Documents**
   - Click "Edit" to update document title
   - View current file information and processing status
   - Cannot change file after upload (security feature)

3. **Process Documents**
   - Click "Process" to manually trigger processing
   - Useful if initial processing failed
   - Creates text chunks and embeddings

4. **Delete Documents**
   - Click "Delete" with confirmation prompt
   - Removes document and all associated chunks
   - Irreversible action

### For Developers

#### File Processing Flow

```ruby
# 1. Document uploaded via form
@document = current_user.documents.build(document_params)
@document.save

# 2. Automatic processing triggered
DocumentProcessingJob.perform_later(@document)

# 3. Text extraction based on file type
case document.file.content_type
when 'application/pdf'
  extract_pdf_text
when 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  extract_docx_text
when 'text/plain'
  extract_text_file
end

# 4. Text chunking for AI processing
chunks = split_into_chunks(text, chunk_size: 1000, overlap: 200)

# 5. Embedding generation (if OpenAI configured)
EmbeddingGenerationJob.perform_later(chunk)
```

#### Model Validations

```ruby
class Document < ApplicationRecord
  validates :title, presence: true
  validates :file, presence: true
  validate :acceptable_file

  private

  def acceptable_file
    return unless file.attached?
    # File type validation
    # File size validation (10MB max)
  end
end
```

## Business Benefits

### Content Creation Efficiency
- **Rapid Course Development**: Upload existing documents to generate courses
- **Knowledge Reuse**: Transform existing documentation into interactive training
- **Automated Processing**: No manual content preparation needed

### AI-Powered Features
- **Semantic Search**: Find relevant content across all documents
- **Context-Aware Generation**: AI uses document content for accurate course creation
- **Intelligent Chunking**: Optimized text segments for better AI processing

### Security & Compliance
- **Secure File Storage**: Enterprise-grade file handling with Rails Active Storage
- **File Validation**: Prevents malicious uploads
- **Access Control**: Admin-only upload permissions
- **Audit Trail**: Track who uploaded what and when

## Sample Upload Testing

A sample document has been created for testing:
- **Location**: `sample_documents/developer_onboarding_guide.md`
- **Content**: Comprehensive developer onboarding guide with multiple sections
- **Format**: Markdown with code examples and structured content
- **Use Case**: Perfect for testing course generation from existing documentation

## Troubleshooting

### Common Issues

1. **File Too Large**
   - **Error**: "File must be less than 10MB"
   - **Solution**: Compress or split the document

2. **Unsupported File Type**
   - **Error**: "Must be a PDF, Word document, plain text, or markdown file"
   - **Solution**: Convert to supported format

3. **Processing Stuck**
   - **Symptom**: Document shows "Processing..." indefinitely
   - **Solution**: Click "Process" button to retry processing

4. **Upload Failed**
   - **Cause**: Network issues or server errors
   - **Solution**: Refresh page and try again

### Development Issues

1. **Active Storage Not Working**
   ```bash
   # Install Active Storage
   rails active_storage:install
   rails db:migrate
   ```

2. **Missing Gems**
   ```bash
   # Install document processing gems
   bundle install
   ```

3. **Background Jobs Not Processing**
   ```bash
   # Check background job configuration
   # Ensure Solid Queue is properly set up
   ```

## Future Enhancements

### Planned Features
- **Batch Upload**: Upload multiple documents at once
- **File Preview**: Preview document content before processing
- **Version Control**: Track document updates and versions
- **Advanced Filters**: Search and filter documents by type, date, etc.
- **Export Options**: Download processed chunks and embeddings

### AI Enhancements
- **Multi-language Support**: Process documents in various languages
- **Advanced Chunking**: Smart content-aware text segmentation
- **Document Classification**: Auto-categorize documents by content type
- **Quality Scoring**: Rate document quality for course generation

The Document Upload feature provides a solid foundation for content-driven AI course generation, making OnboardAI a powerful platform for transforming existing documentation into engaging learning experiences!
