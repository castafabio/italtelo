class ImportEpson < ApplicationJob
  queue_as :italtelo
  sidekiq_options retry: 0, backtrace: 10

  def perform
    CustomerMachine.where(import_job: 'epson').printer_machines.each do |customer_machine|
      Epson.where('SerialNumber': customer_machine.serial_number, imported: false).each do |epson|
        begin
          name = epson.DocName
          ink_list = epson.Ink.split('##')
          inks = ink_list.map { |ink| ink.gsub('InkUse_', '') }.join(';')
          if name.include?("#LI")
            resource_type = "LineItem"
            resource_id = name.split("#LI_").first
            resource = LineItem.find_by(id: resource_id)
          elsif name.include?("#AJ_")
            resource_type = "AggregatedJob"
            resource_id = name.split("#AJ_").first
            resource = AggregatedJob.find_by(id: resource_id)
          elsif AggregatedJob.brand_new.where("file_name LIKE :file_name", file_name: file_name).where("created_at >= :today", today: Date.today - 1.month).size > 0
            resource_type = "AggregatedJob"
            resource = AggregatedJob.brand_new.where("file_name LIKE :file_name", file_name: file_name).where("created_at >= :today", today: Date.today - 1.month).last
            resource_id = resource.id
          else
            resource_type = nil
            resource_id = nil
            resource = nil
          end
          details = {
            customer_machine_id: customer_machine.id,
            resource_type:  resource_type,
            resource_id:    resource_id,
            file_name:      name,
            starts_at:       epson.PrintStartTime,
            ends_at:         epson.PrintEndTime,
            print_time:     epson.PrintEndTime - epson.PrintStartTime,
            copies:         epson.PageNumber,
            job_id:         epson.JobId,
            material:       epson.UserMediaName,
            ink:            inks
          }
          PRINTER_LOGGER.info "details = #{details}"
          printer = Printer.find_by(details)
          if printer.nil?
            printer = Printer.create!(details)
            epson.update!(imported: true)
            Log.create!(kind: 'success', action: "Import #{customer_machine}", description: "Caricati dati di stampa per #{name}")
          end
        rescue Exception => e
          PRINTER_LOGGER.info "Errore importazione dati #{customer_machine}: #{e.message}"
          log_details = {kind: 'error', action: "Import #{customer_machine}", description: e.message}
          if Log.where(log_details).where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).size == 0
            Log.create!(log_details)
          end
        end
      end
    end
  end
end
