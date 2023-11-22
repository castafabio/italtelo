class LineItemsController < ApplicationController
  load_and_authorize_resource

  before_action :fetch_line_item, only: [:inline_update, :edit, :upload_file, :delete_attachment, :append_line_item, :send_to_hotfolder, :show, :choose_operator]

  skip_before_action :verify_authenticity_token, only: :upload_file

  def send_to_hotfolder
    begin
      if @line_item.is_efkal? && params[:is_efkal] == 'true'
        efkal_line_items = LineItem.where.not(send_at: nil).where(cut_customer_machine_id: CustomerMachine.efkal.id).where("status NOT LIKE 'completed'")
         if efkal_line_items.size > 0
          raise "Sono presenti delle righe ordine aventi come macchina #{CustomerMachine.efkal.to_s}, bisogna prima concludere la riga #{efkal_line_items.first.to_s}"
        end
      end
      if request.patch?
        begin
          if params["line_item"]["italtelo_user_id"].present?
            @line_item.send_to_hotfolder!
            @line_item.update!(send_at: DateTime.now, italtelo_user_id: ItalteloUser.find(params["line_item"]["italtelo_user_id"].to_i).id)
            flash[:notice] = I18n::t('obj.sent', obj: 'file')
          else
            raise "Bisogna selezionare un operatore."
          end
        rescue Exception => e
          flash[:alert] = I18n::t('obj.not_sent_exception', obj: 'file', message: e.message)
        ensure
          render js: "location.reload();"
        end
      else
        @italtelo_users = ItalteloUser.all.ordered
      end
    rescue Exception => e
      flash[:alert] = I18n::t('obj.not_sent_exception', obj: 'file', message: e.message)
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
    @line_items = @line_items.where(order_line_item: params[:order_line_item]) if params[:order_line_item].present?
    if params[:aggregated_jobs].present?
      if params[:aggregated_jobs].to_boolean
        @line_items = @line_items.where("line_items.aggregated_job_id IS NOT NULL")
      else
        @line_items = @line_items.where("line_items.aggregated_job_id IS NULL")
      end
    end
    @line_items = @line_items.where(customer: params[:customer]) if params[:customer].present?
    @line_items = @line_items.where(order_code: params[:order_code]) if params[:order_code].present?
    @line_items = @line_items.where(cut_customer_machine_id: params[:cut_customer_machine_id].to_i) if params[:cut_customer_machine_id].present?
    @line_items = @line_items.where(print_customer_machine_id: params[:print_customer_machine_id].to_i) if params[:print_customer_machine_id].present?
    @line_items = @line_items.where('article_code LIKE :article_code', article_code: "%#{params[:article_code]}%") if params[:article_code].present?
    @line_items = @line_items.paginate(page: params[:page], per_page: params[:per_page])
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
      if @line_item.aggregated_job_id.present?
        render json: { code: 400 }
      else
        if params[:customer_machine].present?
          customer_machine = CustomerMachine.find_by(id: params[:customer_machine].to_i)
          if customer_machine.kind == 'printer'
            @line_item.update_old_customer_machine!('print')
            @line_item.update!(print_customer_machine_id: customer_machine.id)
            if @line_item&.old_print_customer_machine&.id == @line_item.print_customer_machine.id
              @line_item.update!(old_print_customer_machine_id: nil)
            end
          else
            @line_item.update_old_customer_machine!('cut')
            @line_item.update!(cut_customer_machine_id: customer_machine.id)
            if @line_item.old_cut_customer_machine.id == @line_item.cut_customer_machine.id
              @line_item.update!(old_cut_customer_machine_id: nil)
            end
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
      case params[:kind]
      when 'print'
        @line_item.print_file.purge
        @line_item.update!(print_number_of_files: 0)
        flash[:notice] = t('obj.destroyed', obj: LineItem.human_attribute_name(:print_file).downcase)
      when 'cut'
        @line_item.cut_file.purge
        @line_item.update!(cut_number_of_files: 0)
        flash[:notice] = t('obj.destroyed', obj: LineItem.human_attribute_name(:cut_file).downcase)
      end
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
          case params[:kind]
          when 'print'
            job_name = "#{@line_item.id}#LI_zip.zip"
          when 'cut'
            job_name = "#{@line_item.id}#LI_zip.zip"
          end
        else
          case params[:kind]
          when 'print'
            job_name = "#{@line_item.id}#LI_#{ params[:files].first.original_filename}"
          when 'cut'
            job_name = "#{@line_item.id}#LI_#{ params[:files].first.original_filename}"
          end
          uploaded_file = "#{tmpdir}/#{job_name}"
          File.open(uploaded_file, 'wb') do |f|
            f.write(params[:files].first.read)
          end
        end
        case params[:kind]
        when 'print'
          @line_item.print_file.attach(io: File.open(uploaded_file), filename: job_name)
          @line_item.update!(print_number_of_files: number_of_files)
        when 'cut'
          @line_item.cut_file.attach(io: File.open(uploaded_file), filename: job_name)
          @line_item.update!(cut_number_of_files: number_of_files)
        end
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
    params.require(:line_item).permit(:print_customer_machine_id, :cut_customer_machine_id, :aggregated_job_id, :row_number, :quantity, :article_code, :article_description, :send_at, :customer, :status, :order_code, :print_number_of_files, :cut_number_of_files, :notes, :print_reference, :cut_reference)
  end

  def append_line_item_params
    params.require(:line_item).permit(:aggregated_job_id)
  end

  def upload_file_params
    params.require(:line_item).require(:files)
  end

  def upload_params
    params.require(:line_item).permit(:print_file, :cut_file)
  end

  def fetch_line_item
    @line_item = LineItem.find(params[:id])
  end
end
