class AggregatedJobsController < ApplicationController
  before_action :fetch_aggregated_job, only: [:toggle_is_active, :destroy, :edit, :delete_attachment, :insert_notes, :set_status, :show, :update, :upload_file, :add_line_items, :inline_update, :send_to_hotfolder]

  skip_before_action :verify_authenticity_token, only: :upload_file

  def send_to_hotfolder
    begin
      @aggregated_job.send_to_hotfolder!
      @aggregated_job.update!(send_at: DateTime.now)
      flash[:notice] = I18n::t('obj.sent', obj: AggregatedJob.model_name.human.downcase)
    rescue Exception => e
      flash[:alert] = I18n::t('obj.not_sent_exception', obj: AggregatedJob.model_name.human.downcase, message: e.message)
    ensure
      render js: 'location.reload();'
    end
  end

  def inline_update
    begin
      if @aggregated_job.need_printing
        @aggregated_job.update(customer_machine_id: params[:customer_machine].to_i)
        @aggregated_job.line_items.each do |line_item|
          line_item.update!(customer_machine_id: @aggregated_job.customer_machine.id)
        end
      end
      render json: { code: 200 }
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
      @aggregated_job.attached_file.purge
      @aggregated_job.update!(number_of_files: 0)
      flash[:notice] = t('obj.destroyed', obj: AggregatedJob.human_attribute_name(:attached_file))
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
      @aggregated_jobs = AggregatedJob.completed
    else
      params[:tag] = 'brand_new'
      @aggregated_jobs = AggregatedJob.brand_new
    end
    if params[:tag] == 'completed'
      @customers = @aggregated_jobs.joins(:line_items).pluck(:customer).uniq
    else
      @customers = @aggregated_jobs.joins(:line_items).pluck(:customer).uniq
    end
    @all_aggregated_jobs = @aggregated_jobs
    if params[:code].present?
      @aggregated_jobs = @aggregated_jobs.where(code: params[:code])
    end
    if params[:customer].present?
      @aggregated_jobs = @aggregated_jobs.where(id: @aggregated_jobs.joins(line_items: :order).where("orders.customer LIKE :customer", customer: "%#{params[:customer]}%"))
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
    @line_items = LineItem.unsend.aggregable
    @orders = @line_items.pluck(:order_code)
    @all_line_items = @line_items
    @articles = @all_line_items.pluck(:article_code)
    if params[:customer].present?
      @line_items = @line_items.where(customer: params[:customer])
    end
    if params[:order_code].present?
      @line_items = @line_items.where(order_code: params[:order_code])
    end
    if params[:customer_machine_id].present?
      @line_items = @line_items.where(customer_machine_id: params[:customer_machine_id])
    end
    if params[:article_code].present?
      @line_items = @line_items.where(article_code: params[:article_code])
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
        if number_of_files > 1
          uploaded_file = Tempfile.new
          Zip::File.open(uploaded_file, Zip::File::CREATE) do |zipfile|
            params[:files].each do |file|
              filename = "#{@aggregated_job.id}#AJ_#{file.original_filename}"
              path = "#{tmpdir}/#{filename}"
              File.open(path, 'wb') do |f|
                f.write(file.read)
              end
              zipfile.add(filename, path)
            end
          end
          job_name = "#{@aggregated_job.id}#AJ_zip.zip"
        else
          job_name = "#{@aggregated_job.id}#AJ_#{ params[:files].first.original_filename}"
          uploaded_file = "#{tmpdir}/#{job_name}"
          File.open(uploaded_file, 'wb') do |f|
            f.write(params[:files].first.read)
          end
        end
        @aggregated_job.attached_file.attach(io: File.open(uploaded_file), filename: job_name)
        @aggregated_job.update!(number_of_files: number_of_files)
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
    params.require(:aggregated_job).permit(:customer_machine_id, :send_now, :sending)
  end

  def add_line_items_params
    params.require(:aggregated_job).permit(appendable_line_items: [])
  end

  def fetch_aggregated_job
    @aggregated_job = AggregatedJob.find(params[:id])
  end
end
