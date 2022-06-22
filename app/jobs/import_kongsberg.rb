class ImportKongsberg < ApplicationJob
  require 'nokogiri'

  queue_as :printing_solutions_v2
  sidekiq_options retry: 0, backtrace: 10

  def perform
    CustomerMachine.where(import_job: "kongsberg").cutter_machines.each do |customer_machine|
      if customer_machine.present? && customer_machine.is_mounted?
        Dir.glob("#{customer_machine.path}/*.xml").each do |xml_path|
          begin
            doc = Nokogiri::XML(File.read(xml_path))
            file_name  = doc.xpath("//Name").text.strip
            if file_name.include?('01LI')
              resource_type = "LineItem"
              resource_id = file_name.split('01LI').first.to_i
              resource = LineItem.find_by(id: resource_id)
            elsif file_name.include?('01AJ')
              resource_type = "AggregatedJob"
              resource_id = file_name.split('01AJ').first.to_i
              resource = AggregatedJob.find_by(id: resource_id)
            else
              resource_type = nil
              resource_id = nil
              resource = nil
            end
            starts_at = Time.parse(doc.xpath("//StartDate").text.strip) rescue nil
            ends_at = Time.parse(doc.xpath("//FinishDate").text.strip) rescue nil
            details = {
              resource_type: resource_type,
              resource_id: resource_id,
              file_name: file_name,
              customer_machine_id: customer_machine.id,
              cut_time: doc.xpath("//ActualCuttingTime").text.strip.downcase,
              starts_at: starts_at,
              ends_at: ends_at
            }
            cutter = Cutter.find_by(details)
            if cutter.nil?
              cutter = Cutter.create!(details)
              Log.create!(kind: 'success', action: "Import #{customer_machine}", description: "Caricati dati di taglio per #{file_name}")
            end
            File.delete(xml_path) if File.exist?(xml_path)
          rescue Exception => e
            CUTTER_LOGGER.info("errore = #{e.message}")
            log_details = { kind: 'error', action: "Import #{customer_machine}", description: "#{e.message}" }
            if Log.where(log_details).where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).size == 0
              Log.create!(log_details)
            end
          end
        end
      end
    end
  end
end
