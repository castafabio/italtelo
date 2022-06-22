class CustomizationsController < ApplicationController
  load_and_authorize_resource

  before_action :fetch_customization, only: [:destroy, :edit, :update]

  def create
    @customization = Customization.new(create_params)
    if @customization.save
      flash[:notice] = I18n::t('obj.created', obj: Customization.model_name.human.downcase)
      render js: 'location.reload();'
    else
      flash.now[:alert] = I18n::t('obj.not_created', obj: Customization.model_name.human.downcase)
      render :new
    end
  end

  def destroy
    begin
      @customization.destroy!
      flash[:notice] = I18n::t('obj.destroyed', obj: Customization.model_name.human.downcase)
    rescue Exception => e
      flash[:alert] = I18n::t('obj.not_destroyed', obj: Customization.model_name.human.downcase, message: e.message)
    ensure
      redirect_to :customizations
    end
  end

  def index
    @customizations = Customization.all
    @customizations = @customizations.order(:parameter)
    @customizations = @customizations.paginate(page: params[:page], per_page: params[:per_page])
    @customizations = @customizations.where('parameter LIKE :search', search: "%#{params[:search]}%") if params[:search].present?
  end

  def new
    @customization = Customization.new
  end

  def update
    if @customization.update(update_params)
      flash[:notice] = t('obj.updated', obj: Customization.model_name.human.downcase)
      respond_to do |format|
        format.html do
          redirect_to [:customizations]
        end
        format.js do
          render js: 'location.reload();'
        end
      end
    else
      flash.now[:danger] = t('obj.not_updated', obj: Customization.model_name.human.downcase)
      render :edit
    end
  end

  private

  def create_params
    params.require(:customization).permit(:parameter, :value, :um, :notes)
  end

  def update_params
    create_params
  end

  def fetch_customization
    @customization = Customization.find(params[:id])
  end
end
