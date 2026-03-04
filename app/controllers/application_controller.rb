class ApplicationController < ActionController::Base
  helper_method :current_user

  def current_user
    return @current_user if defined?(@current_user)

    @current_user =
      if session[:user_id].present?
        User.find_by(id: session[:user_id])
      end
  end
end
