class CustomerMachinesController < ApplicationController
  load_and_authorize_resource

  before_action :fetch_customer_machine, only: [:destroy, :edit, :update]

  def create
    @customer_machine = CustomerMachine.new(create_params)
    if @customer_machine.save
      flash[:notice] = I18n::t('obj.created', obj: CustomerMachine.model_name.human.downcase)
      render js: 'location.reload();'
    else
      @error = I18n::t('obj.not_created', obj: CustomerMachine.model_name.human.downcase)
      render :new
    end
  end

  def destroy
    begin
      @customer_machine.destroy!
      flash[:notice] = I18n::t('obj.destroyed', obj: CustomerMachine.model_name.human.downcase)
    rescue Exception => e
      flash[:alert] = I18n::t('obj.not_destroyed', obj: CustomerMachine.model_name.human.downcase, message: e.message)
    ensure
      redirect_to :customer_machines
    end
  end

  def index
    @customer_machines = CustomerMachine.all.order(:name)
    @all_customer_machines = @customer_machines
    if params[:kind].present?
      @customer_machines = @customer_machines.where(kind: params[:kind])
    end
    @customer_machines = @customer_machines.paginate(page: params[:page], per_page: params[:per_page])
    @customer_machines = @customer_machines.where('name LIKE :search', search: "%#{params[:search]}%") if params[:search].present?
  end

  def new
    @customer_machine = CustomerMachine.new
  end

  def update
    if @customer_machine.update(update_params)
      flash[:notice] = t('obj.updated', obj: CustomerMachine.model_name.human.downcase)
      render js: 'location.reload();'
    else
      flash.now[:danger] = t('obj.not_updated', obj: CustomerMachine.model_name.human.downcase)
      render :edit
    end
  end

  private

  def fetch_customer_machine
    @customer_machine = CustomerMachine.find(params[:id])
  end

  def create_params
    params.require(:customer_machine).permit(:name, :kind, :path, :serial_number, :ip_address, :username, :psw, :api_key, :hotfolder_path, :import_job, :machine_switch_name)
  end

  def update_params
    create_params
  end
end
