class ItalteloUsersController < ApplicationController
  load_and_authorize_resource

  def index
    @italtelo_users = ItalteloUser.all.ordered
    @all_italtelo_users = @italtelo_users
    @italtelo_users = @italtelo_users.where(code: params[:code]) if params[:code].present?
    @italtelo_users = @italtelo_users.where('description LIKE :description', description: "%#{params[:description]}%") if params[:description].present?
    @italtelo_users = @italtelo_users.paginate(page: params[:page], per_page: params[:per_page])
  end
end
