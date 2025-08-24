# PostgreSQL JSON DISTINCT Query Fix

## Issue Description

The application was encountering a PostgreSQL error when trying to execute queries with `DISTINCT` on tables containing JSON columns:

```
ActiveRecord::StatementInvalid in ProgressController#index
PG::UndefinedFunction: ERROR: could not identify an equality operator for type json
LINE 1: SELECT DISTINCT "courses".* FROM "courses" INNER JOIN "cours...
```

## Root Cause

PostgreSQL cannot perform `DISTINCT` operations on tables with JSON columns because JSON type doesn't have a defined equality operator for determining uniqueness across all columns. This affects queries like:

```ruby
Course.joins(...).distinct
```

When the `courses` table contains JSON columns (`task_list`, `structure`), PostgreSQL cannot determine which records are distinct.

## Solution

Instead of using `.distinct` on all columns, we specify which columns to use for the DISTINCT operation:

### Before (Problematic)
```ruby
Course.joins(course_modules: { course_steps: :user_progresses })
      .where(user_progresses: { user: current_user })
      .distinct
```

### After (Fixed)
```ruby
# For count operations
Course.joins(course_modules: { course_steps: :user_progresses })
      .where(user_progresses: { user: current_user })
      .select('DISTINCT courses.id')
      .count

# For retrieving records
course_ids = Course.joins(course_modules: { course_steps: :user_progresses })
                  .where(user_progresses: { user: current_user })
                  .select('DISTINCT courses.id')
                  .pluck(:id)

Course.where(id: course_ids).includes(course_modules: :course_steps)
```

## Files Modified

1. **app/controllers/progress_controller.rb**
   - `courses_with_progress` method: Used two-step approach to first get distinct IDs, then fetch full records
   - `calculate_overall_stats` method: Used `select('DISTINCT courses.id')` for count operation

2. **app/controllers/admin/progress_analytics_controller.rb**
   - `courses_with_progress` method: Used `select('DISTINCT courses.id')` for count operation

3. **app/controllers/admin/dashboard_controller.rb**
   - `courses_with_progress` method: Used `select('DISTINCT courses.id')` for count operation

4. **app/controllers/admin/quizzes_controller.rb**
   - Course query: Used `select('DISTINCT courses.*').group('courses.id')` approach

## Prevention

When working with tables containing JSON columns in PostgreSQL:

1. **Avoid** using `.distinct` without specifying columns
2. **Use** `select('DISTINCT table.id')` when you only need unique records by ID
3. **Use** two-step queries: first get IDs, then fetch full records if needed
4. **Consider** using `.group()` instead of `.distinct` when appropriate

## JSON Columns in Schema

The following tables contain JSON columns that can cause this issue:

- `courses`: `task_list`, `structure`
- `progresses`: `quiz_scores`  
- `steps`: `quiz_questions`

Any query using `.distinct` on these tables needs to be carefully constructed to avoid the equality operator error.
