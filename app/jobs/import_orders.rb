class ImportOrders < ApplicationJob
  queue_as :italtelo
  sidekiq_options retry: 1, backtrace: 10

  def perform
    start = Time.now
    GESTIONALE_LOGGER.info("New import started #{start}")
    italtelo_row_ids = []
    begin
      client = TinyTds::Client.new(username: ENV['SQL_DB_USER'], password: ENV['SQL_DB_PSW'], host: ENV['SQL_DB_HOST'], port: ENV['SQL_DB_PORT'], database: ENV['SQL_DB'])
      tsql = "SET ANSI_NULLS ON"
      result = client.execute(tsql)
      tsql = "SET ANSI_WARNINGS ON"
      result = client.execute(tsql)
      tsql = "SELECT lce_barcode, lce_oranno, lce_orfase, lce_orriga, lce_orserie, lce_ortipo, lce_ornum, lce_deslavo, lce_conto, lce_ragsoc, lce_codart, lce_codcent, lce_desart, lce_note, lce_quant FROM avlav WHERE lce_import = 0"
      # result = ActiveRecord::Base.connection.exec_query(tsql).each ----> per eseguire in locale
      result = client.execute(tsql).each
      ActiveRecord::Base.transaction do
        result.each do |row|
          begin
            print_reference = nil
            print_customer_machine = nil
            cut_reference = nil
            cut_customer_machine = nil
            if row['lce_deslavo'].downcase == "stampa"
              print_reference = row["lce_barcode"]
              print_customer_machine = CustomerMachine.find_by(bus240_machine_reference: row["lce_codcent"]).id
              GESTIONALE_LOGGER.info(" query print macchina: #{CustomerMachine.find_by(bus240_machine_reference: row["lce_codcent"])}")
              GESTIONALE_LOGGER.info(" print customer machine: #{print_customer_machine}")
            elsif row['lce_deslavo'].downcase == "taglio"
              cut_reference = row["lce_barcode"]
              cut_customer_machine = CustomerMachine.find_by(bus240_machine_reference: row["lce_codcent"]).id
              GESTIONALE_LOGGER.info(" query cut macchina: #{CustomerMachine.find_by(bus240_machine_reference: row["lce_codcent"])}")
              GESTIONALE_LOGGER.info(" cut customer machine: #{cut_customer_machine}")
            end
            line_item_details = {
              customer: "#{row['lce_conto']} - #{row["lce_ragsoc"]}",
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
            GESTIONALE_LOGGER.info(" details == #{line_item_details}")
            line_item = LineItem.find_by(order_year: row["lce_oranno"], order_line_item: row["lce_orriga"], order_series: row["lce_orserie"], order_type: row["lce_ortipo"], order_code: row['lce_ornum'])
            GESTIONALE_LOGGER.info(" line_item == #{line_item}")
            if line_item.nil?
              GESTIONALE_LOGGER.info(" line_item è nil")
              line_item_details[:print_reference] = print_reference
              line_item_details[:print_customer_machine_id] = print_customer_machine
              line_item_details[:cut_reference] = cut_reference
              line_item_details[:cut_customer_machine_id] = cut_customer_machine
              line_item = LineItem.create!(line_item_details)
            else
              GESTIONALE_LOGGER.info(" line_item è present quindi aggiorno")
              if row['lce_deslavo'].downcase == "stampa"
                line_item.update!(print_reference: print_reference, print_customer_machine_id: print_customer_machine)
              elsif row['lce_deslavo'].downcase == "taglio"
                line_item.update!(cut_reference: cut_reference, cut_customer_machine_id: cut_customer_machine)
              end
              notes = "#{line_item.notes}"
              new_notes += row['lce_note']
              line_item.update!(notes: new_notes)
            end
            GESTIONALE_LOGGER.info(" lce_barcode == #{row["lce_barcode"]}")
            GESTIONALE_LOGGER.info(" italtelo ids == #{italtelo_row_ids}")
            italtelo_row_ids << "#{row["lce_barcode"]}"
          rescue Exception => e
            GESTIONALE_LOGGER.info(" Import order: #{e.message}")
            log_details = { kind: 'error', action: "Import Ordine", description: "#{e.message}" }
            if Log.where(log_details).where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).size == 0
              Log.create!(log_details)
            end
          end
        end
      end
      begin
        client = TinyTds::Client.new(username: ENV['SQL_DB_USER'], password: ENV['SQL_DB_PSW'], host: ENV['SQL_DB_HOST'], port: ENV['SQL_DB_PORT'], database: ENV['SQL_DB'])
        tsql = "SET ANSI_NULLS ON"
        result = client.execute(tsql)
        tsql = "SET ANSI_WARNINGS ON"
        result = client.execute(tsql)
        GESTIONALE_LOGGER.info(" FINALE italtelo ids == #{italtelo_row_ids}")
        tsql = "UPDATE avlav SET lce_import = 1 WHERE lce_barcode IN (#{italtelo_row_ids.join(', ')})"
        client.execute(tsql).each
      rescue Exception => e
        GESTIONALE_LOGGER.info("errore aggiornamento campo importato = #{e.message}")
        log_details = { kind: 'error', action: "Errore campo importato per #{italtelo_row_ids}", description: "#{e.message}" }
        if Log.where(log_details).where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).size == 0
          Log.create!(log_details)
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
