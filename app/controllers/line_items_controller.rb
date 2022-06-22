class LineItemsController < ApplicationController
  load_and_authorize_resource

  before_action :fetch_line_item, only: [:inline_update, :edit, :show, :toggle_is_active, :upload_file, :delete_attachment, :append_line_item]

  skip_before_action :verify_authenticity_token, only: :upload_file

  def create
    @line_item = LineItem.new(create_params)
    @line_item.submit_point = SubmitPoint.preflight.first
    @line_item.order = @order
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
    if params[:worked] == 'true'
      @line_items = LineItem.joins(:order).where.not(switch_sent: nil).order('orders.order_date': :desc)
    else
      params[:worked] = ''
      @line_items = LineItem.joins(:order).where(switch_sent: nil).order('orders.order_date': :desc)
    end
    @all_line_items = @line_items
    @print_machines = CustomerMachine.printer_machines.where(id: @all_line_items.pluck(:print_customer_machine_id).compact)
    @cut_machines = CustomerMachine.cutter_machines.where(id: @all_line_items.pluck(:cut_customer_machine_id).compact)
    if params[:line_item_id].present?
      @line_items = @line_items.where(id: params[:line_item_id])
    end
    if params[:customer].present?
      @line_items = @line_items.joins(:order).where('orders.customer': params[:customer])
    end
    if params[:print_customer_machine_id].present?
      @line_items = @line_items.where(print_customer_machine_id: params[:print_customer_machine_id])
    end
    if params[:cut_customer_machine_id].present?
      @line_items = @line_items.where(cut_customer_machine_id: params[:cut_customer_machine_id])
    end
    if params[:from].present?
      @line_items = @line_items.joins(:order).where('orders.order_date >= :from', from: params[:from].to_date)
    end
    if params[:to].present?
      @line_items = @line_items.joins(:order).where('orders.order_date <= :to', to: params[:to].to_date)
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
        if params[:value] == '1:1' || params[:value] == '1:10'
          @line_item.update!(scale: params[:value])
        end
        if @line_item.need_printing
          if params[:print].present?
            @line_item.update(print_customer_machine_id: params[:print].split('_').first.to_i)
            @line_item.update(vg7_print_machine_id: params[:print].split('_').last.to_i)
          end
        end
        if @line_item.need_cutting
          if params[:cut].present?
            @line_item.update(cut_customer_machine_id: params[:cut].split('_').first.to_i)
            @line_item.update(vg7_cut_machine_id: params[:cut].split('_').last.to_i)
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
        @line_item.update_column(:print_number_of_files, 0)
        flash[:notice] = t('obj.destroyed', obj: LineItem.human_attribute_name(:print_file).downcase)
      when 'cut'
        @line_item.cut_file.purge
        @line_item.update_column(:cut_number_of_files, 0)
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
      render js: 'location.reload();'
    end
  end

  def upload_file
    if request.post?
      begin
        tmpdir = Dir.mktmpdir
        number_of_files = params[:files].size
        code = @line_item.id.to_s.rjust(7, '0')
        uploaded_file = Tempfile.new
        Zip::File.open(uploaded_file, Zip::File::CREATE) do |zipfile|
          params[:files].each_with_index do |file, index|
            filename = "#{code}01LI#{index + 1}_#{file.original_filename}"
            path = "#{tmpdir}/#{filename}"
            File.open(path, 'wb') do |f|
              f.write(file.read)
            end
            zipfile.add(filename, path)
          end
        end
        line_item_name = "#{code}01LI.zip"
        case params[:kind]
        when 'print'
          @line_item.print_file.attach(io: File.open(uploaded_file), filename: line_item_name)
          @line_item.update_column(:print_number_of_files, number_of_files)
        when 'cut'
          @line_item.cut_file.attach(io: File.open(uploaded_file), filename: line_item_name)
          @line_item.update_column(:cut_number_of_files, number_of_files)
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

  def edit
    @line_item.submit_point = SubmitPoint.find(params[:submit_point_id])
    @line_item.sending = true
    if @line_item.aluan == true
      aluan = 'Si'
    else
      aluan = 'No'
    end
    if !@line_item.cut_customer_machine.nil?
      cut_machine = CustomerMachine.get_machine_switch_name(@line_item.cut_customer_machine.id)
    end
    if !@line_item.print_customer_machine.nil?
      print_machine = CustomerMachine.get_machine_switch_name(@line_item.print_customer_machine.id)
    end
    unless @line_item.fields_data.present?
      @line_item.fields_data = {}
      @line_item.fields_data[@line_item.submit_point.switch_fields.find_by(name: 'Nome cliente').field_id] = @line_item.order.customer
      @line_item.fields_data[@line_item.submit_point.switch_fields.find_by(name: 'Numero ordine').field_id] = @line_item.order.order_code
      @line_item.fields_data[@line_item.submit_point.switch_fields.find_by(name: 'Alwan').field_id] = aluan
      @line_item.fields_data[@line_item.submit_point.switch_fields.find_by(name: 'Scala').field_id] = @line_item.scale
      @line_item.fields_data[@line_item.submit_point.switch_fields.find_by(name: 'Stampa').field_id] = @line_item.sides
      @line_item.fields_data[@line_item.submit_point.switch_fields.find_by(name: 'Operatore').field_id] = current_user
      if !@line_item.cut_customer_machine.nil?
        @line_item.fields_data[@line_item.submit_point.switch_fields.find_by(name: 'Macchina').field_id] = cut_machine
      end
      if !@line_item.print_customer_machine.nil?
        @line_item.fields_data[@line_item.submit_point.switch_fields.find_by(name: 'Macchina').field_id] = print_machine
      end
    end
  end

  private

  def update_params
    params.require(:line_item).permit( :submit_point_id, :order_id, :print_customer_machine_id, :cut_customer_machine_id, :aggregated_job_id, :row_number, :subjects, :quantity, :height, :width, :material, :article_code, :article_name, :description, :aluan, :send_now, :scale, :sides, :error_message, :sending, fields_data: {} )
  end

  def append_line_item_params
    params.require(:line_item).permit(:aggregated_job_id)
  end

  def upload_file_params
    params.require(:line_item).require(:files)
  end

  def upload_params
    params.require(:line_item).permit(print_file: [], cut_file: [])
  end

  def fetch_line_item
    @line_item = LineItem.find(params[:id])
  end
end
