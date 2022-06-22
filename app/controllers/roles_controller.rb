class RolesController < ApplicationController
  load_and_authorize_resource

  before_action :fetch_role, only: [:destroy, :edit, :update]

  def create
    @role = Role.new(create_params)
    if @role.save
      flash[:notice] = I18n::t('obj.created', obj: Role.model_name.human.downcase)
      render js: 'location.reload();'
    else
      flash.now[:alert] = I18n::t('obj.not_created', obj: Role.model_name.human.downcase)
      render :new
    end
  end

  def destroy
    begin
      @role.destroy!
      flash[:notice] = I18n::t('obj.destroyed', obj: Role.model_name.human.downcase)
    rescue Exception => e
      flash[:alert] = I18n::t('obj.not_destroyed', obj: Role.model_name.human.downcase, message: e.message)
    ensure
      redirect_to :roles
    end
  end

  def index
    @roles = Role.all
    @roles = @roles.paginate(page: params[:page], per_page: params[:per_page])
    @roles = @roles.where('name LIKE :search', search: "%#{params[:search]}%") if params[:search].present?
  end

  def new
    @role = Role.new
  end

  def update
    if @role.update_attributes(update_params)
      flash[:notice] = t('obj.updated', obj: Role.model_name.human.downcase)
      render js: 'location.reload();'
    else
      flash.now[:danger] = t('obj.not_updated', obj: Role.model_name.human.downcase)
      render :edit
    end
  end

  private

  def create_params
    params.require(:role).permit(:code, :name, :value)
  end

  def fetch_role
    @role = Role.find(params[:id])
  end

  def update_params
    create_params
  end
end
