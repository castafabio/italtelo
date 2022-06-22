class ImportZund < ApplicationJob
  require 'nokogiri'

  queue_as :italtelo
  sidekiq_options retry: 0, backtrace: 10

  def perform
    # List di tutti i file xml presenti nella cartella
    CustomerMachine.where(import_job: 'zund').cutter_machines.each do |customer_machine|
      if customer_machine.present? && customer_machine.is_mounted?
        Dir.glob("#{customer_machine.path}/*.xml").each do |xml_path|
          # Per ogni XML effettuo l'importazione
          begin
            doc = Nokogiri::XML(File.read(xml_path))
            job_name = doc.xpath("//JobStatus/@Name").text.strip
            if job_name.include?("01LI")
              resource_type = "LineItem"
              resource_id = job_name.split("01LI").first.to_i
              resource = LineItem.find_by(id: resource_id)
            elsif job_name.include?('01AJ')
              resource_type = "AggregatedJob"
              resource_id = job_name.split('01AJ').first.to_i
              resource = AggregatedJob.find_by(id: resource_id)
            else
              resource_type = nil
              resource_id = nil
              resource = nil
            end
            details = {
              resource_type: resource_type,
              resource_id: resource_id,
              file_name: job_name,
              customer_machine_id: customer_machine.id,
              cut_time: (convert_to_time(doc.xpath("//JobStatus/@EndTime").text.strip) - convert_to_time(doc.xpath("//JobStatus/@StartTime").text.strip)).to_i,
              starts_at: convert_to_time(doc.xpath("//JobStatus/@StartTime").text.strip),
              ends_at: convert_to_time(doc.xpath("//JobStatus/@EndTime").text.strip),
              quantity: doc.xpath("//JobStatus/@DoneCopies").text.strip.to_i
            }
            CUTTER_LOGGER.info "details = #{details}"
            cutter = Cutter.find_by(details)
            if cutter.nil?
              cutter = Cutter.create!(details)
              # File.rename(xml_path, "#{xml_path}.imported")
              dir = "#{customer_machine.path}/imported"
              FileUtils.mkdir_p(dir) unless File.directory?(dir)
              FileUtils.mv xml_path, "#{dir}/#{File.basename(xml_path)}"
              Log.create!(kind: 'success', action: "Import #{customer_machine}", description: "Caricati dati di taglio per #{job_name}")
            end
          rescue Exception => e
            CUTTER_LOGGER.info "Errore importazione dati #{customer_machine}: #{e.message}"
            log_details = {kind: 'error', action: "Import #{customer_machine}", description: e.message}
            if Log.where(log_details).where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).size == 0
              Log.create!(log_details)
            end
            File.rename(xml_path, "#{xml_path}.error")
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
