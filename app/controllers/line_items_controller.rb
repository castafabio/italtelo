class LineItemsController < ApplicationController
  load_and_authorize_resource

  before_action :fetch_line_item, only: [:inline_update, :edit, :upload_file, :delete_attachment, :append_line_item, :send_to_hotfolder, :show]

  skip_before_action :verify_authenticity_token, only: :upload_file

  def send_to_hotfolder
    begin
      @line_item.send_to_hotfolder!
      @line_item.update!(send_at: DateTime.now)
      flash[:notice] = I18n::t('obj.sent', obj: LineItem.human_attribute_name(:attached_file))
    rescue Exception => e
      flash[:alert] = I18n::t('obj.not_sent_exception', obj: LineItem.human_attribute_name(:attached_file), message: e.message)
    ensure
      render js: 'location.reload();'
    end
  end

  def create
    @line_item = LineItem.new(create_params)
    if @line_item.save
      flash[:notice] = I18n::t('obj.created', obj: LineItem.model_name.human.downcase)
      if params[:subaction] == 'finish'
        redirect_to @order
      else
        redirect_to [:new, @order, :line_item]
      end
    else
      flash.now[:alert] = I18n::t('obj.not_created', obj: LineItem.model_name.human.downcase)
      render :new
    end
  end

  def index
    if params[:worked].present?
      @line_items = LineItem.where(status: 'completed')
    else
      @line_items = LineItem.where(status: 'brand_new')
    end
    @all_line_items = @line_items
    if params[:line_item_id].present?
      @line_items = @line_items.where(id: params[:line_item_id])
    end
    if params[:customer].present?
      @line_items = @line_items.where(customer: params[:customer])
    end
    if params[:customer_machine_id].present?
      @line_items = @line_items.where(customer_machine_id: params[:customer_machine_id])
    end
    @line_items = @line_items.where('description LIKE :search', search: "%#{params[:search]}%") if params[:search].present?
  end

  def toggle_is_active
    begin
      @line_item.toggle_is_active!
      flash[:notice] = I18n::t('obj.updated', obj: LineItem.model_name.human.downcase)
    rescue Exception => e
      flash[:alert] = I18n::t('obj.not_updated_exception', obj: LineItem.model_name.human.downcase, message: e.message)
    ensure
      redirect_to [:line_items]
    end
  end

  def inline_update
    begin
      # !line item editable
      if @line_item.aggregated_job_id.present?
        render json: { code: 400 }
      else
        if params[:customer_machine].present?
          customer_machine = CustomerMachine.find_by(id: params[:customer_machine].to_i)
          @line_item.update!(customer_machine_id: customer_machine.id)
          if customer_machine.kind == 'printer'
            @line_item.update!(need_printing: true)
            @line_item.update!(need_cutting: false)
          else
            @line_item.update!(need_printing: false)
            @line_item.update!(need_cutting: true)
          end
        end
        render json: { code: 200 }
      end
    rescue Exception => e
      render json: { code: 500 }
    end
  end

  def append_line_item
    if request.patch?
      begin
        @line_item.aggregate!(append_line_item_params[:aggregated_job_id], params[:subaction] == 'create_new_aggregated_job')
        flash[:notice] = t('obj.updated', obj: LineItem.model_name.human.downcase)
      rescue Exception => e
        flash[:alert] = t('obj.not_updated_exception', obj: LineItem.model_name.human.downcase, message: e.message)
      ensure
        render js: 'location.reload();'
      end
    end
  end

  def delete_attachment
    begin
      @line_item.attached_file.purge
      @line_item.update!(number_of_files: 0)
      flash[:notice] = t('obj.destroyed', obj: LineItem.human_attribute_name(:attached_file).downcase)
    rescue Exception => e
      flash[:alert] = t('obj.not_destroyed', obj: LineItem.model_name.human.downcase, message: e.message)
    ensure
      redirect_to [:line_items]
    end
  end

  def deaggregate
    begin
      aggregated_job = @line_item.aggregated_job
      @line_item.deaggregate!
      flash[:notice] = I18n::t('obj.updated', obj: LineItem.model_name.human.downcase)
    rescue Exception => e
      flash[:danger] = I18n::t('obj.not_updated_exception', obj: LineItem.model_name.human.downcase, message: e.message)
    ensure
      if aggregated_job.line_items.size == 0 && params[:index] == 'aggregated_jobs'
        render js: %{ window.location = "#{url_for([:aggregated_jobs])}"; }
      else
        render js: 'location.reload();'
      end
    end
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
              filename = "#{@line_item.id}#LI_#{file.original_filename}"
              path = "#{tmpdir}/#{filename}"
              File.open(path, 'wb') do |f|
                f.write(file.read)
              end
              zipfile.add(filename, path)
            end
          end
          job_name = "#{@line_item.id}#LI_zip.zip"
        else
          job_name = "#{@line_item.id}#LI_#{ params[:files].first.original_filename}"
          uploaded_file = "#{tmpdir}/#{job_name}"
          File.open(uploaded_file, 'wb') do |f|
            f.write(params[:files].first.read)
          end
        end
        @line_item.attached_file.attach(io: File.open(uploaded_file), filename: job_name)
        @line_item.update!(number_of_files: number_of_files)
        flash[:notice] = t('obj.updated', obj: LineItem.model_name.human.downcase)
      rescue Exception => e
        flash[:alert] = t('obj.not_updated_exception', obj: LineItem.model_name.human.downcase, message: e.message)
      end
    end
  end

  def update
    begin
      @line_item.send_now = true
      @line_item.update!(update_params)
      flash[:notice] = t('obj.sent', obj: LineItem.model_name.human.downcase)
      render js: 'location.reload();'
    rescue Exception => e
      flash.now[:alert] = t('obj.not_sent_exception', obj: LineItem.model_name.human.downcase, message: e.message)
      render :edit
    end
  end

  private

  def update_params
    params.require(:line_item).permit(:customer_machine_id, :aggregated_job_id, :row_number, :quantity, :article_code, :article_description, :send_now, :customer, :status, :order_code, :number_of_files, :notes, :need_printing, :need_cutting)
  end

  def append_line_item_params
    params.require(:line_item).permit(:aggregated_job_id)
  end

  def upload_file_params
    params.require(:line_item).require(:files)
  end

  def upload_params
    params.require(:line_item).permit(:attached_file)
  end

  def fetch_line_item
    @line_item = LineItem.find(params[:id])
  end
end
