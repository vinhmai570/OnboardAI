# AI Hackathon Project: OnboardAI

## Project Purpose

Create an intuitive platform, OnboardAI, to simplify and personalize the onboarding process by transforming documents into customized, interactive onboarding journeys.

## Feature Prioritization

### Main Features (Must-Have for Hackathon)

1. **Document Management**

   - Upload and manage documents in multiple formats (PDF, Word, Markdown).
   - Generate embeddings for document chunks using OpenAI (via ruby-openai gem) and store in PostgreSQL with pgvector for semantic search.
   - *Implementation*: Use Rails for file uploads, parse and chunk documents, integrate OpenAI for embeddings.

2. **Custom Onboarding Course Creation**

   - **Step 1: Generate Task List**
     - Admins input an AI prompt (e.g., "Design a path for a junior developer, including environment setup and pull request best practices, referencing {uploaded document}").
     - AI (OpenAI via ruby-openai) generates a list of tasks/steps, augmented with document chunk content using Neighbor for retrieval.
     - Admins can edit, add, remove, or sort (drag-and-drop) tasks in the list using Hotwired and Tailwind UI.
   - **Step 2: Generate Detailed Course**
     - After reviewing the task list, admins click "Generate Details" to create the final course with detailed content and quizzes for each step.
     - Course displayed in a developer-friendly, documentation-style UI with a sidebar listing steps.
     - Admins can edit step content post-generation in a Markdown-like editor.
   - *Implementation*: Rails backend with OpenAI for content generation, Hotwired for dynamic UI, Tailwind for styling.

3. **Interactive Course Interface**

   - Users view the course with a sidebar of steps, each containing content and a quiz (requiring a specific percentage of correct answers to pass).
   - *Implementation*: ERB views with Tailwind, Hotwired for quiz submissions and progress updates.

4. **AI Chat Assistant**

   - A right-sidebar AI chat (powered by OpenAI) provides real-time user support, using document chunk embeddings for context-aware responses.
   - *Implementation*: Integrate ruby-openai for chat completions, Neighbor for embedding-based context retrieval.

5. **Team and Course Management**

   - Admins can add, update, or remove users and assign courses to them.
   - Track user progress (e.g., completed steps, quiz scores).
   - *Implementation*: Rails models for Users, Courses, and Progress; basic CRUD for team management.

6. **Mock Login for User and Admin**

   - Build a login screen for mock login functionality.
   - *Implementation*: Simple Rails authentication with Tailwind-styled login page.

### TODO Features (Lower Priority, Post-Hackathon)

- **Seamless Integration with GitHub/Notion/Google Drive**
  - Sync documents from external platforms using APIs (OAuth for authentication).
  - *Reason*: Time-intensive API integration; focus on core upload functionality first.
- **Progress Analytics Dashboard**
  - Visualize user progress with completion rates and quiz performance.
  - *Reason*: Requires additional frontend work (e.g., Chart.js); basic progress tracking sufficient for hackathon.

## Example Workflow

1. Admin uploads a guide document (e.g., "Junior Developer Setup Guide").
2. Document is chunked, and embeddings are generated for each chunk.
3. Admin inputs an AI prompt to generate a task list for the onboarding path.
4. Admin edits/adds/removes tasks in the list, then clicks "Generate Details" to create the detailed course with steps and quizzes.
5. Users access the course, complete steps, take quizzes, and interact with the AI chat assistant.
6. Admins assign courses, manage users, and monitor progress.
7. Admins can update course content post-generation as needed.

## Technical Documentation

### Tech Stack

- **Backend Framework**: Ruby on Rails (MVC for routes, controllers, models).
- **Database**: PostgreSQL with pgvector (for storing user data, courses, and chunk embeddings).
- **Vector Search**: Neighbor gem (for semantic search on document chunk embeddings).
- **AI Integration**: OpenAI API (via ruby-openai gem for course generation, quizzes, and chat).
- **Frontend Styling**: Tailwind CSS (for responsive UI).
- **Frontend Interactivity**: Hotwired (Turbo for dynamic updates, Stimulus for interactive elements).

### Architecture Overview

- **Document Processing and Chunking**:

  - Uploaded documents are parsed and split into smaller chunks (e.g., by paragraph or fixed size, \~500-1000 characters per chunk) to optimize embedding generation and retrieval.
  - Each chunk is processed with OpenAI's embedding model (via ruby-openai) to create vector representations.
  - Embeddings are stored in PostgreSQL using pgvector, with metadata linking chunks to their source document.
  - Neighbor gem enables efficient similarity searches across chunk embeddings for RAG (Retrieval-Augmented Generation).

- **Course Generation**:

  - **Task List**: OpenAI generates a list of tasks based on the admin’s prompt, augmented with relevant document chunks retrieved via Neighbor.
  - **Detailed Course**: After admin edits the task list, OpenAI generates detailed content and quizzes for each step, stored as JSON in the Course model.
  - Editable via Hotwired/Tailwind UI, with Markdown-like editor for post-generation updates.

- **Chat Assistant**: OpenAI-powered chat uses Neighbor to retrieve relevant document chunks for context-aware responses.

- **User Management**: Rails models for Users, Courses, Steps, Quizzes, Progress.

- **Frontend**: ERB views, Tailwind for styling, Hotwired for dynamic updates (e.g., drag-and-drop, quiz submissions).

### Setup Instructions

1. **Prerequisites**:
   - Ruby 3.3.x, Rails 8.x.
   - PostgreSQL 14+ with pgvector extension.
   - OpenAI API key(Azure provider).

### Key Models (Example Schema)

- **User**: `id, email, role (admin/user)`.
- **Document**: `id, file_path, user_id`.
- **DocumentChunk**: `id, document_id, content (text), embedding (vector), chunk_order (integer)`.
- **Course**: `id, title, prompt, task_list (json), structure (json), admin_id`.
- **Step**: `id, course_id, order, content (text), quiz_questions (json)`.
- **Progress**: `id, user_id, course_id, completed_steps, quiz_scores (json)`.

### Document Chunking Details

- **Chunking Strategy**:
  - Parse documents (PDF, Word, Markdown) using libraries like `pdf-reader` or `ruby-docx` for extraction.
  - Split text into chunks based on natural boundaries (e.g., paragraphs, headings) or fixed lengths (\~500-1000 characters) to balance context and embedding efficiency.
  - Store each chunk in the `DocumentChunk` model with its embedding and order.
- **Embedding Generation**:
  - Use OpenAI’s embedding model (e.g., `text-embedding-ada-002`) via ruby-openai to generate vectors for each chunk.
  - Store embeddings in pgvector for similarity searches.
- **Retrieval**:
  - Neighbor gem performs cosine similarity searches on chunk embeddings to retrieve relevant content for course generation and chat responses.
  - Example: For a prompt referencing a document, retrieve top-k chunks to augment OpenAI’s input.

This setup ensures OnboardAI can handle large documents efficiently, enabling precise retrieval for AI-driven features while maintaining hackathon feasibility.
