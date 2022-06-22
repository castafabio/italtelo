class SendToGest < ApplicationJob
  require 'nokogiri'

  queue_as :printing_solutions_v2
  sidekiq_options retry: 1, backtrace: 10

  def perform(id, kind)
    start = Time.now
    if kind == 'printer'
      resource = Printer.find_by(id: id)
    else
      resource = Cutter.find_by(id: id)
    end
    if resource.is_aggregated_job?
      code = resource.resource_id
    else
      code = resource.resource.order.order_code
    end
    begin
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.send(:'dati') {
          xml.send(:'testa') {
            if resource.is_aggregated_job?
              xml.send(:'idaggregato', resource.resource_id)
            else
              xml.send(:'codordine', resource.resource.order.order_code)
              xml.send(:'nrriga', resource.resource.row_number)
            end
          }
          if kind == 'printer'
            xml.send(:'datistampa') {
              xml.send(:'macchina', resource.resource.print_customer_machine.vg7_machine_reference)
              xml.send(:'ink', resource.ink)
              xml.send(:'jobid', resource.job_id)
              xml.send(:'nomefile', resource.file_name)
              xml.send(:'materiale', resource.material)
              xml.send(:'start_at', resource.start_at)
              xml.send(:'print_time', resource.print_time)
            }
          else
            xml.send(:'datitaglio') {
              xml.send(:'macchina', resource.resource.cut_customer_machine.vg7_machine_reference)
              xml.send(:'nomefile', resource.file_name)
              xml.send(:'start_at', resource.starts_at)
              xml.send(:'cut_time', resource.cut_time)
              xml.send(:'ends_at', resource.ends_at)
            }
          end
        }
      end
      full_path = "#{Rails.root.join("tmp")}/#{kind}_#{code}.xml"
      File.write(full_path, builder.to_xml)
      if File.file?(full_path)
        send_to_ftp!(full_path)
        resource.update!(gest_sent: Time.now)
        Log.create!(kind: 'success', action: "Export dati #{kind}", description: "Esportato dati #{code}")
      else
        Log.where(kind: 'error', action: "Export dati #{kind}", description: "Errore durante l'esportazione dei dati per #{code} a gestionale").first_or_create!
      end
      File.delete(full_path) if File.exist?(full_path)
    rescue Exception => e
      Log.create!(kind: 'error', action: "Export dati #{kind}", description: e.message)
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
