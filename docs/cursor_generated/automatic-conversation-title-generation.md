# Automatic Conversation Title Generation

## Overview

The OnboardAI platform now automatically generates meaningful titles for conversations using OpenAI's GPT-3.5-turbo model. This feature replaces generic timestamps like "New Conversation 08/23 08:49" with descriptive titles based on the actual conversation content.

## How It Works

### 1. Title Generation Trigger
- Title generation is automatically triggered after an AI response is saved to a conversation
- Only conversations with default/generic titles are processed
- The system waits 5 seconds after the AI response to ensure the conversation has settled

### 2. Title Generation Process
The system analyzes:
- **User Messages**: First 3 user prompts from the conversation (up to 800 characters)
- **AI Responses**: First 2 AI responses for additional context (up to 400 characters)
- **Content Cleanup**: Removes document references (like @filename) and surrounding quotes

### 3. AI-Generated Titles
The OpenAI service creates titles that are:
- **Concise**: 3-6 words maximum, under 50 characters
- **Descriptive**: Captures the main topic or purpose
- **Professional**: Uses title case formatting
- **Clean**: Removes implementation details and document references

## Technical Implementation

### Components

#### 1. OpenaiService.generate_conversation_title
- **Location**: `app/services/openai_service.rb`
- **Purpose**: Calls OpenAI GPT-3.5-turbo to generate meaningful titles
- **Parameters**: Takes a `Conversation` object
- **Returns**: Generated title string or nil if failed

```ruby
# Example usage
title = OpenaiService.generate_conversation_title(conversation)
```

#### 2. GenerateConversationTitleJob
- **Location**: `app/jobs/generate_conversation_title_job.rb`
- **Purpose**: Background job that handles title generation asynchronously
- **Features**:
  - Validates conversation exists and needs title generation
  - Handles errors gracefully without failing other processes
  - Broadcasts updates to frontend via Turbo Streams

#### 3. Conversation Model Methods
- **Location**: `app/models/conversation.rb`
- **New Methods**:
  - `has_default_title?`: Checks if title looks like default format
  - `schedule_title_generation(delay:)`: Schedules title generation with delay
  - `should_generate_title?`: Validates if title generation is needed

#### 4. Integration Points
- **GenerateCourseJob**: Triggers title generation after saving AI responses
- **GenerateDetailedCourseJob**: Triggers title generation after detailed responses

### Automatic Trigger Conditions

Title generation only occurs when ALL conditions are met:

1. **Has Messages**: Conversation contains chat messages
2. **Default Title**: Current title matches default patterns:
   - `/^New Conversation \d+\/\d+/` (e.g., "New Conversation 08/23 08:49")
   - `/^Course Generation \d+\/\d+/` (e.g., "Course Generation 08/23 08:49")
3. **Has AI Response**: At least one AI response exists (conversation has progressed)

### Error Handling

The system handles various error scenarios:
- **OpenAI API Failures**: Logs errors but doesn't disrupt chat functionality
- **Missing Conversations**: Gracefully skips title generation
- **Network Issues**: Background job retry mechanism handles temporary failures
- **Invalid Responses**: Validates and cleans generated titles

## Example Title Transformations

| Before | After |
|--------|-------|
| New Conversation 08/23 08:49 | Employee Onboarding Process |
| New Conversation 08/23 14:32 | API Integration Guide |
| Course Generation 08/23 09:15 | Security Best Practices |
| New Conversation 08/23 16:45 | Database Migration Steps |

## Configuration

### OpenAI Settings
- **Model**: `gpt-3.5-turbo` (optimized for speed and cost)
- **Temperature**: `0.3` (focused, consistent responses)
- **Max Tokens**: `20` (short, concise titles)

### Timing Settings
- **Delay**: 5 seconds after AI response
- **Queue**: Background job queue (`:default`)

## Real-Time Updates with Turbo Streams

### Live Title Broadcasting
The system now provides **real-time updates** when conversation titles are generated:

#### Individual Conversation Updates
- **Targeted Updates**: Only the specific conversation item updates, not the entire list
- **Smooth Transitions**: No page refresh or flashing - seamless UI updates
- **Immediate Feedback**: Titles change instantly when generated

#### Visual Notifications
- **Success Notifications**: Green notification appears when title is updated
- **Auto-dismiss**: Notifications fade out after 3 seconds
- **Professional Design**: Clean, non-intrusive alerts

#### Broadcasting Channels
- **Primary Channel**: `course_generator` - main broadcast channel
- **Individual Targeting**: Each conversation has unique DOM ID for precise updates
- **Fallback Support**: Graceful degradation if broadcasting fails

### Technical Implementation

#### Turbo Stream Actions
1. **Replace Individual Item**: Updates specific conversation without affecting others
2. **Update Title Text**: Direct text replacement for immediate visual feedback
3. **Append Notification**: Shows success message to user

#### DOM Structure
- **Conversation Container**: `#conversation-{id}` for individual conversation updates
- **Title Element**: `#conversation-title-{id}` for direct title text updates
- **Notification Target**: `body` for floating success messages

## Benefits

1. **User Experience**: Easily identify conversations from meaningful titles
2. **Organization**: Better conversation management in the sidebar
3. **Navigation**: Quickly find specific topics without opening conversations
4. **Professional**: Clean, descriptive titles instead of timestamps
5. **Real-Time Updates**: See title changes instantly without page refresh
6. **Visual Feedback**: Clear notifications when titles are updated

## Monitoring

The feature includes comprehensive logging:
- Title generation requests
- OpenAI API calls and responses
- Success/failure rates
- Performance metrics

Check Rails logs for entries containing:
- `"Generating title for conversation"`
- `"Updated conversation X title to"`
- `"OpenAI Title Generation Error"`

## Testing Real-Time Updates

### Available Rake Tasks

#### Test Title Generation with Broadcasting
```bash
# Test specific conversation with real-time updates
rails conversations:test_title[CONVERSATION_ID]

# Generate titles for all eligible conversations
rails conversations:generate_titles

# Test broadcasting functionality only
rails conversations:test_broadcast
```

### Live Testing Steps
1. **Open the admin interface** in your browser
2. **Start a new conversation** or switch to existing one with default title
3. **Send a message** and wait for AI response
4. **Watch for real-time title update** - should happen within 5-10 seconds
5. **Look for green notification** confirming the title change

### What You'll See
- ✅ **Instant Title Update**: Conversation title changes in sidebar without page refresh
- ✅ **Success Notification**: Green alert appears saying "Conversation title updated"
- ✅ **Smooth Animation**: No flashing or jarring UI changes

## Future Enhancements

Potential improvements for future versions:
- User ability to manually edit generated titles
- Custom title generation rules per user/organization
- Multi-language title generation support
- Title generation for existing conversations (migration script)
- Real-time title preview during generation
- Title generation history and rollback
