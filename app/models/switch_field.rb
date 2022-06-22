class SwitchField < ApplicationRecord
  default_scope { order(sort: :asc) }
  scope :field_dependency, -> (field_id) { where('dependency = ?', field_id) }

  belongs_to :submit_point

  def self.descriptions(submit_point)
    if submit_point.present?
      submit_point.switch_fields.where(display_field: true).pluck(:description).uniq.sort
    end
  end

  def self.sync!
    switch_api = SwitchApi.new
    old_token = Customization.switch_token
    token = switch_api.ping!(old_token) if old_token.present?
    token = switch_api.login! if token.nil?
    SubmitPoint.all.each do |sp|
      submit_point = switch_api.get_submit_point_by_name!(token, sp.name)
      # Controllo se è stato eliminato qualche campo
      sf_to_delete = sp.switch_fields.pluck(:field_id) - submit_point['metadata'].map {|m| m['id']}
      sp.switch_fields.where(field_id: sf_to_delete).delete_all if sf_to_delete.size > 0
      submit_point['metadata'].each_with_index do |h, index|
        sf = sp.switch_fields.where(field_id: h['id']).first
        if h['type'].include?('enum')
          enum_values = h['type'].gsub('enum:', '')
          type = 'select'
        else
          type = h['type']
        end
        # sort = h['id'].split('_').last.to_i
        if sf
          sf.update!(submit_point: sp, dependency: h['dependency'], dependency_condition: h['dependencyCondition'], dependency_value: h['dependencyValue'], display_field: h['displayField'], field_id: h['id'], kind: type, enum_values: enum_values, required: h['valueIsRequired'], name: h['name'], read_only: h['readOnly'], description: h['description'], default_value: h['value'])
        else
          SwitchField.create!(submit_point: sp, dependency: h['dependency'], dependency_condition: h['dependencyCondition'], dependency_value: h['dependencyValue'], display_field: h['displayField'], field_id: h['id'], kind: type, enum_values: enum_values, required: h['valueIsRequired'], name: h['name'], read_only: h['readOnly'], description: h['description'], default_value: h['value'], sort: index)
        end
      end
    end
    switch_api.logout!(token)
  end

  def sort!(position)
    position = position.to_i
    SwitchField.transaction do
      ids = self.submit_point.switch_fields.ids
      if self.sort > position
        # Sto spostando indietro
        forward_ids = ids[(position)..(self.sort - 1)]
        SwitchField.where(id: forward_ids).update_all("sort = sort + 1")
      else
        # Sposto avanti
        back_ids = ids[(self.sort + 1)..(position)]
        SwitchField.where(id: back_ids).update_all("sort = sort - 1")
      end
      self.update!(sort: position)
    end
  end

  def to_s
    "#{self.name.parameterize.underscore}"
  end
end
