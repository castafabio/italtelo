class Backup < ApplicationJob
  require 'net/ssh'
  require 'net/sftp'

  queue_as :italtelo
  sidekiq_options retry: 0, backtrace: 10

  def perform
    path = "#{ENV['BACKUP_FOLDER']}/#{Rails.env}.sql.gz"
    `mysqldump --opt #{config} | gzip -c | cat > #{path}`
    send_to_sftp!(path)
  end

  private

  def config(options = {})
    options[:database] ||= Rails.configuration.database_configuration[Rails.env]['database']
    options[:host] ||= Rails.configuration.database_configuration[Rails.env]['host']
    options[:password] ||= Rails.configuration.database_configuration[Rails.env]['password']
    options[:socket] ||= Rails.configuration.database_configuration[Rails.env]['socket']
    options[:username] ||= Rails.configuration.database_configuration[Rails.env]['username']
    "#{options[:host] ? "--host=#{options[:host]}" : "--socket=#{options[:socket]}"} -u #{options[:username]} -p#{options[:password]} #{options[:database]}"
  end

  def send_to_sftp!(file_path)
    server = ENV['SS_FTP_SERVER']
    port = ENV['SS_FTP_PORT'] || 22
    user = ENV['SS_FTP_USER']
    password = ENV['SS_FTP_PSW']
    folder = ENV['SS_FTP_FOLDER']
    backup_path = "#{folder}/backup/italtelo"
    Net::SFTP.start(server, user, password: password, port: port.to_i) do |sftp|
      file_intro = "#{Date.today.strftime("%A")}_#{Time.now.hour}_"
      begin
        sftp.mkdir! backup_path
      rescue Net::SFTP::StatusException => e
        if e.code == 4
          # directory already exists. Carry on.
        else
          raise "Creazione cartella #{backup_path} non riuscita"
        end
      end
      sftp.upload(file_path, "#{backup_path}/#{file_intro}#{File.basename(file_path)}")
    end
  end
end
