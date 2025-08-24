# Authentication and Role-Based Access Control System

## Overview

The OnboardAI application now enforces comprehensive authentication and role-based access control to ensure proper security and user experience separation between admin and regular users.

## Implementation Details

### Core Authentication System

**ApplicationController (`app/controllers/application_controller.rb`)**

The base controller implements the following authentication mechanisms:

- `before_action :require_login` - Enforced on all controllers by default
- Helper methods: `current_user`, `logged_in?`, `admin?`
- `require_admin` - Ensures only admin users can access admin functionality
- `require_user_role` - Enforces role-based route separation

### Role-Based Access Control

#### Admin Users
- **Access**: Only admin namespaced routes (`/admin/*`)
- **Redirections**: Admin users accessing user routes are automatically redirected to admin dashboard
- **Controllers**: All `Admin::*Controller` classes use `before_action :require_admin`

#### Regular Users  
- **Access**: Only user-facing routes (courses, progress, quizzes, dashboard, chat)
- **Redirections**: Regular users accessing admin routes are automatically redirected to user dashboard
- **Controllers**: All user controllers use `before_action :require_user_role`

### Route Protection Strategy

#### Admin Routes (`/admin/*`)
- All admin controllers inherit `before_action :require_admin`
- Admin users are redirected to user dashboard if they attempt direct access to user routes
- Examples: Admin Dashboard, Course Generator, User Management, Document Management

#### User Routes  
- All user-facing controllers use `before_action :require_user_role`
- Regular users are redirected to user dashboard if they attempt admin route access
- Examples: Courses, Progress, Quizzes, Chat, User Dashboard

### Authentication Flow

1. **Login** (`SessionsController`)
   - Validates user credentials
   - Sets `session[:user_id]`
   - Redirects admin users to `/admin/dashboard`
   - Redirects regular users to `/dashboard`

2. **Route Access**
   - Every request checks authentication via `require_login`
   - Role-based filtering via `require_user_role` or `require_admin`
   - Automatic redirection based on user role and attempted route

3. **Logout** (`SessionsController#destroy`)
   - Clears `session[:user_id]`
   - Redirects to login page

### Security Enhancements

#### Centralized Authentication
- Removed duplicate authentication methods from individual controllers
- Standardized on ApplicationController's authentication system
- Consistent error handling and redirection logic

#### Controller Cleanup
- **Fixed**: `Admin::QuizzesController` now uses standard `require_admin` instead of custom `ensure_admin`
- **Removed**: Duplicate `current_user` methods from multiple controllers
- **Removed**: Duplicate `authenticate_user!` methods from multiple controllers  
- **Standardized**: All controllers now rely on ApplicationController's authentication

### Route Separation Examples

#### Before Implementation
- Admin users could access user routes directly
- Regular users could potentially access admin routes
- Inconsistent authentication methods across controllers

#### After Implementation  
- **Admin accessing** `/courses` → **Redirected to** `/admin/dashboard`
- **User accessing** `/admin/courses` → **Redirected to** `/dashboard`
- **Unauthenticated accessing any route** → **Redirected to** `/login`

### Course Access Control

Regular users can only access courses that are:
- Published courses assigned to them via `UserCourseAssignment`
- Checked via `can_access_course?` method in `CoursesController`

Admin users can:
- Access all published courses
- Manage course assignments
- View comprehensive analytics

## Files Modified

### Core Controllers
- `app/controllers/application_controller.rb` - Enhanced with role-based access control
- `app/controllers/sessions_controller.rb` - Existing login/logout functionality (unchanged)

### Admin Controllers  
- `app/controllers/admin/quizzes_controller.rb` - Fixed to use standard authentication
- All other admin controllers already had proper `require_admin` filters

### User Controllers
- `app/controllers/courses_controller.rb` - Removed duplicate methods, added role checking
- `app/controllers/progress_controller.rb` - Removed duplicate methods, added role checking  
- `app/controllers/quizzes_controller.rb` - Removed duplicate methods, added role checking
- `app/controllers/dashboard_controller.rb` - Added role checking
- `app/controllers/chat_controller.rb` - Added role checking

## Testing Authentication

### Manual Testing Steps

1. **Admin User Flow**
   - Login as admin → Should redirect to `/admin/dashboard`
   - Try accessing `/courses` → Should redirect to `/admin/dashboard`
   - Access `/admin/courses` → Should work normally

2. **Regular User Flow**  
   - Login as regular user → Should redirect to `/dashboard`
   - Try accessing `/admin/dashboard` → Should redirect to `/dashboard`
   - Access `/courses` → Should work normally (with assigned courses only)

3. **Unauthenticated Flow**
   - Access any protected route → Should redirect to `/login`
   - After login → Should redirect based on user role

## Benefits

- **Security**: Proper role-based access control prevents unauthorized access
- **User Experience**: Users are automatically directed to appropriate interfaces
- **Code Quality**: Centralized authentication logic reduces duplication  
- **Maintainability**: Consistent authentication patterns across all controllers
- **Scalability**: Easy to add new role-based features using existing patterns

## Future Considerations

- Consider implementing more granular permissions within roles
- Add middleware for API authentication if REST API access is needed
- Implement session timeout and security headers
- Consider adding audit logging for access control events
