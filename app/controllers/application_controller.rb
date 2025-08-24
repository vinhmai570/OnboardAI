class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Authentication helpers
  before_action :require_login
  helper_method :current_user, :logged_in?, :admin?

  protected

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end

  def logged_in?
    !!current_user
  end

  def admin?
    logged_in? && current_user.admin?
  end

  def require_login
    redirect_to new_session_path unless logged_in?
  end

  def require_admin
    redirect_to dashboard_path unless admin?
  end

  def require_user_role
    # Ensures regular users can't access admin routes and admins use admin routes
    if logged_in?
      if current_user.admin? && !request.path.start_with?("/admin") && !request.path.start_with?("/logout") && request.path != "/"
        # Admin users trying to access user routes should be redirected to admin
        redirect_to admin_dashboard_path
      elsif current_user.user? && request.path.start_with?("/admin")
        # Regular users trying to access admin routes should be redirected to user dashboard
        redirect_to dashboard_path
      end
    end
  end

  def skip_authentication
    # Can be used in controllers that don't need authentication
  end
end
