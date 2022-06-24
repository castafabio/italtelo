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
      #
        # lce_barcode = id riga
        # lce_ornum = cod ordine
        # codditt = cliente
        # lce_codart = cod articolo
        # lce_codcent = cod macchina
        # lce_descent = nome macchina
        # lce_desart = descr art6
        # lce_note = note riga
        # lce_quant = qtà effettiva
      #
      tsql = "SELECT lce_barcode, lce_ornum, codditt, lce_codart, lce_codcent, lce_desart, lce_descent, lce_note, lce_qtaesdav FROM avlav"
      # result = ActiveRecord::Base.connection.exec_query(tsql).each ----> per eseguire in locale
      result = client.execute(tsql).each
      ActiveRecord::Base.transaction do
        result.each do |row|
          begin
            customer_machine = CustomerMachine.find_by(bus240_machine_name: row['lce_codcent'])
            if customer_machine.nil?
              customer_machine = CustomerMachine.create!(name: row['lce_descent'], bus240_machine_name: row['lce_codcent'])
            end
            line_item_details = {
              customer_machine: customer_machine,
              row_number: row['lce_barcode'],
              customer: row['codditt'],
              order_code: row['lce_ornum'],
              article_code: row['lce_codart'],
              article_description: row['lce_desart'],
              notes: row['lce_note'],
              quantity: row['lce_quant']
            }
            line_item = LineItem.find_by(row_number: row['lce_barcode'])
            if line_item.nil?
              line_item = LineItem.create!(line_item_details)
            else
              line_item.update!(line_item_details)
            end
          rescue Exception => e
            GESTIONALE_LOGGER.info(" Order Errore: #{e.message}")
            Log.create!(kind: 'error', action: "Import Ordine", description: e.message)
          ensure
            GESTIONALE_LOGGER.info("**** IMPORTAZIONE ORDINI TERMINATA ****")
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
