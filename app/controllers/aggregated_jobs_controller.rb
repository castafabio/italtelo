class AggregatedJobsController < ApplicationController
  before_action :fetch_aggregated_job, only: [:toggle_is_active, :destroy, :edit, :delete_attachment, :insert_notes, :set_status, :show, :update, :upload_file, :add_line_items, :inline_update, :send_to_switch]

  skip_before_action :verify_authenticity_token, only: :upload_file

  def send_to_switch
    begin
      @aggregated_job.send_to_switch!
      flash[:notice] = I18n::t('obj.sent', obj: AggregatedJob.model_name.human.downcase)
    rescue Exception => e
      flash[:alert] = I18n::t('obj.not_sent_exception', obj: AggregatedJob.model_name.human.downcase, message: e.message)
    ensure
      render js: 'location.reload();'
    end
  end

  def inline_update
    begin
      # !line item editable
      if @aggregated_job.editable?
        if @aggregated_job.need_printing
          if params[:print].present?
            @aggregated_job.update(print_customer_machine_id: params[:print].split('_').first.to_i)
            @aggregated_job.update_line_items_machines!('print', @aggregated_job.print_customer_machine_id)
          end
        end
        if @aggregated_job.need_cutting
          if params[:cut].present?
            @aggregated_job.update(cut_customer_machine_id: params[:cut].split('_').first.to_i)
            @aggregated_job.update_line_items_machines!('cut', @aggregated_job.print_customer_machine_id)
          end
        end
        render json: { code: 200 }
      end
    rescue Exception => e
      render json: { code: 500 }
    end
  end

  def aggregate
    begin
      @line_items = LineItem.where(id: params[:line_item_ids])
      AggregatedJob.aggregate!(@line_items)
      flash[:notice] = "Aggregazione completata correttamente"
    rescue Exception => e
      flash[:alert] = e.message
    ensure
      render js: 'location.reload();'
    end
  end

  def delete_attachment
    begin
      case params[:kind]
      when 'print'
        @aggregated_job.print_file.purge
        @aggregated_job.update!(print_number_of_files: 0)
        flash[:notice] = t('obj.destroyed', obj: AggregatedJob.human_attribute_name(:print_file))
      when 'cut'
        @aggregated_job.cut_file.purge
        @aggregated_job.update!(cut_number_of_files: 0)
        flash[:notice] = t('obj.destroyed', obj: AggregatedJob.human_attribute_name(:cut_file))
      end
    rescue Exception => e
      flash[:alert] = t('obj.not_destroyed', obj: 'file', message: e.message)
    end
    if params[:all] == 'true'
      redirect_to [:aggregated_jobs]
    else
      params[:all] = ''
      redirect_to [@aggregated_job]
    end
  end

  def destroy
    begin
      @aggregated_job.destroy!
      flash[:notice] = I18n::t('obj.destroyed', obj: AggregatedJob.model_name.human.downcase)
    rescue Exception => e
      flash[:alert] = I18n::t('obj.not_destroyed', obj: AggregatedJob.model_name.human.downcase, message: e.message)
    ensure
      redirect_to :aggregated_jobs
    end
  end

  def index
    if params[:tag] == 'completed'
      @aggregated_jobs = AggregatedJob.all.completed
    else
      params[:tag] = 'brand_new'
      @aggregated_jobs = AggregatedJob.all.brand_new
    end
    if params[:tag] == 'completed'
      @customers = @aggregated_jobs.joins(line_items: :order).pluck(:customer).uniq
    else
      @customers = @aggregated_jobs.joins(line_items: :order).pluck(:customer).uniq
    end
    @all_aggregated_jobs = @aggregated_jobs
    if params[:customer].present?
      @aggregated_jobs = AggregatedJob.where(id: @aggregated_jobs.joins(line_items: :order).where("orders.customer LIKE :customer", customer: "%#{params[:customer]}%"))
    end
    if params[:from].present?
      @aggregated_jobs = @aggregated_jobs.where('deadline >= :from', from: params[:from].to_date)
    end
    if params[:to].present?
      @aggregated_jobs = @aggregated_jobs.where('deadline <= :to', to: params[:to].to_date)
    end
    @aggregated_jobs = @aggregated_jobs.paginate(page: params[:page], per_page: params[:per_page])
    @aggregated_jobs = @aggregated_jobs.order(deadline: :desc)
    @aggregated_jobs = @aggregated_jobs.where('id LIKE :search ', search: "%#{params[:search]}%") if params[:search].present?
  end

  def scheduler
    @line_items = LineItem.aggregable.joins(:order).order('orders.order_code': :desc)
    @orders = @line_items.joins(:order).pluck(:order_code)
    @all_line_items = @line_items
    @print_machines = CustomerMachine.printer_machines.where(id: @all_line_items.pluck(:print_customer_machine_id).uniq)
    @cut_machines = CustomerMachine.cutter_machines.where(id: @all_line_items.pluck(:cut_customer_machine_id).uniq)
    if params[:print_customer_machine_id].present?
      @line_items = @line_items.where(print_customer_machine_id: params[:print_customer_machine_id])
    end
    if params[:cut_customer_machine_id].present?
      @line_items = @line_items.where(cut_customer_machine_id: params[:cut_customer_machine_id])
    end
    if params[:customer].present?
      @line_items = @line_items.joins(:order).where('orders.customer': params[:customer])
    end
    if params[:order_code].present?
      @line_items = @line_items.joins(:order).where('orders.order_code': params[:order_code])
    end
    if params[:from].present?
      @line_items = @line_items.where('orders.order_date >= :from', from: params[:from].to_date)
    end
    if params[:to].present?
      @line_items = @line_items.where('orders.order_date <= :to', to: params[:to].to_date)
    end
    if params[:print_customer_machine].present?
      @line_items = @line_items.where(print_customer_machine_id: params[:print_customer_machine])
    end
    if params[:cut_customer_machine].present?
      @line_items = @line_items.where(cut_customer_machine_id: params[:cut_customer_machine])
    end
  end

  def add_line_items
    if request.patch?
      begin
        @aggregated_job.add_line_items!(add_line_items_params[:appendable_line_items])
        flash[:notice] = t('obj.updated', obj: AggregatedJob.model_name.human.downcase)
      rescue Exception => e
        flash[:alert] = t('obj.not_updated_exception', obj: AggregatedJob.model_name.human.downcase, message: e.message)
      ensure
        render js: 'location.reload();'
      end
    end
  end

  def set_status
    begin
      @aggregated_job.set_status!(params[:job_operation], current_user)
      flash[:notice] = t('obj.updated', obj: AggregatedJob.model_name.human.downcase)
    rescue Exception => e
      flash[:alert] = t('obj.not_updated_exception', obj: AggregatedJob.model_name.human.downcase, message: e.message)
    ensure
      redirect_back(fallback_location: [:my_jobs, :jobs])
    end
  end

  def show
    @line_items = @aggregated_job.line_items.paginate(page: params[:page], per_page: params[:per_page])
  end

  def upload_file
    if request.post?
      begin
        tmpdir = Dir.mktmpdir
        number_of_files = params[:files].size
        code = @aggregated_job.id.to_s.rjust(7, '0')
        uploaded_file = Tempfile.new
        Zip::File.open(uploaded_file, Zip::File::CREATE) do |zipfile|
          params[:files].each_with_index do |file, index|
            filename = "#{code}01AJ#{index + 1}_#{file.original_filename}"
            path = "#{tmpdir}/#{filename}"
            File.open(path, 'wb') do |f|
              f.write(file.read)
            end
            zipfile.add(filename, path)
          end
        end
        aj_name = "#{code}01AJ.zip"
        case params[:kind]
        when 'print'
          @aggregated_job.print_file.attach(io: File.open(uploaded_file), filename: aj_name)
          @aggregated_job.update!(print_number_of_files: number_of_files)
        when 'cut'
          @aggregated_job.cut_file.attach(io: File.open(uploaded_file), filename: aj_name)
          @aggregated_job.update!(cut_number_of_files: number_of_files)
        end
        flash[:notice] = t('obj.updated', obj: AggregatedJob.model_name.human.downcase)
      rescue Exception => e
        flash[:alert] = t('obj.not_updated_exception', obj: AggregatedJob.model_name.human.downcase, message: e.message)
      end
    end
  end

  def update
    begin
      @aggregated_job.send_now = true
      @aggregated_job.update!(update_params)
      flash[:notice] = t('obj.sent', obj: AggregatedJob.model_name.human.downcase)
      render js: 'location.reload();'
    rescue Exception => e
      flash.now[:alert] = t('obj.not_sent_exception', obj: AggregatedJob.model_name.human.downcase, message: e.message)
      render :edit
    end
  end

  def edit
    @aggregated_job.submit_point = SubmitPoint.find(params[:submit_point_id])
    if @aggregated_job.line_items.pluck(:sides).uniq.size > 1
      sides = 'Bifacciale'
    else
      sides = 'Monofacciale'
    end
    if !@aggregated_job.cut_customer_machine_id.nil?
      cut_machine = CustomerMachine.get_machine_switch_name(@aggregated_job.line_items.first.cut_customer_machine.id)
    end
    if !@aggregated_job.print_customer_machine_id.nil?
      print_machine = CustomerMachine.get_machine_switch_name(@aggregated_job.line_items.first.print_customer_machine.id)
    end
  end

  def toggle_is_active
    begin
      @aggregated_job.toggle_is_active!
      flash[:notice] = I18n::t('obj.updated', obj: AggregatedJob.model_name.human.downcase)
    rescue Exception => e
      flash[:alert] = I18n::t('obj.not_updated_exception', obj: AggregatedJob.model_name.human.downcase, message: e.message)
    ensure
      redirect_to [:aggregated_jobs]
    end
  end

  private

  def update_params
    params.require(:aggregated_job).permit(:print_customer_machine_id, :submit_point_id, :cut_customer_machine_id, :send_now, :error_message, :sending, fields_data: {})
  end

  def add_line_items_params
    params.require(:aggregated_job).permit(appendable_line_items: [])
  end

  def fetch_aggregated_job
    @aggregated_job = AggregatedJob.find(params[:id])
  end
end
