class ImportColorado < ApplicationJob
  require 'csv'
  queue_as :printing_solutions_v2
  sidekiq_options retry: 0, backtrace: 10

  def perform
    require 'net/http'
    require 'uri'
    require 'faraday'
    require 'mimemagic'
    require 'digest'

    CustomerMachine.where(import_job: 'colorado').printer_machines.each do |customer_machine|
      if customer_machine.present? && customer_machine.is_mounted?
        url = "http://#{customer_machine.ip_address}"
        conn = Faraday.new(url: url) do |faraday|
          # faraday.response :logger, CUSTOMER_MACHINE_LOGGER, bodies: true
          faraday.adapter Faraday.default_adapter
        end
        res = conn.get("/accounting/#{customer_machine.serial_number}#{Date.today.strftime("%Y%m%d")}.acl") do |req|
          req.headers['charset'] = 'UTF-8'
        end
        CUSTOMER_MACHINE_LOGGER.debug "res = #{res.inspect}"
        now = Time.now.to_i
        dest_path = File.join(Rails.root, 'tmp/csv')
        FileUtils.mkdir_p dest_path
        csv = "#{dest_path}/#{now}.csv"
        f = File.open(csv, 'wb') { |fp| fp.write(res.body) }
        sleep 5
        begin
          if File.exist?(csv)
            last_printer = customer_machine.printers.order(job_id: :desc).first
            CSV.foreach(csv, headers: true, col_sep: ";", skip_blanks: true, encoding: 'windows-1252:utf-8', converters: :numeric) do |row|
              begin
                next if row[14] == 'Deleted'
                next if last_printer.present? && row[2] <= last_printer.job_id.to_i
                file_name = row[4]
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
                headers = row.headers
                ink = ""
                headers.each do |header|
                  if header.include?('inkcolor')
                    ink += "#{header.gsub('inkcolor', '')}: #{row[header].to_f / 1000.0}; "
                  end
                end
                print_time = CustomerMachine.hour_to_seconds(row[8]) + CustomerMachine.hour_to_seconds(row[9])
                details = {
                  resource_id: resource_id,
                  resource_type: resource_type,
                  job_id: row[2],
                  file_name: file_name,
                  customer_machine_id: customer_machine.id,
                  start_at: convert_to_time("#{row[6]} #{row[7]}"),
                  print_time: print_time,
                  copies: row[18],
                  material: row[20],
                  ink: ink
                }
                CUSTOMER_MACHINE_LOGGER.info "details = #{details}"
                printer = Printer.find_by(details)
                if printer.nil?
                  printer = Printer.create!(details)
                  Log.create!(kind: 'success', action: "Import Colorado", description: "Caricati dati di stampa per #{file_name}")
                end
              rescue Exception => e
                CUSTOMER_MACHINE_LOGGER.info("errore = #{e.message}")
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
          CUSTOMER_MACHINE_LOGGER.info("errore = #{e.message}")
          log_details = { kind: 'error', action: "Import Colorado", description: "#{e.message}" }
          if Log.where(log_details).where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).size == 0
            Log.create!(log_details)
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
