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
    redirect_to dashboard_index_path unless admin?
  end

  def skip_authentication
    # Can be used in controllers that don't need authentication
  end
end
