class UsersController < ApplicationController
  load_and_authorize_resource

  before_action :fetch_user, only: [:destroy, :show, :toggle_role]

  def destroy
    begin
      @user.destroy!
      flash[:notice] = I18n::t('obj.destroyed', obj: User.model_name.human.downcase)
    rescue Exception => e
      flash[:alert] = I18n::t('obj.not_destroyed', obj: User.model_name.human.downcase, message: e.message)
    ensure
      redirect_to :users
    end
  end

  def index
    @users = User.all
    @users = @users.paginate(page: params[:page], per_page: params[:per_page])
    @users = @users.where('first_name LIKE :search OR last_name LIKE :search OR email LIKE :search', search: "%#{params[:search]}%") if params[:search].present?
  end

  def toggle_role
    @role = Role.find_by_code(params[:role])
    if @user.has_role?(@role.code)
      @user.roles.destroy(@role)
    else
      @user.roles << @role
    end
    render layout: false
  end

  private

  def fetch_user
    @user = User.find(params[:id])
  end
end
