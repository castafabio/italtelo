class SendToSwitch < ApplicationJob
  require 'zip'
  require 'nokogiri'

  queue_as :italtelo
  sidekiq_options retry: 0, backtrace: 10

  def create_xml!(resource, filename, dest_path)
    no_ext = File.basename(filename.to_s, File.extname(filename))
    builder = Nokogiri::XML::Builder.new do |xml|
      if resource.is_a?(AggregatedJob)
        xml.send(:'quantità', 1)
      else
        xml.send(:'quantità', resource.quantity)
      end
    end
    full_path = "#{dest_path}/#{no_ext}.xml"
    File.write(full_path, builder.to_xml)
  end

  def unzip_and_xml(dest_path, resource, original_zip_file)
    index = 0
    Zip::File.open(original_zip_file) do |zip_file|
      zip_file.each do |f|
        f_path = File.join(dest_path, f.name)
        create_xml!(resource, f.name, dest_path)
        zip_file.extract(f, f_path){ true }
        index += 1
      end
    end
    index
  end

  def handle_resource(resource, tmpdir, index)
    if resource.need_printing
      dest_path = "#{tmpdir}/Stampa"
      Dir.mkdir(dest_path) unless File.directory?(dest_path)
      index += unzip_and_xml(dest_path, resource, resource.to_file_path('print'))
    elsif resource.need_cutting
      dest_path = "#{tmpdir}/Taglio"
      Dir.mkdir(dest_path) unless File.directory?(dest_path)
      index += unzip_and_xml(dest_path, resource, resource.to_file_path('cut'))
    end
    index
  end


  def perform(id, kind)
    resource = kind.camelize.constantize.find_by(id: id)
    begin
      # Cartella per estrazione file
      tmpdir = Dir.mktmpdir
      zip_tmpdir = Dir.mktmpdir
      index = 0
      code = resource.id.to_s.rjust(7, '0')
      if kind == 'aggregated_job'
        if resource.tilia
          # Prendo i file dalle line_item
          resource.line_items.each do |line_item|
            index += handle_resource(line_item, tmpdir, index)
          end
        else
          # Quando non uso Tilia, devono caricare sia file di taglio che file di stampa
          if resource.need_printing
            dest_path = "#{tmpdir}/Stampa"
            Dir.mkdir(dest_path) unless File.directory?(dest_path)
            index += unzip_and_xml(dest_path, resource, resource.to_file_path('print'))
          end
          if resource.need_cutting
            dest_path = "#{tmpdir}/Taglio"
            Dir.mkdir(dest_path) unless File.directory?(dest_path)
            index += unzip_and_xml(dest_path, resource, resource.to_file_path('cut'))
          end
        end
        filename = "#{zip_tmpdir}/#{code}01AJ#{index}.zip"
      else
        # Riga singola, posso avere solo file di stampa o solo file di taglio. Nel caso serva taglio e stampa caricheranno un file di stampa con sopra il tracciato di taglio.
        index += handle_resource(resource, tmpdir, index)
        filename = "#{zip_tmpdir}/#{code}01LI#{index}.zip"
      end
      zf = ZipFileGenerator.new(tmpdir, filename)
      zf.write()
      switch_api = SwitchApi.new
      old_token = Customization.switch_token
      token = switch_api.ping!(old_token) if old_token.present?
      token = switch_api.login! if token.nil?
      submit_point = switch_api.get_submit_point_by_name!(token, resource.submit_point.name)
      switch_api.post_job!(token, submit_point, filename, resource)
      now = Time.now
      update_errors(resource, 'ok')
      resource.update!(switch_sent: now)
      if kind == 'aggregated_job'
        resource.line_items.update_all(switch_sent: now)
        resource.update(status: 'completed')
      end
    rescue Exception => e
      update_errors(resource, 'error', e)
    ensure
      resource.update!(sending: false)
      if kind == 'aggregated_job'
        resource.line_items.update_all(sending: false)
      end
    end
  end

  def update_errors(resource, error, e = nil)
    if resource.has_errors?
      if error == 'ok'
        if resource.is_a?(AggregatedJob)
          resource.line_items.update_all(error_message: nil)
          resource.update(error_message: nil)
        else
          resource.update(error_message: nil)
        end
      else
        if resource.is_a?(AggregatedJob)
          resource.line_items.each do |line_item|
            line_item.update(error_message: "Il lavoro #{line_item} non è andato a buon fine: #{e.message}")
          end
          resource.update(error_message: "Il lavoro #{line_item} non è andato a buon fine: #{e.message}")
        else
          resource.update(error_message: "Il lavoro #{resource} non è andato a buon fine: #{e.message}")
        end
      end
    else
      if error == 'ok'
        if resource.is_a?(AggregatedJob)
          resource.line_items.update_all(error_message: nil)
          resource.update(error_message: nil)
        else
          resource.update(error_message: nil)
        end
      else
        if resource.is_a?(AggregatedJob)
          resource.line_items.each do |line_item|
            line_item.update(error_message: "Il lavoro #{line_item} non è andato a buon fine: #{e.message}")
          end
        else
          resource.update(error_message: "Il lavoro #{resource} non è andato a buon fine: #{e.message}")
        end
      end
    end
  end
end
