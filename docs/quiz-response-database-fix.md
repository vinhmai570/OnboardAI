# Quiz Response Database Schema Fix

## Issue Description

When users attempted to save progress on short answer questions in quizzes, the application was throwing a `PG::NotNullViolation` error:

```
PG::NotNullViolation: ERROR: null value in column "quiz_question_option_id" of relation "quiz_responses" violates not-null constraint
```

## Root Cause

The original database migration for `quiz_responses` (file: `20250823102335_create_quiz_responses.rb`) incorrectly defined the `quiz_question_option` reference as `null: false`:

```ruby
t.references :quiz_question_option, null: false, foreign_key: true
```

However, the QuizResponse model correctly defined the association as optional:

```ruby
belongs_to :quiz_question_option, optional: true
```

This created a conflict because:
- Multiple choice and true/false questions require a selected option (quiz_question_option_id)
- Short answer questions only need response text and should have `quiz_question_option_id` as NULL
- The database constraint prevented saving NULL values, but the application logic required it for short answer questions

## Solution

Created and ran migration `20250823150929_allow_null_quiz_question_option_in_quiz_responses.rb` to fix the constraint:

```ruby
class AllowNullQuizQuestionOptionInQuizResponses < ActiveRecord::Migration[8.0]
  def change
    # Allow quiz_question_option_id to be null for short answer questions
    change_column_null :quiz_responses, :quiz_question_option_id, true
  end
end
```

## Technical Details

### Question Types and Response Structure

1. **Multiple Choice & True/False Questions:**
   - Require `quiz_question_option_id` (not null)
   - `response_text` is null
   - Validation in model ensures option is selected

2. **Short Answer Questions:**
   - `quiz_question_option_id` is null
   - Require `response_text` (not null)
   - Validation in model ensures text response is provided

### Validation Logic

The QuizResponse model has an `appropriate_response_type` validation that ensures:
- Multiple choice/true-false questions must have an option selected
- Short answer questions must have response text and no option selected

### Controller Logic

The `QuizzesController#save_progress` method handles different question types appropriately:
- Sets `quiz_question_option = nil` for short answer questions
- Sets `response_text` for short answer questions
- Sets `quiz_question_option` for multiple choice/true-false questions

## Files Modified

1. **New Migration:** `db/migrate/20250823150929_allow_null_quiz_question_option_in_quiz_responses.rb`
2. **Documentation:** `docs/quiz-response-database-fix.md` (this file)

## Testing

After applying the migration, short answer questions should now save progress correctly without throwing database constraint violations. The PATCH request to `/quizzes/:id/save_progress.json` should succeed for all question types.

## Date

Fixed on August 23, 2025
