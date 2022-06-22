class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  before_action :authenticate_user!

  rescue_from CanCan::AccessDenied do |exception|
    flash[:alert] = I18n::t('flash.authorization_missing')
    begin
      request.xhr? ? render(js: 'location.reload();') : redirect_to(:root)
    rescue ActionController::RedirectBackError
      redirect_to :root
    end
  end
end
