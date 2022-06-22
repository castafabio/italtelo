class LogsController < ApplicationController
  load_and_authorize_resource

  def index
    @logs = Log.all.order(created_at: :desc)
    @logs = @logs.paginate(page: params[:page], per_page: params[:per_page])
    @logs = @logs.where('action LIKE :search', search: "%#{params[:search]}%") if params[:search].present?
  end
end
