class PrintersController < ApplicationController
  load_and_authorize_resource

  before_action :fetch_printer, only: [:resend]

  def index
    @printers = Printer.all.order(created_at: :desc)
    @all_printers = @printers
    @print_machines = CustomerMachine.printer_machines.ordered
    if params[:customer_machine_id].present?
      @printers = @printers.where(customer_machine_id: params[:customer_machine_id])
    end
    if params[:file_name].present?
      @printers = @printers.where(file_name: params[:file_name])
    end
    @printers = @printers.paginate(page: params[:page], per_page: params[:per_page])
    @printers = @printers.joins(:customer_machine).where('printers.file_name LIKE :search OR customer_machines.name LIKE :search', search: "%#{params[:search]}%") if params[:search].present?
  end

  def resend
    UpdateItalteloTable.perform_later(@printer.id, 'printer')
    flash[:notice] = I18n::t('obj.updated', obj: Printer.model_name.human.downcase)
    redirect_to [:printers]
  end

  private

  def fetch_printer
    @printer = Printer.find(params[:id])
  end
end
