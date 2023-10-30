class ImportVutekWindows < ApplicationJob
  queue_as :italtelo
  sidekiq_options retry: 1, backtrace: 10

  def perform
    CustomerMachine.where(import_job: 'vutek_windows').each do |customer_machine|
      if customer_machine.present? && customer_machine.is_mounted?
        if Dir.glob("#{customer_machine.path}/*.csv").size > 0
          files = Dir.glob("#{customer_machine.path}/*.csv")
          kind = 'csv'
        elsif Dir.glob("#{customer_machine.path}/*.log").size > 0
          files = Dir.glob("#{customer_machine.path}/*.log")
          kind = 'log'
        else
          files = []
        end
        files.each do |file|
          begin
            if File.exist?(file)
              last_printer = customer_machine.printers.last
              #PRINTER_LOGGER.info("last_printer = #{last_printer&.start_at}")
              if file.split('.').last == 'csv'
                value = ","
              elsif file.split('.').last == 'log'
                value = "\t"
              end
              CSV.foreach(file, headers: true, col_sep: value, skip_blanks: true) do |row|
                begin
                  # se è un file .log prendo certi headers, altrimenti prendo quelli del .csv
                  if kind == 'log'
                    next if convert_to_time(row["Start Time"]) <= Time.now.beginning_of_day
                    next if last_printer.present? && convert_to_time(row["Start Time"]) <= last_printer.start_at
                    job_name = row["Job Name"]
                    print_time = CustomerMachine.hour_to_seconds(row["Print Time (h:m:s)"])
                    start_at = convert_to_time(row["Start Time"])
                    copies = row["Copies"]
                    status = row["Status"]
                    job_id = nil
                    material = row["MediaName"]
                  else
                    next if last_printer.present? && (row["PRINT JOB ID"].to_i <= last_printer.job_id.to_i)
                    job_name = row["JOB PATH"].split('\\').last.strip
                    print_time = CustomerMachine.hour_to_seconds(row["PRINT TIME"])
                    date = Date.strptime(row["START DATE"], "%m/%d/%Y")
                    time = convert_to_time(row["START TIME"])
                    start_at = DateTime.new(date.year, date.month, date.day, time.strftime("%H").to_i, time.strftime("%m").to_i, time.strftime("%S").to_i)
                    copies = 1
                    status = row["COMPLETED"]
                    job_id = row["PRINT JOB ID"]
                    material = row["MEDIA"]
                  end
                  if job_name.include?("#LI_")
                    resource_type = "LineItem"
                    resource_id = job_name.split("#LI_").first
                    resource = LineItem.find_by(id: resource_id)
                  elsif job_name.include?("#AJ_")
                    resource_type = "AggregatedJob"
                    resource_id = job_name.split("#AJ_").first
                    resource = AggregatedJob.find_by(id: resource_id)
                  else
                    resource_type = nil
                    resource_id = nil
                    resource = nil
                  end
                  headers = row.headers.compact
                  ink = ""
                  headers.each do |header|
                    if kind == 'log' && header.include?('Ink Consumption (ml)') && header.exclude?('Total Ink Consumption (ml)')
                      ink += "#{header.gsub('Ink Consumption (ml)', '').strip}: #{row[header].to_f};"
                    elsif kind == 'csv' && header.include?('ml') && header.exclude?('ALL ml')
                      ink += "#{header.gsub(' ml', '').strip}: #{row[header].to_f};"
                    end
                  end
                  details = {
                    resource_type: resource_type,
                    resource_id: resource_id,
                    file_name: job_name,
                    customer_machine_id: customer_machine.id,
                    job_id: job_id,
                    start_at: start_at,
                    print_time: print_time,
                    copies: copies,
                    material: material,
                    extra_data: status,
                    ink: ink
                  }
                  #PRINTER_LOGGER.info "details = #{details}"
                  printer = Printer.find_by(details)
                  if printer.nil?
                    printer = Printer.create!(details)
                  end
                rescue Exception => e
                  #PRINTER_LOGGER.info "Errore importazione dati #{customer_machine}: #{e.message}"
                  log_details = {kind: 'error', action: "Import #{customer_machine}", description: e.message}
                  if Log.where(log_details).where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).size == 0
                    Log.create!(log_details)
                  end
                end
              end
            else
              raise "File CSV non trovato"
            end
          rescue Exception => e
            #PRINTER_LOGGER.info "Errore importazione dati #{customer_machine}: #{e.message}"
            log_details = {kind: 'error', action: "Import #{customer_machine}", description: e.message}
            if Log.where(log_details).where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).size == 0
              Log.create!(log_details)
            end
          end
        end
      end
    end
  end

  def convert_to_time(date)
    begin
       Time.parse(date)
    rescue ArgumentError
       nil
    end
  end
end
