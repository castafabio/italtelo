class UpdateItalteloTable < ApplicationJob
  queue_as :italtelo
  sidekiq_options retry: 1, backtrace: 10

  def perform(id, type)
    GESTIONALE_LOGGER.info "eeeeentro UpdateItalteloTable"
    skip = false
    inks = ""
    old_customer_machine = ""
    if type == 'printer'
      GESTIONALE_LOGGER.info "printerrrrrrrr"
      resource = Printer.find_by(id: id)
      if resource.resource.old_print_customer_machine.present?
        old_customer_machine += "Macchina impostata: #{resource.resource.old_print_customer_machine.bus240_machine_reference} - #{resource.resource.old_print_customer_machine.name}"
      end
      printers = resource.resource.printers
      if printers.size > 1
        skip = true
        duration = printers.pluck(:print_time).map(&:to_i).sum
      else
        duration = resource.print_time.to_i
      end
      printer_ink_total = resource.resource.calculate_ink_total
      if resource.resource.is_a?(AggregatedJob)
        printer_ink_total.map { |k, v| printer_ink_total[k] = v / resource.resource.line_items.size }
      end
      printer_ink_total.each do |name, value|
        inks += "#{name}: #{value}; "
      end
      reference = 'print_reference'
    else
      GESTIONALE_LOGGER.info "cutterrrrrrrrrrrrr"
      resource = Cutter.find_by(id: id)
      if resource.resource.old_cut_customer_machine.present?
        old_customer_machine += "Macchina impostata: #{resource.resource.old_cut_customer_machine.bus240_machine_reference} - #{resource.resource.old_cut_customer_machine.name}"
      end
      cutters = resource.resource.cutters
      if cutters.size > 1
        skip = true
        durations = cutters.pluck(:cut_time).map(&:to_i).sum
      else
        duration = resource.cut_time.to_i
      end
      reference = 'cut_reference'
    end

    GESTIONALE_LOGGER.info "prima di beginnnnn"
    begin
      GESTIONALE_LOGGER.info "resource == #{resource.inspect}"
      if resource.resource.is_a?(AggregatedJob)
        GESTIONALE_LOGGER.info "iffff"
        resource.resource.line_items.each do |li|
          send_to_gest!(resource, li, reference, skip, duration, inks, resource.customer_machine, old_customer_machine)
        end
      else
        GESTIONALE_LOGGER.info "elseeee"
        send_to_gest!(resource, resource.resource, reference, skip, duration, inks, resource.customer_machine, old_customer_machine)
      end
    rescue Exception => e
      GESTIONALE_LOGGER.info("errore = #{e.message}")
      log_details = { kind: 'error', action: "Scrittura su tabella #{resource}", description: "#{e.message}" }
      if Log.where(log_details).where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).size == 0
        Log.create!(log_details)
      end
    end
  end

  def send_to_gest!(resource, line_item, reference, skip, duration, inks, customer_machine, old_customer_machine)
    client = TinyTds::Client.new(username: ENV['SQL_DB_USER'], password: ENV['SQL_DB_PSW'], host: ENV['SQL_DB_HOST'], port: ENV['SQL_DB_PORT'], database: ENV['SQL_DB'])
    client.execute('SET ANSI_PADDING ON').do
    client.execute('SET ANSI_NULLS ON').do
    client.execute('SET CONCAT_NULL_YIELDS_NULL ON').do
    client.execute('SET ANSI_WARNINGS ON').do

    # tsql = "SET ANSI_NULLS ON"
    # result = client.execute(tsql)
    # tsql = "SET ANSI_WARNINGS ON"
    # result = client.execute(tsql)

    if skip
      tsql = "UPDATE avlav SET lce_qtaes = #{line_item.quantity}, lce_flevas = 'S', lce_stop = '#{resource.ends_at}', lce_tempese = #{duration}, lce_ultagg = '#{DateTime.now.strftime("%Y-%m-%d %H:%m:%S")}', lce_ink = '#{inks}', lce_note = '#{old_customer_machine}', lce_codcent = '#{customer_machine.bus240_machine_reference}', lce_descent = '#{customer_machine.name}', lce_codcope = '#{line_item.italtelo_user.code}', lce_descope = '#{line_item.italtelo_user.description}' WHERE lce_barcode = '#{line_item.send(reference)}'"
    else
      tsql = "UPDATE avlav SET lce_qtaes = #{line_item.quantity}, lce_start = '#{resource.starts_at}', lce_stato = 'C', lce_stop = '#{resource.ends_at}', lce_tempese = #{duration}, lce_ultagg = '#{DateTime.now.strftime("%Y-%m-%d %H:%m:%S")}', lce_ink = '#{inks}', lce_note = '#{old_customer_machine}', lce_codcent = '#{customer_machine.bus240_machine_reference}', lce_descent = '#{customer_machine.name}' WHERE lce_barcode = '#{line_item.send(reference)}'"
    end
    GESTIONALE_LOGGER.info("tsql == #{tsql}")
    client.execute(tsql).each
    line_item.update!(status: 'completed') if line_item.status == 'brand_new'
    line_item.check_aggregated_job
  end
end
