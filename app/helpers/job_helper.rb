module JobHelper
  def job_for(form, job, card)
    Job.new(self, form, job, card).html
  end

  class Field
    attr_accessor :default, :dependency, :dependency_condition, :dependency_value, :description, :enum_values, :form, :field_id, :label, :name, :options, :required, :type, :view

    delegate :asset_path, :content_tag, :image_tag, :link_to, :safe_join, to: :view

    def initialize(view, form, job, options = nil)
      @view, @form, @job = view, form, job
      @default ||= options[:default]
      @label ||= options[:label]
      @name ||= options[:name]
      @required ||= options[:required]
      @type ||= options[:type]
      @dependency ||= options[:dependency]
      @dependency_condition ||= options[:dependency_condition]
      @dependency_value ||= options[:dependency_value]
      @field_id ||= options[:field_id]
      @enum_values ||= options[:enum_values]
      @description ||= options[:description]
      @display_field ||= options[:display_field]
    end

    def html
      if @display_field
        case type
        when :hidden then hidden_field_tag
        when :select then select_tag
        when :string then text_field_tag
        when :number then text_field_tag
        when :date then date_field_tag
        when :time then time_field_tag
        when :bool then bool_field_tag
        else
          raise "Don't know how to build #{type} field tag!"
        end
      else
        hidden_field_tag
      end
    end

    private

    def form_group(content)
      if dependency.present?
        tag = content_tag(:div, content, class: :'form-group col-md-4', data: {dependency: dependency, dependencyvalue: dependency_value, dependencycondition: dependency_condition})
      else
        tag = content_tag(:div, content, class: :'form-group col-md-4')
      end

    end

    def bool_field_tag
      if SwitchField.field_dependency(field_id).size > 0
        field_tag = safe_join([
          @form.select(field_id.to_sym, ['SI', 'NO'], { include_blank: I18n::t('strings.Select_one'), selected: default }, class: :'form-control', data: {behaviour: :toggle_fields}, id: field_id)
          ])
      else
        field_tag = safe_join([
          @form.select(field_id.to_sym, ['SI', 'NO'], { include_blank: I18n::t('strings.Select_one'), selected: default }, class: :'form-control', id: field_id)
          ])
      end
      if required && default.blank?
        form_group(safe_join([label_tag, field_tag, error_tag]))
      else
        form_group(safe_join([label_tag, field_tag]))
      end
    end

    def date_field_tag
      field_tag = safe_join([
        @form.date_field(field_id.to_sym, value: default, class: :'form-control', id: field_id)
      ])
      if required && default.blank?
        form_group(safe_join([label_tag, field_tag, error_tag]))
      else
        form_group(safe_join([label_tag, field_tag]))
      end
    end

    def error_tag
      content_tag(:div, 'Non può essere lasciato in bianco', class: :'invalid-feedback d-block')
    end

    def hidden_field_tag
      @form.hidden_field field_id.to_sym, class: :'form-control', value: default, id: field_id
    end

    def label_tag
      @form.label(field_id.to_sym, label, class: :'control-label')
    end

    def select_tag
      if SwitchField.field_dependency(field_id).size > 0
        field_tag = safe_join([
          @form.select(field_id.to_sym, enum_values, { include_blank: I18n::t('strings.Select_one'), selected: default }, class: :'form-control', data: {behaviour: :toggle_fields}, id: field_id)
          ])
      else
        field_tag = safe_join([
          @form.select(field_id.to_sym, enum_values, { include_blank: I18n::t('strings.Select_one'), selected: default }, class: :'form-control', id: field_id)
          ])
      end
      if required && default.blank?
        form_group(safe_join([label_tag, field_tag, error_tag]))
      else
        form_group(safe_join([label_tag, field_tag]))
      end
    end

    def text_field_tag
      if required && default.blank?
        field_tag = safe_join([
          @form.text_field(field_id.to_sym, value: default, class: :'form-control is-invalid', id: field_id)
        ])
      else
        field_tag = safe_join([
          @form.text_field(field_id.to_sym, value: default, class: :'form-control', id: field_id)
        ])
      end
      if required && default.blank?
        form_group(safe_join([label_tag, field_tag, error_tag]))
      else
        form_group(safe_join([label_tag, field_tag]))
      end
    end

    def time_field_tag
      field_tag = safe_join([
        @form.time_field(field_id.to_sym, value: default, class: :'form-control', id: field_id)
      ])
      if required && default.blank?
        form_group(safe_join([label_tag, field_tag, error_tag]))
      else
        form_group(safe_join([label_tag, field_tag]))
      end
    end
  end

  class Job
    attr_accessor :card, :form, :product, :view

    delegate :number_to_percentage, :safe_join, to: :view

    def initialize(view, form, job, card)
      @view, @form, @job, @card = view, form, job, card
      @fields = []
    end

    def fields
      @job.submit_point.switch_fields.where(description: card).each do |parameter|
        if @job.fields_data.present? && @job.fields_data[parameter.field_id].present?
          default_value = @job.fields_data[parameter.field_id]
        elsif parameter.default_value.present?
          default_value = parameter.default_value
        else
          default_value = ''
        end
        @fields << Field.new(@view, @form, @job, {
          default: default_value,
          label: parameter.name,
          name: parameter.name.parameterize.underscore,
          required: parameter.required,
          type: parameter.kind.to_sym,
          dependency: parameter.dependency,
          dependency_condition: parameter.dependency_condition,
          dependency_value: parameter.dependency_value,
          field_id: parameter.field_id,
          enum_values: parameter.enum_values&.split(';'),
          description: parameter.description,
          display_field: parameter.display_field
        })
      end
    end

    def html
      fields
      safe_join(@fields.map(&:html))
    end
  end
end
