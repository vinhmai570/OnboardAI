# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create admin user
admin = User.find_or_create_by!(email: 'admin@onboardai.com') do |u|
  u.role = 'admin'
  u.password = 'password'
  u.password_confirmation = 'password'
end

# Create regular users
user1 = User.find_or_create_by!(email: 'user1@example.com') do |u|
  u.role = 'user'
  u.password = 'password'
  u.password_confirmation = 'password'
end

user2 = User.find_or_create_by!(email: 'user2@example.com') do |u|
  u.role = 'user'
  u.password = 'password'
  u.password_confirmation = 'password'
end

puts "Created users:"
puts "- Admin: admin@onboardai.com (password: password)"
puts "- User 1: user1@example.com (password: password)"
puts "- User 2: user2@example.com (password: password)"

# Create sample course
if Course.count == 0
  course = Course.create!(
    title: 'Junior Developer Onboarding',
    prompt: 'Create a comprehensive onboarding path for junior developers covering environment setup, Git workflows, and code review best practices.',
    admin: admin,
    task_list: [
      {
        "title" => "Environment Setup",
        "description" => "Set up development environment including IDE, Git, and necessary tools"
      },
      {
        "title" => "Git Basics",
        "description" => "Learn Git version control fundamentals and workflow"
      },
      {
        "title" => "Code Review Process",
        "description" => "Understand how to create and review pull requests"
      }
    ]
  )

  # Create sample steps
  Step.create!([
    {
      course: course,
      order: 1,
      content: "# Environment Setup\n\nWelcome to your development journey! Let's start by setting up your development environment...",
      quiz_questions: [
        {
          "question" => "Which tool is essential for version control?",
          "options" => [ "Git", "Vim", "Docker", "Node.js" ],
          "correct_answer" => 0,
          "explanation" => "Git is the industry standard for version control."
        }
      ]
    },
    {
      course: course,
      order: 2,
      content: "# Git Basics\n\nNow that your environment is ready, let's learn the fundamentals of Git...",
      quiz_questions: [
        {
          "question" => "What command creates a new Git repository?",
          "options" => [ "git create", "git init", "git new", "git start" ],
          "correct_answer" => 1,
          "explanation" => "git init initializes a new Git repository."
        }
      ]
    }
  ])

  puts "Created sample course: #{course.title} with #{course.steps.count} steps"

  # Create course assignments
  UserCourseAssignment.find_or_create_by!(user: user1, course: course) do |assignment|
    assignment.assigned_by = admin
    assignment.assigned_at = Time.current
  end

  puts "Assigned course to user1@example.com"
  puts "user2@example.com has no course assignments (for testing restricted access)"
end
