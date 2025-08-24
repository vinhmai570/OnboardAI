# User Management and Course Assignment System

## Overview

This document describes the user management and course assignment system implemented in OnboardAI, which allows administrators to manage users and assign specific courses to individual users.

## Features

### User Management
- **Admin User Creation**: Administrators can create new user accounts with email and password
- **Role Management**: Users can be assigned either 'admin' or 'user' roles
- **User Editing**: Update user information including email, role, and password
- **User Deletion**: Remove users from the system

### Course Assignment System
- **Course Assignment**: Administrators can assign published courses to specific users
- **Course Unassignment**: Remove course assignments from users
- **Assignment Tracking**: Track who assigned courses and when
- **Access Control**: Users can only access courses assigned to them

## Database Schema

### User Course Assignments Table
```sql
user_course_assignments
├── id (primary key)
├── user_id (foreign key → users.id)
├── course_id (foreign key → courses.id)
├── assigned_by_id (foreign key → users.id)
├── assigned_at (datetime)
├── created_at (timestamp)
└── updated_at (timestamp)
```

### Indexes
- `unique_index` on `[user_id, course_id]` - prevents duplicate assignments
- Standard indexes on foreign keys for performance

## Models

### UserCourseAssignment
```ruby
class UserCourseAssignment < ApplicationRecord
  belongs_to :user
  belongs_to :course
  belongs_to :assigned_by, class_name: "User"

  validates :user_id, uniqueness: { scope: :course_id }
  validates :assigned_at, presence: true
end
```

### User Model Updates
```ruby
# New associations added:
has_many :user_course_assignments, dependent: :destroy
has_many :assigned_courses, through: :user_course_assignments, source: :course
has_many :course_assignments_made, class_name: "UserCourseAssignment", foreign_key: :assigned_by_id
```

### Course Model Updates
```ruby
# New associations added:
has_many :user_course_assignments, dependent: :destroy
has_many :assigned_users, through: :user_course_assignments, source: :user
```

## Controllers

### Admin::UsersController
- `index` - List all users with their assigned courses
- `show` - Display user details and course assignment interface
- `new/create` - Create new users
- `edit/update` - Update user information (handles password updates properly)
- `destroy` - Delete users
- `assign_course` - Assign a course to a user
- `unassign_course` - Remove a course assignment

### CoursesController (Updated)
- **Access Control**: Regular users only see courses assigned to them
- **Admin Access**: Administrators can see all published courses
- **Course Access Validation**: Prevents unauthorized access to course content

## User Interface

### Admin User Management
- **Users Index**: Tabular view showing users, roles, assigned courses, and actions
- **User Details**: Comprehensive view with assignment interface
- **Course Assignment**: One-click assign/unassign functionality with visual feedback
- **User Forms**: Clean, accessible forms for creating and editing users

### Features of the UI
- **Visual Course Badges**: Shows assigned courses as colored badges
- **Assignment Statistics**: Quick overview of user's course assignments
- **Responsive Design**: Works well on desktop and mobile devices
- **Accessibility**: Proper ARIA labels and keyboard navigation

## Access Control Logic

### Course Visibility Rules
```ruby
def index
  if current_user.admin?
    @courses = Course.published  # Admins see all
  else
    @courses = current_user.assigned_courses.published  # Users see assigned only
  end
end
```

### Course Access Validation
```ruby
def can_access_course?(course)
  return true if current_user.admin?
  current_user.assigned_courses.include?(course)
end
```

## Usage Workflow

### Admin Workflow
1. **Create User**: Navigate to Admin → Users → Add New User
2. **Assign Courses**: Click on user → Select from available courses → Click "Assign"
3. **Manage Assignments**: View user details to see all assignments and remove if needed
4. **User Management**: Edit user details, change roles, or delete accounts

### User Experience
1. **Login**: Users login with their assigned email/password
2. **Course Access**: Only see courses assigned to them in the course list
3. **Enrollment**: Can enroll in assigned courses and track progress
4. **Restricted Access**: Cannot access courses not assigned to them

## Security Considerations

### Access Control
- **Role-based Authorization**: Only admins can manage users and assignments
- **Course Access Validation**: All course-related actions validate user access
- **Session Security**: Proper authentication required for all actions

### Data Integrity
- **Unique Constraints**: Prevents duplicate course assignments
- **Foreign Key Constraints**: Ensures referential integrity
- **Cascade Deletions**: Proper cleanup when users or courses are deleted

## API Endpoints

### Admin User Management Routes
```ruby
admin/users
├── GET /admin/users (index)
├── GET /admin/users/new (new)
├── POST /admin/users (create)
├── GET /admin/users/:id (show)
├── GET /admin/users/:id/edit (edit)
├── PATCH /admin/users/:id (update)
├── DELETE /admin/users/:id (destroy)
├── POST /admin/users/:id/assign_course (assign_course)
└── DELETE /admin/users/:id/unassign_course (unassign_course)
```

## Testing

### Test Users Created by Seeds
- **Admin**: `admin@onboardai.com` / `password`
- **User 1**: `user1@example.com` / `password`
- **User 2**: `user2@example.com` / `password`

### Test Scenarios
1. **Admin Access**: Admin can see all courses and manage all users
2. **Assigned User**: User1 has course assignments and can access assigned courses
3. **Unassigned User**: User2 has no assignments and sees empty course list
4. **Access Validation**: Users cannot directly access unassigned courses

## Future Enhancements

### Potential Features
- **Bulk Assignment**: Assign multiple courses to multiple users at once
- **Assignment Expiration**: Time-limited course access
- **Assignment History**: Track assignment changes over time
- **User Groups**: Assign courses to groups of users
- **Email Notifications**: Notify users when courses are assigned
- **Assignment Analytics**: Track assignment usage and completion rates

### Performance Optimizations
- **Eager Loading**: Optimize database queries for large user bases
- **Caching**: Cache user assignments for faster access checks
- **Pagination**: Handle large lists of users and courses efficiently

## Maintenance

### Regular Tasks
- **Monitor Assignments**: Regular review of active course assignments
- **Clean Up**: Remove assignments for deleted courses or inactive users
- **Performance Review**: Monitor query performance with growing data

### Troubleshooting
- **Assignment Issues**: Check foreign key constraints and validations
- **Access Problems**: Verify user roles and assignment relationships
- **Performance Issues**: Review database indexes and query optimization

---

## Implementation Details

This feature was implemented following Rails best practices:
- **MVC Architecture**: Clear separation of concerns
- **RESTful Routes**: Standard Rails routing conventions
- **Service Objects**: Complex business logic encapsulated appropriately
- **Database Design**: Normalized structure with proper constraints
- **Security**: Role-based access control throughout
- **UI/UX**: Modern, responsive design with accessibility considerations

The system is designed to be scalable and maintainable, with clear patterns that can be extended as the application grows.
