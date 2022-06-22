class ImportEfiXf < ApplicationJob
  require 'nokogiri'
  queue_as :printing_solutions_v2
  sidekiq_options retry: 0, backtrace: 10

  def perform
    CustomerMachine.where(import_job: 'efi_xf').printer_machines.each do |customer_machine|
      if customer_machine.present? && customer_machine.is_mounted?
        start = Time.now
        PRINTER_LOGGER.info("**** NUOVA IMPORTAZIONE DATI VUTEK #{start} ****")
        # List di tutti i file xml presenti nella cartella
        Dir.glob("#{customer_machine.path}/JOB_*").each do |xml_path|
          # Per ogni XML effettuo l'importazione
          consumptions = []
          inks = {}
          begin
            Printer.transaction do
              file_name = File.basename(xml_path)
              PRINTER_LOGGER.debug "file_name = #{file_name}"
              xml = get_file_as_string(xml_path)
              xml = xml.gsub('&', ' ')
              doc = Nokogiri::XML(xml)
              to_import = doc.xpath("//JDF/Out/PrintTime/End").text.strip.downcase
              job_name = File.basename(doc.xpath("//Input/Filename ").text.strip)
              if to_import.blank? || (to_import.present? && Printer.where(customer_machine: customer_machine.id, file_name: job_name).size > 0)
                # Salto se è un file che non è concluso oppure se è un file concluso ma che ho già importato
                next
              end
              PRINTER_LOGGER.debug "job_name = #{job_name}"
              if job_name.include?("01LI")
                resource_type = "LineItem"
                resource_id = file_name.split('01LI').first.to_i
                resource = LineItem.find_by(id: resource_id)
              elsif job_name.include?('01AJ')
                resource_type = "AggregatedJob"
                resource_id = file_name.split('01AJ').first.to_i
                resource = AggregatedJob.find_by(id: resource_id)
              else
                resource_type = nil
                resource_id = nil
                resource = nil
              end
              index = 0
              doc.xpath("//JDF/Out/Ink").each do |consumption|
                consumption.children.each do |ink_value|
                  if ink_value.name == 'Consumption'
                    consumptions << (ink_value.text.to_f * 1000).to_f
                  elsif ink_value.name == 'Name'
                    inks[ink_value.text] = consumptions[index]
                    index += 1
                  end
                end
              end
              details = {
                resource_id: resource_id,
                resource_type: resource_type,
                file_name: job_name,
                customer_machine_id: customer_machine.id,
                print_time: doc.xpath("//JDF/Out/PrintTime/Duration").text.strip.downcase,
                start_at: DateTime.strptime(doc.xpath("//JDF/Out/PrintTime/Start").text.strip.downcase,'%s'),
                copies: doc.xpath("//JDF/Out/Job/Copies").text.strip.downcase,
                ink: inks.map {|k, v| "#{k}:#{v}"}.join(';')
              }
              PRINTER_LOGGER.info "details = #{details}"
              printer = Printer.find_by(details)
              if printer.nil?
                Printer.create!(details)
                PRINTER_LOGGER.info("Importazione dati #{customer_machine} conclusa per file_name: #{job_name}")
                Log.create!(kind: 'success', action: "Import #{customer_machine}", description: "Caricato printer per file_name #{job_name}")
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
        PRINTER_LOGGER.info("**** IMPORTAZIONE DATI VUTEK TERMINATA ****")
      end
    end
  end

  def get_file_as_string(filename)
    data = ''
    f = File.open(filename, "r")
    f.each_line do |line|
      data += line
    end
    return data
  end
end
