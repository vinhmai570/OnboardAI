# CSRF Token Authenticity Fix for Dynamic Forms

## Issue Description

When users clicked "Generate Course Structure" button after course generation, they encountered a CSRF token authenticity error:

```
Can't verify CSRF token authenticity.
```

The error was occurring when making requests to `/admin/course_generator/generate_detailed` and could only be resolved by reloading the page.

## Root Cause

The issue was caused by stale CSRF tokens in dynamically rendered forms via Turbo streaming:

1. After course generation completes, a background job (`GenerateCourseJob`) broadcasts a form replacement via Turbo streaming
2. The form is rendered from within the background job context, not a controller context
3. The CSRF token in the dynamically rendered form becomes stale or invalid
4. When the user clicks the button, the form submission fails with CSRF authenticity error

## Technical Analysis

### Problem Flow
1. `GenerateCourseJob` calls `broadcast_generate_button` (lines 50, 115)
2. `broadcast_generate_button` uses `Turbo::StreamsChannel.broadcast_replace_to` to render the form
3. The partial `_generate_detailed_button.html.erb` was rendered without proper conversation context
4. The CSRF token in the dynamically rendered form was stale

### Location of Issue
- **Background Job**: `app/jobs/generate_course_job.rb` (lines 343-349)
- **Form Template**: `app/views/admin/course_generator/_generate_detailed_button.html.erb`
- **JavaScript**: `app/views/admin/course_generator/_chatgpt_style_script.html.erb`

## Solution Implemented

### 1. Fixed Background Job Context (generate_course_job.rb)

**Before:**
```ruby
def broadcast_generate_button
  Turbo::StreamsChannel.broadcast_replace_to(
    "course_generator",
    target: "generate-button-container",
    partial: "admin/course_generator/generate_detailed_button"
  )
end
```

**After:**
```ruby
def broadcast_generate_button
  Turbo::StreamsChannel.broadcast_replace_to(
    "course_generator",
    target: "generate-button-container",
    partial: "admin/course_generator/generate_detailed_button",
    locals: { conversation: @conversation }
  )
end
```

### 2. Added CSRF Token Refresh Function (JavaScript)

**Added to `_chatgpt_style_script.html.erb`:**
```javascript
// CSRF token refresh function for dynamically rendered forms
window.refreshCSRFToken = function(form) {
  const tokenInput = form.querySelector('input[name="authenticity_token"]');
  if (tokenInput) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]');
    if (csrfToken) {
      tokenInput.value = csrfToken.content;
    }
  }
};
```

### 3. Updated Form Button to Refresh Token

**Modified button click handler in `_generate_detailed_button.html.erb`:**
```erb
<input type="submit"
       value="Generate Course Structure"
       class="..."
       onclick="this.disabled=true; this.value='⏳ Generating structure...'; refreshCSRFToken(this.form); this.form.submit();" />
```

## How the Fix Works

1. **Dynamic Rendering**: When the background job renders the form via Turbo streaming, it now passes the conversation context properly
2. **Token Refresh**: Before form submission, JavaScript fetches the current CSRF token from the page's meta tags
3. **Form Update**: The hidden `authenticity_token` field is updated with the fresh token
4. **Clean Submission**: The form submits with a valid, current CSRF token

## Files Modified

1. **Background Job**: `app/jobs/generate_course_job.rb`
   - Added `locals: { conversation: @conversation }` to `broadcast_generate_button`

2. **JavaScript**: `app/views/admin/course_generator/_chatgpt_style_script.html.erb`
   - Added `refreshCSRFToken()` function

3. **Form Template**: `app/views/admin/course_generator/_generate_detailed_button.html.erb`
   - Updated button onclick to call `refreshCSRFToken(this.form)` before submission

4. **Documentation**: `docs/csrf-token-fix.md` (this file)

## Testing

After implementing the fix:
1. Generate a course overview using the AI generator
2. Wait for the "Generate Course Structure" button to appear
3. Click the button immediately without reloading the page
4. The request should succeed without CSRF errors

## Related Issues

This pattern can be applied to other dynamically rendered forms that might face similar CSRF token staleness issues when rendered via Turbo streaming from background jobs.

## Date

Fixed on August 23, 2025
