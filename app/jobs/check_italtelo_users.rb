class CheckItalteloUsers < ApplicationJob
  queue_as :italtelo
  sidekiq_options retry: 1, backtrace: 10

  def perform
    begin
      #GESTIONALE_LOGGER.info("Inizio import utenti")
      client = TinyTds::Client.new(username: ENV['SQL_DB_USER'], password: ENV['SQL_DB_PSW'], host: ENV['SQL_DB_HOST'], port: ENV['SQL_DB_PORT'], database: ENV['SQL_DB'])
      tsql = "SET ANSI_NULLS ON"
      result = client.execute(tsql)
      tsql = "SET ANSI_WARNINGS ON"
      result = client.execute(tsql)
      tsql = "SELECT tb_codcope, tb_descope FROM tabcope"
      result = client.execute(tsql).each
      ActiveRecord::Base.transaction do
        result.each do |res|
          #GESTIONALE_LOGGER.info("res = #{res.inspect}")
          code = res["tb_codcope"]
          description = res["tb_descope"]
          if ItalteloUser.find_by(code: code).present?
            ItalteloUser.find_by(code: code).update!(description: description)
          else
            ItalteloUser.create!(code: code, description: description)
          end
        end
      end
    rescue Exception => e
      #GESTIONALE_LOGGER.info("errore importazione operatori = #{e.message}")
      log_details = { kind: 'error', action: "Connessione import operatori", description: "#{e.message}" }
      if Log.where(log_details).where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).size == 0
        Log.create!(log_details)
      end
    end
  end
end
