class Restore < ApplicationJob
  queue_as :printing_solutions_v2
  sidekiq_options retry: 1, backtrace: 10

  # Il comando da lanciare per eseguire il restore dalla console di rails è: Restore.perform_later('environment') dove environment può essere production o development
  def perform(environment)
    if Rails.env != 'production'
      `rails db:drop DISABLE_DATABASE_ENVIRONMENT_CHECK=1`
      `rails db:create`
    end
    `zcat #{ENV['BACKUP_FOLDER']}/#{environment}.sql.gz | mysql #{config}`
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
end
