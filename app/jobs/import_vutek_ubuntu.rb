class ImportVutekUbuntu < ApplicationJob
  queue_as :italtelo
  sidekiq_options retry: 1, backtrace: 10

  def perform
    # Bisogna installare sulla macchina il cron ExportCSV_Lx3.sh presente in lib/scripts che va ad esportare dal database 1 file csv
    # Il crontab va definito così:
    # */5 * * * * /home/vutek01/Documents/ExportCSV_Lx3.sh
    CustomerMachine.where(import_job: 'vutek_ubuntu').printer_machines.each do |customer_machine|
      if customer_machine.present? && customer_machine.is_mounted?
        csv = "#{customer_machine.path}/Print_Times.csv"
        begin
          if File.exist?(csv)
            last_printer = customer_machine.printers.order(job_id: :desc).first
            #PRINTER_LOGGER.info("last_printer = #{last_printer&.start_at}")
            CSV.foreach(csv, headers: true, col_sep: ",", skip_blanks: true, converters: :numeric) do |row|
              begin
                #PRINTER_LOGGER.info "row['uid'] #{row['uid']}"
                break if last_printer.present? && row['uid'] <= last_printer.job_id.to_i
                next if convert_to_time(row['PrintStart']).nil? || convert_to_time(row['PrintStart']) <= Time.now.beginning_of_day
                job_name = row['Name']
                #PRINTER_LOGGER.info("job_name = #{job_name}")
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
                cyan = row['Cyan'] / 1000000000.to_f
                magenta = row['Magenta'] / 1000000000.to_f
                yellow = row['Yellow'] / 1000000000.to_f
                black = row['Black'] / 1000000000.to_f
                light_cyan = row['LightCyan'] / 1000000000.to_f
                light_magenta = row['LightMagenta'] / 1000000000.to_f
                light_yellow = row['LightYellow'] / 1000000000.to_f
                light_black = row['LightBlack'] / 1000000000.to_f
                white = row['White'] / 1000000000.to_f
                ink = "C:#{cyan};M:#{magenta};Y:#{yellow};B:#{black};LC:#{light_cyan};LM:#{light_magenta}LY:#{light_yellow};LB:#{light_black};W:#{white};"
                details = {
                  resource_type: resource_type,
                  resource_id: resource_id,
                  file_name: job_name,
                  customer_machine_id: customer_machine.id,
                  start_at: convert_to_time(row['PrintStart']),
                  print_time: convert_to_time(row['PrintFinish']) - convert_to_time(row['PrintStart']),
                  copies: nil,
                  material: nil,
                  ink: ink,
                  job_id: row['uid']
                }
                #PRINTER_LOGGER.info "details = #{details}"
                printer = Printer.find_by(details)
                if printer.nil?
                  printer = Printer.create!(details)
                  Log.create!(kind: 'success', action: "Import #{customer_machine}", description: "Caricati dati di stampa per #{job_name}")
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

  def convert_to_time(date)
    begin
       Time.parse(date)
    rescue ArgumentError
       nil
    end
  end
end
