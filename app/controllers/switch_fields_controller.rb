class SwitchFieldsController < ApplicationController
  load_and_authorize_resource

  before_action :fetch_submit_point

  def index
    @switch_fields = @submit_point&.switch_fields
  end

  def sort
    if request.get?
      @switch_fields = @submit_point.switch_fields
    elsif request.patch?
      @switch_field = @submit_point.switch_fields.find(params[:id]).sort!(params[:position])
      @switch_fields = @submit_point.switch_fields
      render nothing: true
    end
  end

  private

  def fetch_submit_point
    @submit_point = SubmitPoint.find(params[:submit_point_id])
  end
end
