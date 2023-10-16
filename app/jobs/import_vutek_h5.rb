class ImportVutekH5 < ApplicationJob
  queue_as :italtelo
  sidekiq_options retry: 1, backtrace: 10

  def perform
    # Bisogna installare sulla macchina il cron ExportCSV_H5.sh presente in lib/scripts che va ad esportare dal database 2 file csv
    # Il crontab va definito così:
    # */5 * * * * /home/vutek01/Documents/ExportCSV_H5.sh
    CustomerMachine.where(import_job: 'vutek_h5').printer_machines.each do |customer_machine|
      if customer_machine.present? && customer_machine.is_mounted?
        time_csv = "#{customer_machine.path}/Print_Times.csv"
        ink_csv = "#{customer_machine.path}/Ink_H5.csv"
        begin
          if File.exist?(time_csv) && File.exist?(ink_csv)
            last_printer = customer_machine.printers.order(job_id: :desc).first
            PRINTER_LOGGER.info("last_printer = #{last_printer&.job_id}")
            CSV.foreach(time_csv, headers: true, col_sep: ",", skip_blanks: true, converters: :numeric) do |row|
              begin
                if row[4] == "Completed"
                  next if row[1] <= Time.now.beginning_of_day.to_i
                  break if last_printer.present? && row[0] <= last_printer.job_id.to_i
                  job_name = row[2]
                  PRINTER_LOGGER.info "job_name = #{job_name}"
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
                  print_time = row[3] - row[1]
                  details = {
                    resource_type: resource_type,
                    resource_id: resource_id,
                    file_name: job_name,
                    customer_machine_id: customer_machine.id,
                    start_at: DateTime.strptime(row[1].to_s,'%s'),
                    print_time: print_time,
                    job_id: row[0],
                    copies: nil,
                    material: nil,
                    extra_data: row[4]
                  }
                  PRINTER_LOGGER.info "details = #{details}"
                  ink_format =/:\d+.\d*/
                  csv_ink = CSV.foreach(ink_csv, col_sep: ",", skip_blanks: true, converters: :numeric)
                  csv_ink.drop(1).each do |ink_row|
                    if ink_row[0] == row[0]
                      ink = ""
                      ink_row.drop(1).each do |ink_line|
                        f_letter = ink_line[0]
                        color = ink_line.match(ink_format).to_s
                        ink += f_letter + color + ";"
                      end
                      details[:ink] = ink
                    end
                  end
                  PRINTER_LOGGER.info "details = #{details}"
                  printer = Printer.find_by(details)
                  if printer.nil?
                    printer = Printer.create!(details)
                    Log.create!(kind: 'success', action: "Import H5", description: "Caricati dati di stampa per #{job_name}")
                  end
                end
              rescue Exception => e
                PRINTER_LOGGER.info "Errore importazione dati #{customer_machine}: #{e.message}"
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
          PRINTER_LOGGER.info("errore = #{e.message}")
          log_details = { kind: 'error', action: "Import H5", description: "#{e.message}" }
          if Log.where(log_details).where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).size == 0
            Log.create!(log_details)
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
