class ImportOrders < ApplicationJob
  require 'nokogiri'

  queue_as :printing_solutions_v2
  sidekiq_options retry: 1, backtrace: 10

  def perform
    start=Time.now
    GESTIONALE_LOGGER.info("New import JOB started #{start}")
    begin
      @server = ENV['VG7_FTP_SERVER']
      @user = ENV['VG7_FTP_USER']
      @password = ENV['VG7_FTP_PSW']
      @folder = ENV['VG7_FTP_FOLDER']
      if ENV['VG7_USE_SFTP'].present?
        import_from_sftp!
      else
        import_from_ftp!
      end
      # Dir.glob("/home/soltech/Documenti/Printing Solutions v2/import_orders/*.xml").each do |xml_string|
      #   doc = Nokogiri::XML( File.read(xml_string) )
      #   order = parse_order_xml!(doc)
      # end
    rescue Exception => e
      GESTIONALE_LOGGER.info(" Order Errore: #{e.message}")
      Log.create!(kind: 'error', action: "Import Ordine", description: e.message)
    ensure
      GESTIONALE_LOGGER.info("**** IMPORTAZIONE ORDINI TERMINATA ****")
    end
  end

  def import_from_ftp!
    require 'net/ftp'
    ftp = Net::FTP.new(@server, @user, @password)
    files = ftp.nlst("#{@folder}/*.xml")
    files.each_with_index do |file, index|
      next if index > 0
      GESTIONALE_LOGGER.info("file == #{file.inspect}")
      begin
        xml_string = ftp.getbinaryfile( file, nil )
        Order.transaction do
          LineItem.transaction do
            doc = Nokogiri::XML( xml_string )
            order = parse_order_xml!(doc)
            GESTIONALE_LOGGER.info("Sposto il file in importati")
            ftp.rename(file, "/importati/#{File.basename(file)}")
            GESTIONALE_LOGGER.info("Import_Order_DONE: code: #{order.order_code}")
            Log.create!(kind: 'success', action: "Import Ordine", description: "Creato ordine #{order.order_code}")
          end
        end
      rescue Exception => e
        GESTIONALE_LOGGER.info("Order Errore: #{e.message}")
        Log.create!(kind: 'error', action: "Import Ordine", description: "#{order.order_code}: #{e.message}")
        GESTIONALE_LOGGER.info("Sposto il file in errori")
        ftp.rename(file, "/errori/#{File.basename(file)}")
      end
    end
  end

  def import_from_sftp!
    require 'net/ssh'
    require 'net/sftp'
    Net::SFTP.start(@server, @user, password: @password) do |sftp|
      sftp.dir.glob(folder, '*.xml').each do |remote_file|
        file_path = "#{folder}/#{remote_file.name}"
        xml_string = sftp.download!(file_path)
        Order.transaction do
          LineItem.transaction do
            doc = Nokogiri::XML( xml_string )
            order = parse_order_xml!(doc)
            sftp.remove!(file_path)
            GESTIONALE_LOGGER.info("Import_Order_DONE: code: #{order.order_code}")
            Log.create!(kind: 'success', action: "Import Ordine", description: "Creato ordine #{order.order_code}")
          end
        end
      end
    end
  end

  def parse_order_xml!(doc)
    begin
      ActiveRecord::Base.transaction do
        GESTIONALE_LOGGER.info('parse_order_xml')
        customer = doc.xpath('//fatturazione//ragsoc').text.strip
        customer.gsub! '![CDATA[ ', ''
        customer.gsub! ' ]]', ''
        order_details = { order_code: doc.xpath('//testa//codordine').text.strip.downcase, customer: customer, order_date: doc.xpath('//testa//data').text&.to_date}
        GESTIONALE_LOGGER.info("order_details = #{order_details.inspect}")
        order = Order.find_by(order_code: order_details[:order_code])
        order = Order.create!(order_details) unless order.present?
        doc.xpath('//righe//riga').each do |detail|
          row_number = detail.xpath('idriga').text.strip
          next if detail.xpath('nome').text.strip == 'Generico'
          next if row_number == 0
          text = ""
          detail.xpath('descrizioneXml').each do |row|
            row.children.each do |c|
              text += "#{c.name}: #{c.text}; \r\n"
            end
            text
          end
          height = detail.xpath('descrizioneXml/altezza').text.strip.split(' mm').first.to_i
          width = detail.xpath('descrizioneXml/base').text.strip
          sides = detail.xpath('DettagliCalcolo/LatiStampati').text.strip
          if sides == '1'
            sides = 'Monofacciale'
          else
            sides = 'Bifacciale'
          end
          vg7_machine_reference = detail.xpath('DettagliCalcolo/Componente[@Tipo="Principale"]/CodiceMacchina').text.strip
          machine = CustomerMachine.find_by(vg7_machine_reference: vg7_machine_reference) if vg7_machine_reference.present?
          vg7_machine = Vg7Machine.find_by(description: detail.xpath('descrizioneXml/macchina').text.strip)
          if vg7_machine.nil?
            vg7_machine = Vg7Machine.create!(description: detail.xpath('descrizioneXml/macchina').text.strip, vg7_machine_reference: vg7_machine_reference)
          end
          need_printing = false
          need_cutting = false
          detail.xpath('DettagliCalcolo/Componente').children.each do |row|
            if row.name == 'Stampa'
              if row.text == '1'
                need_printing = true
              end
            end
            if row.name == 'Taglio'
              if row.text == '1'
                need_cutting = true
              end
            end
          end
          if machine.present?
            if machine.kind == 'printer'
              print_customer_machine = machine.id
              cut_customer_machine = nil
              vg7_print_machine = vg7_machine.id
              vg7_cut_machine = nil
            else
              cut_customer_machine = machine.id
              print_customer_machine = nil
              vg7_cut_machine = vg7_machine.id
              vg7_print_machine = nil
            end
          else
            cut_customer_machine = nil
            print_customer_machine = nil
          end
          li_details = {
            order_id: order.id,
            print_customer_machine_id: print_customer_machine,
            cut_customer_machine_id: cut_customer_machine,
            vg7_print_machine_id: vg7_print_machine,
            vg7_cut_machine_id: vg7_cut_machine,
            row_number: row_number,
            article_code: detail.xpath('codiceart').text.strip,
            article_name: detail.xpath('nome').text.strip,
            subjects: detail.xpath('descrizioneXml/soggetti').text.strip,
            quantity: detail.xpath('descrizioneXml/quantita').text.strip,
            sides: sides,
            height: height,
            width: width,
            material: detail.xpath('descrizioneXml/materiale').text.strip,
            description: text,
            need_printing: need_printing,
            need_cutting: need_cutting
          }
          GESTIONALE_LOGGER.info("li_details = #{li_details.inspect}")
          line_item = LineItem.find_by(li_details)
          if line_item.nil?
            line_item = LineItem.create!(li_details)
          end
        end
        order
      end
    rescue Exception => e
      GESTIONALE_LOGGER.info("Order Errore: #{e.message}")
      Log.create!(kind: 'error', action: "Import Ordine", description: "#{e.message}")
    end
  end
end
