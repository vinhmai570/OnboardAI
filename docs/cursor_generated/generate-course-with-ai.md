# Generate Course with AI Feature

## Overview

The "Generate Course with AI" feature allows administrators to create comprehensive onboarding course structures using natural language prompts and document references. This chat-like interface leverages AI to generate detailed course outlines, modules, and assessments based on existing documentation.

## Key Features

### 🤖 **AI-Powered Course Generation**
- **Natural Language Prompts** - Describe courses in plain English
- **Document References** - Use `@document_id` to reference specific documents
- **Smart Context Integration** - AI uses document content to create relevant courses
- **Comprehensive Structure** - Generates modules, topics, assessments, and timelines

### 💬 **Chat Interface**
- **Interactive Experience** - Real-time conversation with AI assistant
- **Visual Feedback** - See prompts and responses in a clean chat interface
- **Loading Indicators** - Clear feedback during AI processing
- **Error Handling** - Graceful error messages and retry options

### 📄 **Document Mention System**
- **@ Mention Support** - Type `@` to reference documents by ID
- **Autocomplete Dropdown** - Search documents while typing
- **Visual References** - See referenced documents as badges
- **Click to Insert** - Click documents to insert references

## How to Access

### From Admin Dashboard
1. Login as admin (`admin@onboardai.com` / `password`)
2. Go to Admin Dashboard
3. Click **"Generate Course with AI"** in Quick Actions

### Direct URL
- **Route**: `/admin/course_generator`
- **Method**: GET

## User Interface Components

### **Left Panel: Document Library**
- **Available Documents** - List of all uploaded documents
- **Document Info** - Shows ID, title, chunk count, and AI readiness
- **Click to Reference** - Click any document to insert `@ID` reference
- **Usage Instructions** - Helpful tips and examples

### **Right Panel: Chat Interface**
- **Welcome Message** - Introduction and usage examples
- **Message History** - All conversation with timestamps
- **Input Area** - Text area with mention support
- **Referenced Documents** - Visual badges showing mentioned documents

### **Interactive Elements**
- **Mention Dropdown** - Real-time document search
- **Reference Badges** - Removable document references
- **Generate Button** - Starts AI course generation
- **Clear Button** - Resets the input field

## Usage Examples

### **Basic Course Generation**
```
Create a developer onboarding course
```

### **With Document References**
```
Create a comprehensive security training using @1 @3 @5
```

### **Specific Requirements**
```
Generate a 2-week onboarding program for new sales team members using our process documentation @2
```

### **Advanced Prompts**
```
Design an interactive course for remote developers covering Git workflows, coding standards, and deployment processes. Use @4 for Git guidelines and @7 for deployment procedures.
```

## AI Course Structure Output

### **Generated Content Includes:**
- **Course Title & Description** - Clear, descriptive course information
- **Learning Objectives** - Specific, measurable learning goals
- **Duration Estimate** - Realistic time estimates for completion
- **Difficulty Level** - Beginner, Intermediate, or Advanced
- **Modular Structure** - 3-5 modules with logical progression
- **Detailed Topics** - Specific topics with key points and activities
- **Assessment Suggestions** - Quizzes, assignments, and projects

### **Example Output Structure:**
```json
{
  "title": "Developer Onboarding Bootcamp",
  "description": "Comprehensive 3-week program for new developers",
  "objectives": [
    "Set up development environment",
    "Understand company coding standards",
    "Complete first feature implementation"
  ],
  "duration_estimate": "3 weeks",
  "difficulty_level": "Intermediate",
  "modules": [
    {
      "order": 1,
      "title": "Environment Setup",
      "description": "Get your development environment ready",
      "duration": "3-4 hours",
      "topics": [...]
    }
  ],
  "assessment_suggestions": [...]
}
```

## Technical Implementation

### **Backend Components**

#### **Controller**: `Admin::CourseGeneratorController`
- **`index`** - Main chat interface with document library
- **`generate`** - AI course generation endpoint
- **`search_documents`** - Document search for mentions

#### **OpenAI Service**: Enhanced with `generate_course_structure`
- **Prompt Engineering** - Specialized prompts for course creation
- **Context Integration** - Incorporates document chunks
- **JSON Output** - Structured course data
- **Error Handling** - Graceful API failures

#### **Routes**
```ruby
resources :course_generator, only: [:index] do
  collection do
    post :generate
    get :search_documents
  end
end
```

### **Frontend Features**

#### **JavaScript Functionality**
- **@ Mention Detection** - Real-time typing analysis
- **Document Search** - Fuzzy matching document titles
- **Reference Management** - Add/remove document mentions
- **AJAX Communication** - Asynchronous API calls
- **Dynamic UI Updates** - Real-time chat interface

#### **Document Reference System**
```javascript
// Detect @ mentions while typing
function handleMentionTyping(e) {
  // Extract @searchText patterns
  // Show dropdown with matching documents
  // Handle selection and insertion
}
```

#### **Chat Interface**
```javascript
// Add messages to chat
function addMessageToChat(type, content, sender) {
  // Create message elements
  // Apply styling and icons
  // Auto-scroll to bottom
}
```

## Database Changes

### **Migration: Remove `file_path` from Documents**
```ruby
class RemoveFilePathFromDocuments < ActiveRecord::Migration[8.0]
  def change
    remove_column :documents, :file_path, :string
  end
end
```

**Reason**: Using Active Storage for file management, making `file_path` column redundant.

## AI Integration Details

### **Prompt Engineering**
- **System Prompt** - Defines AI role and output format
- **Context Integration** - Includes referenced document content
- **JSON Schema** - Enforces consistent output structure
- **Error Recovery** - Handles malformed responses

### **Document Context Processing**
1. **Extract Mentions** - Parse `@ID` references from prompt
2. **Fetch Documents** - Load referenced documents with chunks
3. **Filter AI-Ready** - Only use documents with embeddings
4. **Combine Context** - Join all chunks into context string
5. **Generate Course** - Send to OpenAI with structured prompt

### **Example OpenAI Call**
```ruby
response = client.chat(
  parameters: {
    model: "gpt-4",
    messages: [
      {
        role: "system",
        content: build_course_structure_system_prompt
      },
      {
        role: "user",
        content: build_course_structure_prompt(prompt, context)
      }
    ],
    temperature: 0.7,
    max_tokens: 2000
  }
)
```

## Security & Access Control

### **Admin-Only Access**
- **Authentication Required** - `before_action :require_admin`
- **Role-Based Access** - Only admin users can access
- **CSRF Protection** - All forms protected against attacks

### **Input Validation**
- **Prompt Validation** - Ensures non-empty prompts
- **Document ID Extraction** - Safely parses mentions
- **SQL Injection Prevention** - Parameterized queries
- **XSS Protection** - HTML escaping in views

## Performance Considerations

### **Optimization Strategies**
- **Document Preloading** - `includes(:user, :document_chunks)`
- **Chunk Filtering** - Only AI-ready chunks used
- **Async Processing** - Non-blocking API calls
- **Response Caching** - Can be extended for repeated queries

### **Resource Management**
- **Token Limits** - Text truncation for API limits
- **Rate Limiting** - Can be added for API protection
- **Background Jobs** - Future enhancement for long operations

## Error Handling

### **Frontend Error Management**
- **Network Errors** - Connection failure messages
- **API Errors** - Server error display
- **Validation Errors** - Empty prompt warnings
- **JSON Parsing** - Malformed response handling

### **Backend Error Recovery**
- **OpenAI API Failures** - Graceful degradation
- **Document Not Found** - Skip invalid references
- **Database Errors** - Transaction rollbacks
- **Logging** - Comprehensive error tracking

## Future Enhancements

### **Planned Features**
- **Course Templates** - Predefined course structures
- **Export Options** - Download generated courses
- **Collaborative Editing** - Multiple admin input
- **Version History** - Track course iterations
- **Integration** - Direct course creation from generated structure

### **UI Improvements**
- **Rich Text Editor** - Enhanced input formatting
- **Drag & Drop** - File references via drag and drop
- **Preview Mode** - Live course structure preview
- **Mobile Support** - Responsive design enhancements

## Usage Tips

### **For Best Results**
1. **Be Specific** - Detailed prompts generate better courses
2. **Use References** - Mention relevant documents for context
3. **Iterate** - Refine prompts based on results
4. **Review Output** - AI-generated content should be reviewed

### **Common Patterns**
- **Role-Based Courses** - "Create course for [role]"
- **Topic-Specific** - "Generate training on [topic]"
- **Document-Driven** - "Build course using @1 @2 @3"
- **Time-Constrained** - "Create 2-week program for..."

The "Generate Course with AI" feature transforms OnboardAI into a powerful course creation platform, enabling administrators to rapidly develop comprehensive training programs using their existing documentation! 🚀🤖📚
