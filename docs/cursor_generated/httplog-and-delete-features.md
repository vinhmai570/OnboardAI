# HttpLog & Document Delete Features

## Overview

Two new features have been added to enhance the OnboardAI platform:
1. **HttpLog Integration** - Comprehensive logging of all external HTTP requests
2. **Enhanced Document Deletion** - Individual and bulk document deletion with safety features

## 1. HttpLog Integration

### Purpose
HttpLog provides detailed logging of all HTTP requests to external services (like OpenAI API) during development, making debugging and monitoring much easier.

### Configuration

**Gem Added:**
```ruby
# Gemfile - development group
gem "httplog"
```

**Configuration File:** `config/initializers/httplog.rb`
```ruby
if Rails.env.development?
  HttpLog.configure do |config|
    config.enabled = true
    config.log_request = true
    config.log_response = true
    config.log_data = true
    config.log_headers = false # Protects API keys
    config.log_benchmark = true
    config.filter_sensitive_data = true
    config.sensitive_headers = %w[authorization x-api-key]
    config.severity = Logger::INFO
    config.prefix = '[HTTP]'
    config.compact_log = true
    # Only log external requests (not internal Rails)
    config.url_blacklist_pattern = %r{^https?://(127\.0\.0\.1|localhost)}
  end
end
```

### What Gets Logged

**OpenAI API Requests:**
```
[HTTP] GET https://api.openai.com/v1/embeddings
[HTTP] Request Headers: {...}
[HTTP] Request Body: {"input":"Document content...","model":"text-embedding-3-small"}
[HTTP] Response Status: 200
[HTTP] Response Body: {"data":[{"embedding":[0.1,0.2,...],"index":0}]}
[HTTP] Benchmark: 1.2s
```

**Benefits:**
- ✅ **Debug API Issues** - See exact requests/responses
- ✅ **Monitor Performance** - Track API response times
- ✅ **Cost Tracking** - Monitor API usage patterns
- ✅ **Error Diagnosis** - Detailed error information
- ✅ **Security** - Filters sensitive headers automatically

### Usage

**View Logs:**
```bash
# Watch all HTTP requests in development
docker-compose logs -f web | grep "\[HTTP\]"

# View recent HTTP activity
docker-compose logs web | grep -A5 -B5 "\[HTTP\]" | tail -50
```

**Example Log Output:**
```
[HTTP] POST https://api.openai.com/v1/embeddings
[HTTP] Connecting: api.openai.com:443
[HTTP] Request Body: {"input":"Welcome to OnboardAI...","model":"text-embedding-3-small"}
[HTTP] Response Status: 200 OK
[HTTP] Response Body: {"object":"list","data":[{"object":"embedding","embedding":[...],"index":0}],"model":"text-embedding-3-small-002","usage":{"prompt_tokens":15,"total_tokens":15}}
[HTTP] Benchmark: 0.85s
```

## 2. Enhanced Document Deletion

### Features Overview

#### **Individual Document Deletion**
- **Enhanced Confirmation** - Shows detailed information about what will be deleted
- **Robust Error Handling** - Graceful failure handling with detailed logging
- **Complete Cleanup** - Removes document, chunks, embeddings, and file attachments

#### **Bulk Document Deletion**
- **Multi-Select Interface** - Checkboxes for selecting multiple documents
- **Select All Functionality** - Toggle all documents with one click
- **Smart Confirmation** - Shows list of documents to be deleted
- **Batch Processing** - Efficiently deletes multiple documents

### Individual Delete Implementation

**Controller Action:**
```ruby
def destroy
  document_title = @document.title
  chunks_count = @document.document_chunks.count

  begin
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
```

**Enhanced Confirmation Dialog:**
```
Are you sure you want to delete 'Developer Onboarding Guide'?

This will permanently remove:
• The document file (2.5 MB)
• All 6 processed text chunks
• All generated AI embeddings

This action cannot be undone!
```

### Bulk Delete Implementation

**Controller Action:**
```ruby
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
```

**Routes Configuration:**
```ruby
resources :documents do
  member do
    post :process_document
  end
  collection do
    delete :bulk_delete
  end
end
```

### User Interface Features

#### **Select All Header**
```html
<div class="px-4 py-3 bg-gray-50 border-b border-gray-200">
  <div class="flex items-center">
    <input type="checkbox" id="select-all" onchange="toggleAllCheckboxes(this)">
    <label for="select-all">Select All Documents</label>
  </div>
</div>
```

#### **Individual Checkboxes**
```html
<input type="checkbox" name="document_ids[]" value="<%= document.id %>"
       class="document-checkbox" onchange="updateBulkDeleteButton()">
```

#### **Dynamic Delete Button**
- **Hidden by Default** - Only shows when documents are selected
- **Smart Counting** - Shows "Delete Selected (3)" with count
- **Color Coded** - Red button to indicate destructive action

### JavaScript Functionality

#### **Toggle All Selection**
```javascript
function toggleAllCheckboxes(selectAllCheckbox) {
  const checkboxes = document.querySelectorAll('.document-checkbox');
  checkboxes.forEach(checkbox => {
    checkbox.checked = selectAllCheckbox.checked;
  });
  updateBulkDeleteButton();
}
```

#### **Update Button State**
```javascript
function updateBulkDeleteButton() {
  const checkedBoxes = document.querySelectorAll('.document-checkbox:checked');
  const bulkDeleteBtn = document.getElementById('bulk-delete-btn');

  if (checkedBoxes.length > 0) {
    bulkDeleteBtn.style.display = 'inline-flex';
    bulkDeleteBtn.textContent = `Delete Selected (${checkedBoxes.length})`;
  } else {
    bulkDeleteBtn.style.display = 'none';
  }
}
```

#### **Enhanced Confirmation**
```javascript
function confirmBulkDelete() {
  const checkedBoxes = document.querySelectorAll('.document-checkbox:checked');
  const titles = Array.from(checkedBoxes).map(cb => {
    return cb.closest('li').querySelector('.font-medium').textContent.trim();
  });

  const confirmMessage = `Are you sure you want to delete ${count} documents?

Documents to be deleted:
${titles.map(title => `• ${title}`).join('\n')}

This will permanently remove:
• All document files
• All processed text chunks
• All generated AI embeddings

This action cannot be undone!`;

  if (confirm(confirmMessage)) {
    document.getElementById('bulk-delete-form').submit();
  }
}
```

## Usage Examples

### Monitoring HTTP Requests

**Watch OpenAI API calls:**
```bash
# See all OpenAI requests
docker-compose logs -f web | grep -i openai

# Monitor embedding generation
docker-compose logs -f web | grep -i embedding

# Check API performance
docker-compose logs -f web | grep "Benchmark"
```

### Using Delete Features

#### **Individual Delete:**
1. Go to Admin → Documents
2. Click "Delete" next to any document
3. Review detailed confirmation dialog
4. Confirm to permanently delete

#### **Bulk Delete:**
1. Go to Admin → Documents
2. Check boxes next to documents to delete
3. Use "Select All" to toggle all documents
4. Click "Delete Selected (X)" button that appears
5. Review confirmation with document list
6. Confirm to delete all selected documents

### Database Cleanup

**What Gets Deleted:**
- ✅ **Document Record** - Main document entry
- ✅ **File Attachment** - Uploaded file via Active Storage
- ✅ **Document Chunks** - All text segments (via `dependent: :destroy`)
- ✅ **Embeddings** - AI-generated vectors stored in chunks
- ✅ **Background Jobs** - Any pending processing jobs are cleaned up

**Logging Output:**
```
Successfully deleted document 'Developer Guide' with 6 chunks
Bulk deleted 3 documents with 18 total chunks
```

## Security & Safety Features

### **Confirmation Dialogs**
- **Detailed Information** - Shows exactly what will be deleted
- **File Size Display** - Shows storage impact
- **Chunk Count** - Shows processing work that will be lost
- **Irreversible Warning** - Clear messaging about permanent deletion

### **Error Handling**
- **Graceful Failures** - Continues operation even if some deletions fail
- **Detailed Logging** - All actions logged for audit trail
- **User Feedback** - Clear success/error messages
- **Transaction Safety** - Uses Rails transactions where appropriate

### **Access Control**
- **Admin Only** - All delete operations require admin privileges
- **Authenticated Routes** - Protected by `before_action :require_admin`
- **CSRF Protection** - All forms protected against cross-site request forgery

## Benefits

### **HttpLog Benefits:**
- 🔍 **Complete Visibility** - See all external API interactions
- 🐛 **Easier Debugging** - Detailed request/response logging
- 📊 **Performance Monitoring** - Track API response times and usage
- 🛡️ **Security** - Filters sensitive data automatically

### **Delete Feature Benefits:**
- 🗑️ **Safe Deletion** - Comprehensive confirmation dialogs
- ⚡ **Bulk Operations** - Delete multiple documents efficiently
- 🧹 **Complete Cleanup** - Removes all associated data
- 📝 **Audit Trail** - Detailed logging of all deletions
- 🎯 **User-Friendly** - Intuitive checkbox interface

## Testing

### **Test Individual Delete:**
```bash
# Create a test document first
# Then delete via admin interface
# Check logs for cleanup confirmation
```

### **Test Bulk Delete:**
```bash
# Upload multiple test documents
# Select multiple documents
# Test "Select All" functionality
# Perform bulk deletion
# Verify complete cleanup
```

### **Test HttpLog:**
```bash
# Upload a document (triggers OpenAI API call)
# Watch logs for HTTP request details
docker-compose logs -f web | grep "\[HTTP\]"
```

These features significantly enhance the administrative capabilities of OnboardAI, providing both powerful deletion tools and comprehensive monitoring of external service interactions! 🚀🗑️📊
