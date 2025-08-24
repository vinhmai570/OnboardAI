# Interactive Quiz System Documentation

## Overview

The OnboardAI platform now features a comprehensive, interactive quiz system that generates real quiz questions using AI, stores them in a structured database, and provides rich analytics and progress tracking. This system replaces the previous text-based quiz generation with actual interactive quizzes that users can take.

## System Architecture

### Database Schema

The quiz system uses a normalized database schema with the following key tables:

```
quizzes
├── id (primary key)
├── course_step_id (foreign key to course_steps)
├── title
├── description
├── total_points
├── time_limit_minutes
└── timestamps

quiz_questions
├── id (primary key)
├── quiz_id (foreign key to quizzes)
├── question_text
├── question_type (multiple_choice, true_false, short_answer)
├── points
├── order_position
├── explanation
└── timestamps

quiz_question_options
├── id (primary key)
├── quiz_question_id (foreign key to quiz_questions)
├── option_text
├── is_correct
├── order_position
└── timestamps

quiz_attempts
├── id (primary key)
├── user_id (foreign key to users)
├── quiz_id (foreign key to quizzes)
├── started_at
├── completed_at
├── score
├── total_points
├── time_spent_minutes
├── status (in_progress, completed, abandoned)
└── timestamps

quiz_responses
├── id (primary key)
├── quiz_attempt_id (foreign key to quiz_attempts)
├── quiz_question_id (foreign key to quiz_questions)
├── quiz_question_option_id (foreign key to quiz_question_options, nullable)
├── response_text (for short answer questions)
├── is_correct
├── points_earned
└── timestamps

user_progresses
├── id (primary key)
├── user_id (foreign key to users)
├── course_step_id (foreign key to course_steps)
├── status (not_started, in_progress, completed)
├── started_at
├── completed_at
├── score
└── timestamps
```

### Model Architecture

#### Core Models

**Quiz** (`app/models/quiz.rb`)
- Belongs to a course step
- Has many quiz questions and quiz attempts
- Provides methods for: `has_questions?`, `average_score`, `completion_rate`, `user_completed?`

**QuizQuestion** (`app/models/quiz_question.rb`)
- Supports three question types: multiple_choice, true_false, short_answer
- Has many options and responses
- Provides intelligent answer checking with `check_answer()` and `check_short_answer()`

**QuizAttempt** (`app/models/quiz_attempt.rb`)
- Manages quiz attempt lifecycle with status tracking
- Auto-calculates scores and timing
- Provides methods: `complete!`, `calculate_score!`, `passed?`, `answer_question!`

**UserProgress** (`app/models/user_progress.rb`)
- Tracks step-by-step learning progress
- Provides course-level completion analytics
- Status progression: not_started → in_progress → completed

### AI Integration

#### Structured Quiz Generation

The system uses OpenAI GPT-4 to generate structured quiz data in JSON format:

**OpenaiService.generate_quiz_json()** (`app/services/openai_service.rb`)
- Generates exactly 5 multiple choice + 3 true/false + 2 short answer questions
- Uses document context from uploaded files
- Returns validated JSON structure
- Handles markdown cleanup and error recovery

**Example AI-Generated Quiz Structure:**
```json
{
  "quiz": {
    "title": "Module 1 Quiz",
    "description": "Quiz covering key concepts from this module",
    "total_points": 100,
    "time_limit_minutes": 15,
    "questions": [
      {
        "question_text": "What is the primary purpose of...",
        "question_type": "multiple_choice",
        "points": 10,
        "order_position": 1,
        "explanation": "This tests understanding of...",
        "options": [
          {
            "option_text": "Option A text",
            "is_correct": false,
            "order_position": 1
          },
          {
            "option_text": "Option B text",
            "is_correct": true,
            "order_position": 2
          }
        ]
      }
    ]
  }
}
```

#### Document-Based Content

- Quiz questions are generated exclusively from uploaded document content
- The system extracts document mentions (`@filename`) from conversations
- Up to 8 document excerpts are provided to the AI as context
- Strict prompt instructions ensure AI only uses provided document content

### Controllers

#### User-Facing Controllers

**QuizzesController** (`app/controllers/quizzes_controller.rb`)
- `show` - Display quiz introduction or active quiz interface
- `start` - Initialize new quiz attempt
- `submit` - Process and score quiz submission
- `results` - Display detailed quiz results with question review

**ProgressController** (`app/controllers/progress_controller.rb`)
- `index` - User's learning progress dashboard
- `course_progress` - Detailed progress for specific course
- `start_step` / `complete_step` - AJAX endpoints for progress updates

#### Admin Controllers

**Admin::QuizzesController** (`app/controllers/admin/quizzes_controller.rb`)
- Full CRUD operations for quiz management
- `analytics` - Comprehensive quiz performance analytics
- `regenerate` - AI-powered quiz regeneration
- Detailed question difficulty analysis and user performance tracking

### User Interface

#### Interactive Quiz Taking

**Quiz Show View** (`app/views/quizzes/show.html.erb`)
- Progressive quiz interface with real-time progress tracking
- Support for all three question types with appropriate UI controls
- Timer functionality with warnings
- Auto-save and manual save options
- Visual feedback for answered/unanswered questions

**Stimulus Controller** (`app/javascript/controllers/quiz_controller.js`)
- Real-time progress updates
- Auto-save functionality
- Timer management with warnings
- Keyboard shortcuts (Ctrl+S to save, Ctrl+Enter to submit)
- Dynamic UI updates and notifications

#### Results and Analytics

**Quiz Results View** (`app/views/quizzes/results.html.erb`)
- Comprehensive score breakdown with visual progress bars
- Question-by-question review with correct answers
- Attempt history tracking
- Animated score displays

**Progress Dashboard** (`app/views/progress/index.html.erb`)
- Overall learning statistics
- Course-by-course progress tracking
- Interactive progress bars and completion tracking

**Admin Analytics Dashboard** (`app/views/progress/dashboard.html.erb`)
- System-wide learning analytics
- Course performance overview
- Top performers leaderboard
- Recent activity tracking

### Features

#### For Students

1. **Interactive Quiz Taking**
   - Multiple choice, true/false, and short answer questions
   - Real-time progress tracking
   - Auto-save functionality
   - Timer with warnings
   - Immediate results with detailed explanations

2. **Progress Tracking**
   - Course completion percentages
   - Quiz performance history
   - Time spent learning
   - Achievement tracking

3. **Retake Functionality**
   - Unlimited quiz retakes
   - Best score tracking
   - Attempt history
   - Performance improvement tracking

#### For Administrators

1. **Quiz Management**
   - View all quizzes across courses
   - Edit quiz properties (title, time limit, points)
   - Regenerate quizzes with new AI content
   - Delete underperforming quizzes

2. **Advanced Analytics**
   - Question difficulty analysis
   - User performance tracking
   - Course completion rates
   - Score distribution analysis

3. **Progress Monitoring**
   - Real-time learning activity
   - User engagement metrics
   - Course effectiveness measurement
   - Intervention opportunities identification

### Navigation

The system adds new navigation options to the main dashboard:

**For Users:**
- "My Progress" - Personal learning dashboard
- Enhanced course views with quiz integration

**For Admins:**
- "Quiz Management" - Comprehensive quiz administration
- "Learning Analytics" - System-wide analytics dashboard
- Enhanced admin dropdown with all management tools

### Integration Points

#### Course Generation Integration

The quiz system is fully integrated with the existing course generation workflow:

**GenerateFullCourseJob** (`app/jobs/generate_full_course_job.rb`)
- Automatically creates quiz records during course generation
- Uses document context for quiz content
- Creates quiz step as final module step
- Handles quiz creation errors gracefully

#### Progress Tracking Integration

**CourseStep Model Updates**
- Added `has_one :quiz` and progress tracking methods
- Methods: `has_quiz?`, `quiz_completed_by?`, `progress_for_user`

**User Model Updates**
- Added quiz and progress associations
- Analytics methods: `quiz_completion_rate_for_course`, `average_quiz_score`

### API Endpoints

#### User Quiz API
```
GET    /quizzes/:id          # Show quiz (intro or taking interface)
POST   /quizzes/:id/start    # Start new quiz attempt
PATCH  /quizzes/:id/submit   # Submit quiz responses
GET    /quizzes/:id/results  # View quiz results
```

#### Progress API
```
GET    /progress                              # User progress dashboard
GET    /progress/course/:course_id           # Course-specific progress
POST   /progress/step/:course_step_id/start  # Start course step
PATCH  /progress/step/:course_step_id/complete # Complete course step
```

#### Admin Quiz API
```
GET    /admin/quizzes                # Quiz management dashboard
GET    /admin/quizzes/:id           # Quiz details and questions
GET    /admin/quizzes/:id/analytics # Detailed quiz analytics
POST   /admin/quizzes/:id/regenerate # Regenerate quiz content
```

### Technical Implementation Details

#### Question Types

**Multiple Choice**
- 4 options per question
- Single correct answer support
- Visual radio button interface
- Automatic scoring

**True/False**
- Exactly 2 options ("True" and "False")
- Simple binary choice interface
- Quick completion design

**Short Answer**
- Text area input
- Simple string matching for auto-grading
- Exact match validation (case-insensitive)

#### Scoring Algorithm

```ruby
def calculate_score!
  total_points = 0
  earned_points = 0

  quiz.quiz_questions.each do |question|
    total_points += question.points

    response = quiz_responses.find_by(quiz_question: question)
    earned_points += response&.points_earned || 0
  end

  update_columns(score: earned_points, total_points: total_points)
end
```

#### Auto-Save Implementation

- Saves progress every 2 minutes if changes detected
- Manual save button available
- Visual feedback for save status
- AJAX requests to prevent data loss

#### Timer Implementation

- JavaScript-based countdown timer
- Visual warnings at 5 minutes remaining
- Automatic submission when time expires
- Grace period handling

### Performance Considerations

#### Database Optimization

- Proper indexing on foreign keys and frequently queried columns
- Efficient eager loading with `includes()` for associated data
- Pagination for large quiz lists
- Query optimization for analytics calculations

#### Frontend Performance

- Stimulus controllers for lightweight JavaScript interactions
- Progressive enhancement approach
- Minimal JavaScript dependencies
- CSS-based animations for smooth UI

#### Caching Strategy

- Quiz question caching for repeated access
- Analytics data caching for dashboard performance
- User progress caching for quick dashboard loads

### Security Considerations

#### Data Protection

- Proper parameter filtering in controllers
- SQL injection prevention through ActiveRecord
- CSRF protection on all forms
- User authentication required for all quiz operations

#### Access Control

- Users can only access their own quiz attempts and progress
- Admins have full system access
- Course-specific access controls
- Quiz attempt integrity protection

### Testing Strategy

#### Model Testing
```ruby
# Example test structure
describe Quiz do
  it "calculates average score correctly"
  it "determines user completion status"
  it "handles question associations properly"
end
```

#### Controller Testing
```ruby
describe QuizzesController do
  it "allows user to start new quiz attempt"
  it "prevents access to other users' attempts"
  it "handles quiz submission properly"
end
```

#### Integration Testing
```ruby
describe "Quiz taking flow" do
  it "completes full quiz workflow"
  it "updates progress tracking correctly"
  it "shows accurate results"
end
```

### Future Enhancement Opportunities

1. **Advanced Question Types**
   - Drag-and-drop ordering questions
   - Image-based questions
   - Code snippet questions
   - Matching questions

2. **Enhanced Analytics**
   - Learning path optimization
   - Predictive performance modeling
   - Personalized question difficulty
   - A/B testing for question effectiveness

3. **Mobile Optimization**
   - Progressive Web App (PWA) features
   - Offline quiz taking capability
   - Touch-optimized interfaces
   - Mobile-specific question types

4. **Integration Enhancements**
   - LTI (Learning Tools Interoperability) support
   - Third-party learning management system integration
   - API for external quiz platforms
   - Webhook notifications for progress updates

5. **AI Improvements**
   - Dynamic difficulty adjustment
   - Personalized question generation
   - Multi-language support
   - Context-aware question sequencing

### Troubleshooting Guide

#### Common Issues

**Quiz Generation Failures**
- Check OpenAI API connectivity and credentials
- Verify document context availability
- Review AI prompt structure for errors
- Monitor token limits and usage

**Progress Tracking Issues**
- Ensure proper foreign key relationships
- Check for race conditions in concurrent updates
- Verify user authentication state
- Monitor database constraint violations

**Performance Problems**
- Review database query patterns
- Check for N+1 query problems
- Monitor JavaScript console errors
- Verify proper caching implementation

### Deployment Notes

#### Environment Variables
```bash
# OpenAI Configuration (required for quiz generation)
OPENAI_API_KEY=your_openai_api_key_here
OPENAI_ORGANIZATION_ID=your_organization_id_here

# Database Configuration
DATABASE_URL=postgresql://user:pass@localhost/onboard_ai_production
```

#### Database Migrations
```bash
# Run all quiz-related migrations
rails db:migrate

# Verify quiz tables are created
rails db:schema:dump
```

#### Production Considerations
- Monitor OpenAI API usage and costs
- Set up proper logging for quiz generation
- Configure background job processing for quiz creation
- Implement proper error monitoring and alerting

---

This quiz system represents a significant enhancement to the OnboardAI platform, providing engaging, interactive learning experiences with comprehensive tracking and analytics capabilities. The system is designed to be scalable, maintainable, and user-friendly while providing rich data for optimizing the learning experience.
