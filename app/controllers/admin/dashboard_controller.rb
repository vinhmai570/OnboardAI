class Admin::DashboardController < ApplicationController
  before_action :require_admin

  def index
    # Admin dashboard overview
    @total_users = User.users.count
    @total_courses = Course.count
    @total_documents = Document.count
    @recent_courses = Course.includes(:admin).order(created_at: :desc).limit(5)
    @recent_users = User.users.order(created_at: :desc).limit(5)
  end
end
