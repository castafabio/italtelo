require 'faraday'
require 'openssl'
require 'base64'
require 'mimemagic'
require 'digest'

class SwitchApi
  def initialize
    @url = "#{Customization.switch_url}:#{Customization.switch_port}"
    @conn = Faraday.new(url: @url) do |faraday|
      # faraday.response :logger, ::Logger.new(STDOUT), bodies: true
      faraday.adapter Faraday.default_adapter
    end
    public_key_file = Rails.root.join("app", "switch_api", "public.pem")
    public_key = OpenSSL::PKey::RSA.new(File.read(public_key_file))
    @encrypted_password = Base64.encode64(public_key.public_encrypt(Customization.switch_psw))
  end

  def login!
    resp = @conn.post('login') do |req|
      req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
      req.headers['charset'] = 'UTF-8'
      req.params['username'] = Customization.switch_user
      req.params['password'] = "!@$#{@encrypted_password}"
    end
    body = JSON.parse(resp.body)
    success = body['success']
    if success
      Customization.find_by_parameter('switch_token').update!(value: body['token'])
      @token = body['token']
    else
      raise "Errore login: #{body['error']}"
    end
  end

  def logout!(token)
    resp = @conn.get('logout') do |req|
      req.headers['Authorization'] = "Bearer #{token}"
    end
    body = JSON.parse(resp.body)
    success = body['status']
    if success
      "Logout effettuato correttamente!"
    else
      raise "Errore logout: #{body['error']}"
    end
  end

  def get_submit_point_list!(token)
    resp = @conn.get('api/v1/submitpoints') do |req|
      req.headers['Authorization'] = "Bearer #{token}"
    end
    body = JSON.parse(resp.body)
    if resp.status == 200
      body
    else
      raise "Errore nel recupero dei submit point. #{body['error']}"
    end
  end

  def get_submit_point_by_name!(token, name)
    submit_points = get_submit_point_list!(token)
    submit_point_found = nil
    submit_points.each do |sp|
      if sp['name'] == name
        submit_point_found = sp
        break
      end
    end
    if submit_point_found.nil?
      raise "Nessun submit point trovato col nome #{name}"
    else
      submit_point_found
    end
  end

  def ping!(token)
    resp = @conn.get('api/v1/ping?refresh=true') do |req|
      req.headers['Authorization'] = "Bearer #{token}"
    end
    if resp.status == 200
      token
    else
      nil
    end
  end

  def post_job!(token, submit_point, file_path, job)
    time = Time.now
    flow_id = submit_point['flowId'] # ID of the flow where the job should be submitted
    object_id = submit_point['objectId'] # ID of the Submit point where the job should be submitted
    sp_metadata_list = submit_point['metadata'].map {|m| [m['name'], m['id']] }
    sp = job.submit_point
    raise "Nessun submit point trovato a sistema con il nome #{submit_point}" unless sp
    # Controllo che i metadati siano stati sincronizzati
    not_found_metadata = submit_point['metadata'].map {|m| m['id']} - sp.switch_fields.pluck(:field_id)
    if not_found_metadata.size > 0
      not_found_names = []
      sp_metadata_list.each do |name, id|
        if not_found_metadata.include?(id)
          not_found_names << "#{id}: #{name}"
        end
      end
      raise "Configurazione dei metadata errata! I seguenti metadata non sono stati trovati su switch: #{not_found_names.join(', ')}"
    end
    metadata_fields = []
    sp_metadata_list.each do |sw_field, id|
      if job.fields_data[id].present?
        if sp.switch_fields.find_by_field_id(id) && sp.switch_fields.find_by_field_id(id).kind == 'date'
          metadata_fields << { "id" => id, "name" => sw_field, "value" => job.fields_data[id].to_date.to_s }
        else
          metadata_fields << { "id" => id, "name" => sw_field, "value" => job.fields_data[id] }
        end
      end
    end
    SWITCH_LOGGER.info("file_path == #{file_path}")
    file_name = file_path.split('/').last
    SWITCH_LOGGER.info("file_name == #{file_name}")
    job_name = job.to_switch_name(job)
    SWITCH_LOGGER.info("job == #{job_name}")
    multi_part = MultipartPost.new("#{@url}/api/v1/job", token) do
      params_part "flowId", flow_id
      params_part "objectId", object_id
      params_part "jobName", job_name
      params_part "metadata", metadata_fields.to_json
      params_part "file[0][path]", file_name # Path di salvataggio del file sul server di switch
      files_part "file[0][file]", file_name, MimeMagic.by_magic(File.open(file_path)).type, open(file_path).read
    end
    resp = multi_part.run
    SWITCH_LOGGER.info("resp iniziale ==== #{resp.inspect}")
    resp =  JSON.parse(resp)
    SWITCH_LOGGER.info("resp == #{resp.inspect}")
    success = resp['status']
    if success.to_s == 'true'
      # job_id = get_job_list!(token, flow_id, job_name, time)
      # errors = get_job_error_messages!(token, job_id)
      # if errors.size > 0
      #   error_string = errors.map { |e| e[:message] }.joins(' | ')
      #   raise "Invio lavoro riuscito ma ha generato i seguenti messaggi di errore: #{error_string}"
      # else
      #   "Job creato correttamente!"
      # end
      "Invio effettuato correttamente a switch!"
    else
      raise "Errore invio a switch: #{resp['error']}"
    end
  end

  def get_job_list!(token, flow_id, job_name, filter_from)
    resp = @conn.get('api/v1/jobs') do |req|
      req.headers['Authorization'] = "Bearer #{token}"
      req.params['fields'] = 'id'
      req.params['filter'] = {"and":[{"flowId":{"is":"#{flow_id}"}},{"name":{"is":"#{job_name}"}},{"modificationDate":{"is_after":"#{filter_from}"}}]}.to_json
    end
    body = JSON.parse(resp.body)
    success = body['status']
    if success
      job_id = body['data'][0]['id']
    else
      raise "Errore nel recupero dei job: #{body['error']}"
    end
  end

  def get_job_error_messages!(token, job_id)
    resp = @conn.get('api/v1/messages') do |req|
      req.headers['Authorization'] = "Bearer #{token}"
      req.params['job'] = job_id
      req.params['module'] = 'Switch Web Service'
      req.params['type'] = 'error'
    end
    body = JSON.parse(resp.body)
    success = body['status']
    if success
      errors = body['messages']
    else
      raise "Errore nel recupero dei messaggi: #{body['error']}"
    end
  end
end
