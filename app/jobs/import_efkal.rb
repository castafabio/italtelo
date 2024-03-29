class ImportEfkal < ApplicationJob
  queue_as :italtelo
  sidekiq_options retry: 0, backtrace: 10

  def perform
    CustomerMachine.where(import_job: 'efkal').cutter_machines.each do |customer_machine|
      return unless customer_machine.present?
      client = Mysql2::Client.new(host: customer_machine.ip_address, username: customer_machine.username, password: customer_machine.psw, port: 3306, database: "i4_production")
      query = <<-SQL
        SELECT
          MS.Pieces as pieces,
          SL.UpdateTime as utime,
          SL.TotalSewingTime_ms AS sewing_time_ms,
          SL.TotalStitches as total_stitches,
          SL.AverageSpeed_rpm AS average_speed,
          SL.RunTime_ms AS running_time,
          SL.StopTime_ms AS stop_time,
          SL.Stops AS stops
        FROM i4_production.machinestatus AS MS
        INNER JOIN i4_production.sewinginfolog AS SL ON MS.MachineGUID = SL.MachineGUID
        WHERE SL.UpdateTime > timestamp(current_date);
      SQL
      results = client.query(query)
      results.each do |row|
        begin
          duration = (row['running_time'].to_i / 1000).round
          starts_at = row['utime']
          ends_at = starts_at + duration.seconds
          extra_data = "Tempo totale cucitura: #{row['sewing_time_ms'].to_i/1000}s, Numero di punti: #{row['total_stitches']}, Stops: #{row['stops']}"
          if LineItem.where.not(send_at: nil).where(cut_customer_machine_id: CustomerMachine.efkal.id).where("status NOT LIKE 'completed'").size > 0
            resource_type = "LineItem"
            resource_id = LineItem.where.not(send_at: nil).where(cut_customer_machine_id: CustomerMachine.efkal.id).where("status NOT LIKE 'completed'").first&.id
            resource = LineItem.find_by(id: resource_id)
          else
            resource_type = nil
            resource_id = nil
            resource = nil
          end
          details = {
            resource_id: resource_id,
            resource_type: resource_type,
            customer_machine_id: customer_machine.id,
            file_name: 'ND',
            starts_at: DateTime.parse(starts_at.to_s),
            cut_time: duration,
            ends_at: DateTime.parse(ends_at.to_s),
          }
          printer = Cutter.find_by(details)
          if printer.nil?
            printer = Cutter.create!(details)
            Log.create!(kind: 'success', action: "Import #{customer_machine}", description: "Caricati dati di stampa per #{starts_at}")
          end
        rescue Exception => e
          log_details = { kind: 'error', action: "Import #{customer_machine}", description: "#{e.message}" }
          if Log.where(log_details).where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).size == 0
            Log.create!(log_details)
          end
        end
      end
    end
  end
end
