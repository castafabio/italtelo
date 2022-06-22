class Ping < ApplicationJob
  queue_as :italtelo
  sidekiq_options retry: 0, backtrace: 10

  def perform
    require 'net/http'
    uri = URI.parse(ENV['SS_GEST_URL'])
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Post.new(uri.path, {'Content-Type' => 'application/json', token: ENV['SS_GEST_TOKEN']})
    # request.body = data.to_json
    response = http.request(request)
  end
end
