class SubmitPointsController < ApplicationController
  load_and_authorize_resource

  before_action :fetch_submit_point, only: [:destroy, :edit, :update]

  def create
    @submit_point = SubmitPoint.new(create_params)
    if @submit_point.save
      flash[:notice] = I18n::t('obj.created', obj: SubmitPoint.model_name.human.downcase)
      render js: 'location.reload();'
    else
      flash.now[:alert] = I18n::t('obj.not_created', obj: SubmitPoint.model_name.human.downcase)
      render :new
    end
  end

  def destroy
    begin
      @submit_point.destroy!
      flash[:notice] = I18n::t('obj.destroyed', obj: SubmitPoint.model_name.human.downcase)
    rescue Exception => e
      flash[:alert] = I18n::t('obj.not_destroyed', obj: SubmitPoint.model_name.human.downcase, message: e.message)
    ensure
      redirect_to :submit_points
    end
  end

  def index
    @submit_points = SubmitPoint.all
    @submit_points = @submit_points.paginate(page: params[:page], per_page: params[:per_page])
    @submit_points = @submit_points.where('title LIKE :search', search: "%#{params[:search]}%") if params[:search].present?
  end

  def new
    @submit_point = SubmitPoint.new
  end

  def sync
    begin
      SwitchField.sync!
      flash[:notice] = I18n::t('obj.created', obj: SwitchField.model_name.human.downcase)
    rescue Exception => e
      flash[:danger] = I18n::t('obj.not_updated_exception', obj: SwitchField.model_name.human.downcase, message: e.message)
    ensure
      redirect_to :submit_points
    end
  end

  def update
    if @submit_point.update(update_params)
      flash[:notice] = t('obj.updated', obj: SubmitPoint.model_name.human.downcase)
      render js: 'location.reload();'
    else
      flash.now[:danger] = t('obj.not_updated', obj: SubmitPoint.model_name.human.downcase)
      render :edit
    end
  end

  private

  def create_params
    params.require(:submit_point).permit(:name, :kind)
  end

  def update_params
    create_params
  end

  def fetch_submit_point
    @submit_point = SubmitPoint.find(params[:id])
  end
end
