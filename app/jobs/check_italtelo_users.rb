class CheckItalteloUsers < ApplicationJob
  queue_as :italtelo
  sidekiq_options retry: 1, backtrace: 10

  def perform(id, type)
    client = TinyTds::Client.new(username: ENV['SQL_DB_USER'], password: ENV['SQL_DB_PSW'], host: ENV['SQL_DB_HOST'], port: ENV['SQL_DB_PORT'], database: ENV['SQL_DB'])
    tsql = "SET ANSI_NULLS ON"
    result = client.execute(tsql)
    tsql = "SET ANSI_WARNINGS ON"
    result = client.execute(tsql)
    tsql = "SELECT tb_codcope, tb_descope FROM tabcope"
    result = client.execute(tsql).each
    ActiveRecord::Base.transaction do
      result.each do |res|
        code = res["tb_codcope"]
        description = res["tb_descope"]
        if code.present?
          ItalteloUser.find_by(code: code).update!(description: description)
        else
          ItalteloUser.find_by(code: code).create!(code: code, description: description)
        end
      end
    end
  end
end
