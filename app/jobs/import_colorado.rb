class ImportColorado < ApplicationJob
  require 'csv'
  queue_as :italtelo
  sidekiq_options retry: 0, backtrace: 10

  def perform
    require 'net/http'
    require 'uri'
    require 'faraday'
    require 'mimemagic'
    require 'digest'
    CustomerMachine.where(import_job: 'colorado').printer_machines.each do |customer_machine|
      if customer_machine.present? && customer_machine.is_mounted?
        # url = "http://#{customer_machine.ip_address}"
        # conn = Faraday.new(url: url) do |faraday|
        #   faraday.adapter Faraday.default_adapter
        # end
        # res = conn.get("/accounting/#{customer_machine.serial_number}#{Date.today.strftime("%Y%m%d")}.acl") do |req|
        #   req.headers['charset'] = 'UTF-8'
        # end
        # now = Time.now.to_i
        # dest_path = File.join(Rails.root, 'tmp/csv')
        # FileUtils.mkdir_p dest_path
        # csv = "#{dest_path}/#{now}.csv"
        # f = File.open(csv, 'wb') { |fp| fp.write(res.body) }
        # sleep 5
        files = "/srv/vhosts/soltechws/production/public/Colorado/*.CSV"
        files.each do |csv|
          begin
            if File.exist?(csv)
              last_printer = customer_machine.printers.order(job_id: :desc).first
              CSV.foreach(csv, headers: true, col_sep: ";", skip_blanks: true, encoding: 'windows-1252:utf-8', converters: :numeric) do |row|
                begin
                  start_at = CustomerMachine.convert_to_time("#{row['startdate']} #{row['starttime']}")
                  next if row['result'] == 'Deleted'
                  next if last_printer.present? && row['jobid'] <= last_printer.job_id.to_i && start_at <= last_printer.start_at
                  headers = row.headers
                  ink = ""
                  headers.each do |header|
                    if header.include?('inkcolor')
                      ink += "#{header.gsub('inkcolor', '')}: #{row[header].to_f / 1000.0};"
                    end
                  end
                  file_name = row['jobname']
                  if file_name.include?("#LI_")
                    resource_type = "LineItem"
                    resource_id = file_name.split("#LI_").first
                    resource = LineItem.find_by(id: resource_id)
                  elsif file_name.include?("#AJ_")
                    resource_type = "AggregatedJob"
                    resource_id = file_name.split("#AJ_").first
                    resource = AggregatedJob.find_by(id: resource_id)
                  else
                    resource_type = nil
                    resource_id = nil
                    resource = nil
                  end
                  print_time = CustomerMachine.hour_to_seconds(row[8]) + CustomerMachine.hour_to_seconds(row[9])
                  details = {
                    resource_id: resource_id,
                    resource_type: resource_type,
                    job_id: row['jobid'],
                    file_name: file_name,
                    customer_machine_id: customer_machine.id,
                    starts_at: start_at,
                    print_time: print_time,
                    ends_at: start_at + print_time&.to_i&.seconds,
                    copies: row['copiesrequested'],
                    material: row['mediatype'],
                    extra_data: "Larghezza Bobina: #{row['mediawidth'].to_f/10_000}M, Lunghezza Stampa: #{row['medialengthused'].to_f/10_000}M, Area Stampa: #{row['printedarea'].to_f/10_000}M2, Produttività: #{row['printmode']}",
                    ink: ink
                  }
                  #PRINTER_LOGGER.info "details = #{details}"
                  printer = Printer.find_by(details)
                  if printer.nil?
                    printer = Printer.create!(details)
                    Log.create!(kind: 'success', action: "Import Colorado", description: "Caricati dati di stampa per #{file_name}")
                  end
                rescue Exception => e
                  #PRINTER_LOGGER.info("errore = #{e.message}")
                  log_details = { kind: 'error', action: "Import Colorado", description: " row == #{row[2]} #{e.message}" }
                  if Log.where(log_details).where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).size == 0
                    Log.create!(log_details)
                  end
                end
              end
            else
              raise "File CSV non trovato"
            end
          rescue Exception => e
            #PRINTER_LOGGER.info("errore = #{e.message}")
            log_details = { kind: 'error', action: "Import Colorado", description: "#{e.message}" }
            if Log.where(log_details).where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).size == 0
              Log.create!(log_details)
            end
          end
        end
      end
    end
  end

  def convert_to_time(date)
    begin
       Time.zone.parse(date)
    rescue ArgumentError
       nil
    end
  end
end
