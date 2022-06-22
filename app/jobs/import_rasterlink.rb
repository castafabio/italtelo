class ImportRasterlink < ApplicationJob
  require 'nokogiri'

  queue_as :printing_solutions_v2
  sidekiq_options retry: 0, backtrace: 10

  def perform

    CustomerMachine.where(import_job: "rasterlink").printer_machines.each do |customer_machine|
      begin
        if customer_machine.present? && customer_machine.is_mounted?
          start = Time.now
          PRINTER_LOGGER.info("**** NUOVA IMPORTAZIONE DATI MIMAKI #{start} ****")
          # List di tutti i file xml presenti nella cartella
          # Aggiungere /**/* al .env per il listing in eventuali sottocartelle
          Dir.glob("#{customer_machine.path}/*.xml").each do |xml_path|
            # Per ogni XML effettuo l'importazione
            Printer.transaction do
              doc = Nokogiri::XML(File.read(xml_path))
              file_name = doc.xpath("/java/object/void[@property='jobBasisProperty']/object/void[2]/object[1]/void[6]/string[2]").text.strip
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
              PRINTER_LOGGER.debug "file_name = #{file_name}"
              line_item_id = file_name.split('_').first.to_i
              PRINTER_LOGGER.debug "line_item_id = #{line_item_id}"
              line_item = LineItem.find(line_item_id)
              raise "Riga ordine non trovata con l'id #{line_item_id}" unless line_item.present?
              #import colori in un'unica stringa
              cyan = doc.xpath("/java/object/void/object/void[@property='inkUsed']/object[1]/void[1]/int[2]").text.strip.downcase
              magenta = doc.xpath("/java/object/void/object/void[@property='inkUsed']/object[1]/void[2]/int[2]").text.strip.downcase
              yellow = doc.xpath("/java/object/void/object/void[@property='inkUsed']/object[1]/void[3]/int[2]").text.strip.downcase
              black = doc.xpath("/java/object/void/object/void[@property='inkUsed']/object[1]/void[4]/int[2]").text.strip.downcase
              white1 = doc.xpath("/java/object/void/object/void[@property='inkUsed']/object[1]/void[5]/int[2]").text.strip.downcase
              white2 = doc.xpath("/java/object/void/object/void[@property='inkUsed']/object[1]/void[6]/int[2]").text.strip.downcase
              ink = "C:#{cyan};M:#{magenta};Y:#{yellow};B:#{black};W1:#{white1};W2:#{white2}"
              # Il tempo in java viene misurato in millisec dal 1970 mentre in Rails è misurato in secondi
              start_at = Time.at(doc.xpath("/java/object/void/object/void[@property='date']").text.strip.to_i/1000)

              details = {
                resource_type:  resource_type,
                resource_id:    resource_id,
                job_id:         line_item_id,
                file_name:      file_name,
                start_at:       start_at,
                customer_machine_id: customer_machine.id,
                print_time:     doc.xpath("/java/object/void[20]/object/void[@property='timeCmdPrn']/long").text.strip.downcase,
                copies:         doc.xpath("/java/object/void/object/void[@property='copyCount']").text,
                ink: ink
              }
              PRINTER_LOGGER.debug "details = #{details.inspect}"
              printer = Printer.find_by(details)
              if printer.nil?
                printer = Printer.create!(details)
                Log.create!(kind: 'success', action: "Import #{customer_machine}", description: "Caricato rasterlink per line_item #{file_name}")
              end
              File.rename(xml_path, "#{xml_path}.imported")
              PRINTER_LOGGER.info("Importazione dati #{customer_machine} conclusa per line_item_id: #{line_item_id}")
            end
          end
        end
      rescue Exception => e
        PRINTER_LOGGER.info("Errore importazione dati Mimaki: #{e.message}")
        Log.create!(kind: 'error', action: "Import #{customer_machine}", description: e.message)
        File.rename(xml_path, "#{xml_path}.error")
      end
    end
  end
end
