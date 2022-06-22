require "net/http"
require "uri"
class MultipartPost
  BOUNDARY = "-----------RubyMultipartPost"
  EOL = "\r\n"

  def initialize uri, token, &block
    @params = Array.new
    @uri = URI.parse uri
    @token = token
    instance_eval &block if block
  end

  def params_part key, value
    @params << multipart_text(key, value)
  end

  def files_part key, filename, mime_type, content
    @params << multipart_file(key, filename, mime_type, content)
  end

  def request_body
    body = @params.map{|p| "--#{BOUNDARY}#{EOL}" << p}.join ""
    body << "#{EOL}--#{BOUNDARY}--#{EOL}"
  end

  def run
    http = Net::HTTP.new @uri.host, @uri.port
    request = Net::HTTP::Post.new @uri.request_uri
    request.body = request_body
    request['Authorization'] = "Bearer #{@token}"
    request.set_content_type "multipart/form-data", {"boundary" => BOUNDARY}
    res = http.request request
    res.body
  end

  private
  def multipart_text key, value
    content = "Content-Disposition: form-data; name=\"#{key}\"" <<
      EOL <<
      EOL <<
      "#{value}" << EOL
  end

  def multipart_file key, filename, mime_type, content
    content = "Content-Disposition: form-data; name=\"#{key}\"; filename=\"#{filename}\"#{EOL}" <<
      "Content-Type: #{mime_type}\r\n" <<
      EOL <<
      "#{content}" << EOL
  end
end
