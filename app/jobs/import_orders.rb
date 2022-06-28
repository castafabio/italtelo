class ImportOrders < ApplicationJob
  queue_as :italtelo
  sidekiq_options retry: 1, backtrace: 10

  def perform
    start = Time.now
    GESTIONALE_LOGGER.info("New import started #{start}")
    begin
      client = TinyTds::Client.new(username: ENV['SQL_DB_USER'], password: ENV['SQL_DB_PSW'], host: ENV['SQL_DB_HOST'], port: ENV['SQL_DB_PORT'], database: ENV['SQL_DB'])
      tsql = "SET ANSI_NULLS ON"
      result = client.execute(tsql)
      tsql = "SET ANSI_WARNINGS ON"
      result = client.execute(tsql)
      tsql = "SELECT lce_barcode, lce_oranno, lce_orfase, lce_orriga, lce_orserie, lce_ortipo, lce_ornum, lce_deslavo, codditt, lce_codart, lce_codcent, lce_desart, lce_descent, lce_note, lce_quant FROM avlav"
      # result = ActiveRecord::Base.connection.exec_query(tsql).each ----> per eseguire in locale
      result = client.execute(tsql).each
      ActiveRecord::Base.transaction do
        result.each do |row|
          begin
            print_reference = nil
            cut_reference = nil
            if row['lce_deslavo'].downcase == "stampa"
              print_reference = row["lce_barcode"]
            elsif row['lce_deslavo'].downcase == "taglio"
              cut_reference = row["lce_barcode"]
            end
            line_item_details = {
              customer: row['codditt'],
              order_code: row['lce_ornum'],
              order_year: row["lce_oranno"],
              order_phase: row["lce_orfase"],
              order_line_item: row["lce_orriga"],
              order_series: row["lce_orserie"],
              order_type: row["lce_ortipo"],
              article_code: row['lce_codart'],
              article_description: row['lce_desart'],
              notes: row['lce_note'],
              quantity: row['lce_quant'],
            }
            line_item = LineItem.find_by(order_year: row["lce_oranno"], order_phase: row["lce_orfase"], order_line_item: row["lce_orriga"], order_series: row["lce_orserie"], order_type: row["lce_ortipo"])
            if line_item.nil?
              line_item_details[:print_reference] = print_reference
              line_item_details[:cut_reference] = cut_reference
              line_item = LineItem.create!(line_item_details)
            else
              if row['lce_deslavo'].downcase == "stampa"
                line_item.update!(print_reference: print_reference)
              elsif row['lce_deslavo'].downcase == "taglio"
                line_item.update!(cut_reference: cut_reference)
              end
              notes = "#{line_item.notes}"
              new_notes += row['lce_note']
              line_item.update!(notes: new_notes)
            end
          rescue Exception => e
            GESTIONALE_LOGGER.info(" Order Errore: #{e.message}")
            Log.create!(kind: 'error', action: "Import Ordine", description: e.message)
          end
        end
      end
    rescue Exception => e
      GESTIONALE_LOGGER.info("errore connessione = #{e.message}")
      log_details = { kind: 'error', action: "Connessione import DB_TABLE", description: "#{e.message}" }
      if Log.where(log_details).where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).size == 0
        Log.create!(log_details)
      end
    end
  end
end
