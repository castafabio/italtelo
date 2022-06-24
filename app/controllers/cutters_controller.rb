class CuttersController < ApplicationController
  load_and_authorize_resource

  before_action :fetch_cutter, only: [:resend]

  def index
    @cutters = Cutter.all.order(starts_at: :desc)
    @all_cutters = @cutters
    @cut_machines = CustomerMachine.cutter_machines
    if params[:customer_machine_id].present?
      @cutters = @cutters.where(customer_machine_id: params[:customer_machine_id])
    end
    if params[:file_name].present?
      @cutters = @cutters.where(file_name: params[:file_name])
    end
    @cutters = @cutters.paginate(page: params[:page], per_page: params[:per_page])
    @cutters = @cutters.joins(:customer_machine).where('cutters.file_name LIKE :search OR customer_machines.name LIKE :search', search: "%#{params[:search]}%") if params[:search].present?
  end

  def resend
    UpdateItalteloTable.perform_later(@cutter.id, 'cutter')
    flash[:notice] = I18n::t('obj.updated', obj: Cutter.model_name.human.downcase)
    redirect_to [:cutters]
  end

  private

  def fetch_cutter
    @cutter = Cutter.find(params[:id])
  end
end
