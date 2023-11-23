class ImportSumma < ApplicationJob
  queue_as :italtelo
  sidekiq_options retry: 0, backtrace: 10

  def perform
    start = Time.now
    CustomerMachine.where(import_job: 'summa').cutter_machines.each do |customer_machine|
      if customer_machine.present? && customer_machine.is_mounted?
        csv = "#{customer_machine.path}/Joblog.csv"
        last_cutter = customer_machine.cutters.last
        if File.exist?(csv)
          details = {}
          CSV.foreach(csv, headers: true, col_sep: ";", skip_blanks: true) do |row|
            begin
              starts_at = convert_to_time(row['Start time'] + " " + row['Date'])
              ends_at = convert_to_time(row['End time'] + " " + row['Date'])
              CUTTER_LOGGER.info "starts_at = #{starts_at.inspect}"
              next if last_cutter.present? && last_cutter.starts_at > starts_at
              job_name = row['Job name']
              CUTTER_LOGGER.info "job_name = #{job_name}"
              if job_name.include?("#LI_")
                resource_type = "LineItem"
                resource_id = job_name.split("#LI_").first
                resource = LineItem.find_by(id: resource_id)
              elsif job_name.include?("#AJ_")
                resource_type = "AggregatedJob"
                resource_id = job_name.split("#AJ_").first
                resource = AggregatedJob.find_by(id: resource_id)
              else
                resource_type = nil
                resource_id = nil
                resource = nil
              end
              if starts_at.present? && ends_at.present?
                cut_time = (convert_to_time(row['End time']) - convert_to_time(row['Start time'])).to_i
              else
                cut_time = 0
              end
              details = {
                resource_type: resource_type,
                resource_id: resource_id,
                file_name: job_name,
                customer_machine_id: customer_machine.id,
                cut_time: cut_time,
                starts_at: starts_at,
                ends_at: ends_at
              }
              CUTTER_LOGGER.info "details = #{details}"
              cutter = Cutter.find_by(details)
              if cutter.nil?
                cutter = Cutter.create!(details)
              end
            rescue Exception => e
              CUTTER_LOGGER.info "Errore importazione dati #{customer_machine}: #{e.message}"
              log_details = {kind: 'error', action: "Import #{customer_machine}", description: e.message}
              if Log.where(log_details).where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).size == 0
                Log.create!(log_details)
              end
            end
          end
        end
      end
    end
  end

  def convert_to_time(date)
    begin
       date = Time.parse(date)
    rescue ArgumentError
       nil
    end
  end
end
