# Document-Based Course Generation Update

## Overview

The `GenerateFullCourseJob` has been updated to generate course content exclusively from documents that are referenced in the conversation. This ensures that all generated content is based on actual uploaded documents rather than generic AI knowledge.

## Key Changes

### 1. Document Context Extraction
- **Function**: `extract_document_context()`
- **Purpose**: Extracts document references from conversation messages and loads document chunks
- **Process**:
  - Scans user messages for `@filename` patterns
  - Matches filenames to uploaded documents
  - Loads document chunks with embeddings
  - Returns structured context with chunks, documents, and IDs

### 2. Content Generation with Document Context
All content generation methods now include document context:

#### Module Content Generation
- **Method**: `build_module_content_prompt()`
- **Enhancement**: Includes up to 5 document excerpts in the prompt
- **Constraint**: Content must be based ONLY on referenced documents

#### Step Content Generation
- **Method**: `build_step_content_prompt()`
- **Enhancement**: Includes up to 3 relevant document excerpts
- **Constraint**: Examples and explanations must come FROM THE DOCUMENTS

#### Quiz Generation
- **Method**: `build_module_quiz_prompt()`
- **Enhancement**: Includes up to 8 document excerpts for broader question coverage
- **Constraint**: All questions and answers must be based on DOCUMENT CONTENT

### 3. Enhanced Logging and UI
- **Logging**: Reports number of documents and chunks used in generation
- **Progress UI**: Updated to show "Generating content from your documents"
- **Completion UI**: Updated to mention "detailed content from your documents"

## Document Reference Format

Users reference documents in conversations using the `@filename` pattern:
```
Create a course about security using @security_guide.pdf @best_practices.md
```

## Benefits

1. **Accuracy**: Content is based on actual organizational documents
2. **Relevance**: Material is specific to the company's processes and guidelines
3. **Consistency**: All content aligns with documented procedures
4. **Quality**: Reduces AI hallucination by constraining to document content

## Fallback Behavior

If no documents are referenced in the conversation:
- System logs a warning about missing document context
- Generic educational content is generated as fallback
- UI still functions normally but content may be less specific

## Technical Implementation

### Document Context Structure
```ruby
{
  chunks: [DocumentChunk objects with embeddings],
  documents: [Document objects],
  document_ids: [Array of referenced document IDs]
}
```

### Prompt Structure
Each generation prompt now includes:
1. Course/module/step context (as before)
2. Document excerpts section with clear labeling
3. Explicit instructions to use ONLY document content
4. Warnings against including external knowledge

## Testing

To test document-based generation:
1. Upload documents to the admin interface
2. Start a conversation referencing documents with @filename
3. Generate a course structure
4. Generate full course content
5. Verify that content reflects document information

## Monitoring

Look for these log entries:
- `"Extracting document context from conversation X"`
- `"Found Y referenced documents in conversation"`
- `"Loaded Z chunks from Y documents for full course generation"`
- `"Documents used: X (Y chunks)"` in generation summary

This ensures complete traceability of document usage in course generation.
