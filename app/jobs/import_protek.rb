class ImportProtek < ApplicationJob
  queue_as :italtelo
  sidekiq_options retry: 0, backtrace: 10

  def perform
    start = Time.now
    CustomerMachine.where(import_job: 'protek').cutter_machines.each do |customer_machine|
      if customer_machine.present? && customer_machine.is_mounted?
        begin
          #CUTTER_LOGGER.info "connessa e present"
          db = SQLite3::Database.open "#{customer_machine.path}/cnlogger_exported.sqlite"
          #CUTTER_LOGGER.info "db connesso"
          query = "select * from v_LAVORAZIONI_LISTA_AGGREGATA where TERMINATO = 1 "
          last_cutter = customer_machine.cutters.last
          query += " AND DATA_LAST > '#{last_cutter.ends_at}'" if last_cutter.present?
          db.execute(query) do |row|
            begin
              Cutter.transaction do
                #CUTTER_LOGGER.info "Orario = #{DateTime.now}"
                #CUTTER_LOGGER.info "last_cutter = #{last_cutter.inspect}"
                job_name = row[9]
                #CUTTER_LOGGER.info "job_name = #{job_name.inspect}"
                if job_name.include?("#LI_")
                  resource_type = "LineItem"
                  resource_id = job_name.split("#LI_").first.split("\\").last
                  resource = LineItem.find_by(id: resource_id)
                elsif job_name.include?("#AJ_")
                  resource_type = "AggregatedJob"
                  resource_id = job_name.split("#AJ_").first.split("\\").last
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
                  cut_time: row[16],
                  starts_at: row[13],
                  ends_at: row[15]
                }
                #CUTTER_LOGGER.info "details = #{details.inspect}"
                #CUTTER_LOGGER.info "Cutter.find_by(details) = #{Cutter.find_by(details).inspect}"
                cutter = Cutter.find_by(details)
                if cutter.nil?
                  cutter = Cutter.create!(details)
                  Log.create!(kind: 'success', action: "Import #{customer_machine}", description: "Caricati dati di taglio per riga ordine #{cutter.resource}")
                end
              end
            rescue Exception => e
              #CUTTER_LOGGER.info "Errore importazione dati #{customer_machine}: #{e.message}"
              log_details = {kind: 'error', action: "Import #{customer_machine}", description: e.message}
              if Log.where(log_details).where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).size == 0
                Log.create!(log_details)
              end
            end
          end
        rescue Exception => e
          #CUTTER_LOGGER.info "Errore connessione db #{customer_machine}: #{e.message}"
          log_details = {kind: 'error', action: "Import connessione db #{customer_machine}", description: e.message}
          if Log.where(log_details).where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).size == 0
            Log.create!(log_details)
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
