class ImportEfkal < ApplicationJob
  queue_as :italtelo
  sidekiq_options retry: 0, backtrace: 10

  def perform
    CustomerMachine.where(import_job: 'efkal').cutter_machines.each do |customer_machine|
      return unless customer_machine.present? && customer_machine.is_mounted?
      machine_serial_number = customer_machine.serial_number
      client = Mysql2::Client.new(host: customer_machine.ip_address, username: customer_machine.username, password: customer_machine.psw, port: 3306, database: "statistic")
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
        WHERE MS.SerialNo = #{machine_serial_number} AND SL.utime > #{Date.today.beginning_of_day}
      SQL
      results = client.query(query)
      results.each do |row|
        begin
          duration = row['stop_time'] + row['running_time']
          starts_at = row['utime']
          ends_at = start_at + duration.seconds
          extra_data = "Tempo totale cucitura: #{row['sewing_time_ms'].to_i/1000}s, Numero di punti: #{row['total_stitches']}, Stops: #{row['stops']}"
          details = {
            customer_machine_id: customer_machine.id,
            file_name: 'ND',
            starts_at: start_at,
            cut_time: duration,
            ends_at: ends_at,
          }
          printer = Cutter.find_by(details)
          if printer.nil?
            printer = Cutter.create!(details)
            Log.create!(kind: 'success', action: "Import #{customer_machine}", description: "Caricati dati di stampa per #{job_name}")
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
