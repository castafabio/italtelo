class ImportFlora < ApplicationJob
  queue_as :italtelo
  sidekiq_options retry: 1, backtrace: 10

  def perform
    start = Time.now
    CustomerMachine.where(import_job: 'flora').each do |customer_machine|
      if customer_machine.present? && customer_machine.is_mounted?
        csv = "#{customer_machine.path}/#{Date.today.strftime("%Y-%m-%d")}.csv"
        if File.exist?(csv)
          last_printer = customer_machine.printers.last
          #PRINTER_LOGGER.info("last_printer = #{last_printer&.start_at}")
          jump = false
          details = {}
          print_mode = ""
          CSV.foreach(csv, headers: false, col_sep: ",", skip_blanks: true) do |row|
            begin
              if row[1] == '[Prompt:3]'
                #PRINTER_LOGGER.info "prompt 3"
                start_at = Time.strptime("#{Date.today} #{row[0]}", '%Y-%m-%d %H:%M:%S') rescue nil
                if start_at.nil? || (start_at.present? && last_printer.present? && start_at <= last_printer.start_at)
                  jump = true
                else
                  print_mode = row[2].split('PrintMode:').last
                  job_name = row[2].split(' Width:').first.split('Print File: ').last.strip
                  #PRINTER_LOGGER.info "job_name = #{job_name}"
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
                  #PRINTER_LOGGER.info "resource = #{resource.inspect}"
                  details = {
                    resource_type: resource_type,
                    resource_id: resource_id,
                    file_name: job_name,
                    customer_machine_id: customer_machine.id,
                    start_at: start_at
                  }
                  jump = false
                end
              elsif row[1].nil?
                width = row[0].split('W:').last.split(' ').first
                height = row[0].split('H:').last.split(' ').first
                details[:extra_data] = "Base: #{width}, Altezza: #{height}, Modalità di stampa: #{print_mode}"
              elsif !jump && row[1] == '[Prompt:11]'
                #PRINTER_LOGGER.info "prompt 11"
                end_at = Time.strptime("#{Date.today} #{row[0]}", '%Y-%m-%d %H:%M:%S') rescue nil
                details[:print_time] = end_at - details[:start_at]
                #PRINTER_LOGGER.info "details = #{details}"
                printer = Printer.find_by(details)
                if printer.nil?
                  printer = Printer.create!(details)
                end
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
  end

  def convert_to_time(date)
    begin
       Time.parse(date)
    rescue ArgumentError
       nil
    end
  end
end
