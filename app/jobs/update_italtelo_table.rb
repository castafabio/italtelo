class UpdateItalteloTable < ApplicationJob
  queue_as :italtelo
  sidekiq_options retry: 1, backtrace: 10

  def perform(id, type)
    skip = false
    new_inks = ""
    if type == 'printer'
      resource = Printer.find_by(id: id)
      if Printer.where(resource_id: resource.resource_id, resource_type: 'AggregatedJob').size > 0
        printers = Printer.where(resource_id: resource.resource_id, resource_type: 'AggregatedJob')
      elsif Printer.where(resource_id: resource.resource_id, resource_type: 'LineItem').size > 0
        printers = Printer.where(resource_id: resource.resource_id, resource_type: 'LineItem')
      end
      if printers.size > 1
        skip = true
        duration = (printers.pluck(:print_time).map { |v| v.to_i }).sum
      else
        duration = resource.print_time.to_i
      end
      printer_ink_total = resource.resource.calculate_ink_total
      if resource.resource.is_a?(AggregatedJob)
        printer_ink_total.map { |k, v| printer_ink_total[k] = v / resource.resource.line_items.size }
      end
      inks = ""
      printer_ink_total.each do |name, value|
        inks += "#{name}: #{value}; "
      end
      start_at = resource.start_at
      end_at = resource.end_at
    else
      resource = Cutter.find_by(id: id)
      cutters = Cutter.where(resource_id: resource.resource_id, resource_type: 'AggregatedJob')
      if cutters.size > 1
        skip = true
        durations = (cutters.pluck(:cut_time).map { |v| v.to_i }).sum
      else
        duration = resource.cut_time.to_i
      end
      start_at = resource.starts_at
      end_at = resource.ends_at
    end
    if resource.resource.is_a?(AggregatedJob)
      quantity = resource.resource.line_items.first.quantity
      italtelo_line_item_ids = ""
      resource.resource.line_items.each do |line_item|
        italtelo_line_item_ids += "#{line_item.row_number};"
      end
    else
      italtelo_line_item_ids = resource.resource.row_number
      quantity = resource.resource.quantity
    end
    begin
      client = TinyTds::Client.new(username: ENV['SQL_DB_USER'], password: ENV['SQL_DB_PSW'], host: ENV['SQL_DB_HOST'], port: ENV['SQL_DB_PORT'], database: ENV['SQL_DB'])
      client.execute('SET ANSI_PADDING ON').do
      client.execute('SET ANSI_NULLS ON').do
      client.execute('SET CONCAT_NULL_YIELDS_NULL ON').do
      client.execute('SET ANSI_WARNINGS ON').do

      # tsql = "SET ANSI_NULLS ON"
      # result = client.execute(tsql)
      # tsql = "SET ANSI_WARNINGS ON"
      # result = client.execute(tsql)

      italtelo_line_item_ids.split(";").each do |li_row_number|
        if skip
          #  colonna_inchiostri = #{new_inks}
          tsql = "UPDATE avlav SET lce_qtaes = #{quantity}, lce_stato = 'C', lce_stop = #{end_at}, lce_tempese = #{duration}, lce_ultagg = #{DateTime.now} WHERE id = #{li_row_number}"
        else
          tsql = "UPDATE avlav SET lce_qtaes = #{quantity}, lce_start = #{start_at}, lce_stato = 'C', lce_stop = #{end_at}, lce_tempese = #{duration}, lce_ultagg = #{DateTime.now}, colonna_inchiostri = #{new_inks} WHERE id = #{li_row_number}"
        end
        GESTIONALE_LOGGER.info("tsql == #{tsql}")
        client.execute(tsql)
        line_item = LineItem.find_by(row_number: li_row_number)
        line_item.update!(status: 'completed') if line_item.status == 'brand_new'
        line_item.check_aggregated_job
      end
      # ActiveRecord::Base.connection.exec_query(tsql)
    rescue Exception => e
      GESTIONALE_LOGGER.info("errore = #{e.message}")
      log_details = { kind: 'error', action: "Scrittura su tabella #{resource}", description: "#{e.message}" }
      if Log.where(log_details).where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).size == 0
        Log.create!(log_details)
      end
    end
  end
end
