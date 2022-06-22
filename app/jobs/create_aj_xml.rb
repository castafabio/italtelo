class CreateAjXml < ApplicationJob
  require 'nokogiri'

  queue_as :printing_solutions_v2
  sidekiq_options retry: 1, backtrace: 10

  def perform(id)
    aggregated_job = AggregatedJob.find_by(id: id)
    begin
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.send(:'dati') {
          xml.send(:'idaggregato', aggregated_job.id)
          if aggregated_job.need_printing
            xml.send(:'stampa') {
              xml.send(:'codicemacchina', aggregated_job.print_customer_machine.vg7_machine_reference)
            }
          end
          if aggregated_job.need_cutting
            xml.send(:'taglio') {
              xml.send(:'codicemacchina', aggregated_job.cut_customer_machine.vg7_machine_reference)
            }
          end
          xml.send(:'righeordine') {
            aggregated_job.line_items.each do |line_item|
              xml.send(:'idriga', line_item.row_number)
            end
          }
        }
      end
      full_path = "#{Rails.root.join("tmp")}/aggregato_#{aggregated_job.to_s}.xml"
      File.write(full_path, builder.to_xml)
      if File.file?(full_path)
        send_to_ftp!(full_path)
        Log.create!(kind: 'success', action: "Export dati #{aggregated_job.id}", description: "Inviato dati #{aggregated_job.id}")
      else
        Log.where(kind: 'error', action: "Export dati #{aggregated_job.id}", description: "Errore durante l'invio dei dati per #{aggregated_job.id} a gestionale").first_or_create!
      end
      File.delete(full_path) if File.exist?(full_path)
    rescue Exception => e
      Log.create!(kind: 'error', action: "Errore durante l'invio dei dati per #{aggregated_job.id} a gestionale", description: e.message)
    end
  end

  def send_to_ftp!(file_path)
    @server = ENV['VG7_FTP_SERVER']
    @user = ENV['VG7_FTP_USER']
    @password = ENV['VG7_FTP_PSW']
    @folder = ENV['VG7_FTP_FOLDER']
    require 'net/ftp'
    file = File.new(file_path)
    Net::FTP.open(@server, @user, @password) do |ftp|
      ftp.passive = true
      begin
        ftp.nlst("#{@folder}/*")
      rescue
        ftp.mkdir(@folder)
      end
      ftp.putbinaryfile(file, "#{@folder}/#{File.basename(file_path)}")
    end
  end
end
