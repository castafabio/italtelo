class LineItem < ApplicationRecord
  belongs_to :order
  belongs_to :print_customer_machine, class_name: 'CustomerMachine', optional: true
  belongs_to :cut_customer_machine, class_name: 'CustomerMachine', optional: true
  belongs_to :vg7_print_machine, class_name: 'Vg7Machine', optional: true
  belongs_to :vg7_cut_machine, class_name: 'Vg7Machine', optional: true
  belongs_to :aggregated_job, optional: true
  belongs_to :submit_point, optional: true

  has_one_attached :print_file
  has_one_attached :cut_file

  after_commit :send_to_switch, on: :update

  attr_accessor :send_now

  validates :row_number, presence: true
  validates :article_code, presence: true
  validates :article_name, presence: true
  validates :scale, inclusion: { in: LINE_ITEM_SCALE }
  validates :sides, inclusion: { in: LINE_ITEM_SIDES }

  validate :fields_data_required

  def self.aggregable
    line_item_ids = []
    LineItem.where(aggregated_job_id: nil).each do |line_item|
      if line_item.print_customer_machine.present? || line_item.cut_customer_machine.present?
        line_item_ids << line_item.id
      end
    end
    LineItem.where(id: line_item_ids)
  end

  def get_machines(kind)
    if kind == 'print'
      self.print_customer_machine.to_vg7_machine_id(self.vg7_print_machine) if self.print_customer_machine.present?
    elsif kind == 'cut'
      self.cut_customer_machine.to_vg7_machine_id(self.vg7_cut_machine) if self.cut_customer_machine.present?
    end
  end

  def to_customer_machine(kind)
    text = ""
    if kind == 'print'
      if self.vg7_print_machine.present?
        text += "#{self.print_customer_machine.name} - #{self.vg7_print_machine.description}"
      end
    else
      if self.vg7_cut_machine.present?
        text += "#{self.cut_customer_machine.name} - #{self.vg7_cut_machine.description}"
      end
    end
    text
  end

  def has_errors?
    return false if self.error_message == nil
  end

  def toggle_is_active!(linked_resource = nil)
    if self.aluan == false
      self.update!(aluan: true)
    else
      self.update!(aluan: false)
    end
  end

  def editable?
    (self.aggregated_job.nil? && self.switch_sent.nil? && !self.sending)
  end

  def to_description(filter)
    text = ''
    initial_machine = self.description.split("macchina: ").last.split(";").first
    if self.need_printing && self.vg7_print_machine.present?
      if initial_machine != self.vg7_print_machine.description
        text += "Macchina impostata: #{self.vg7_print_machine.description}\r\n"
      end
    end
    if self.need_cutting && self.vg7_cut_machine.present?
      text += "Macchina impostata: #{self.vg7_print_machine.description}\r\n"
      if initial_machine != self.vg7_cut_machine.description
      end
    end
    text += self.description
    if self.submit_point.present? && !filter
      SwitchField.descriptions(self.submit_point).each do |description|
        text += "- #{description.split('_').last}\r\n"
        self.submit_point.switch_fields.where(description: description, display_field: true).each do |sf|
          if self&.fields_data[sf&.field_id]&.present?
            text += "#{sf.name}: #{self.fields_data[sf.field_id]}\r\n"
          end
        end
      end
    end
    text
  end

  def send_to_switch
    if self.switch_sent.nil? && self.send_now
      SendToSwitch.perform_later(self.id, 'line_item')
    end
  end

  def to_file_path(kind)
    if kind == 'print'
      ActiveStorage::Blob.service.send(:path_for, self.print_file.key)
    else
      ActiveStorage::Blob.service.send(:path_for, self.cut_file.key)
    end
  end

  def to_switch_name(kind)
    code = self.id.to_s.rjust(7, '0')
    "#{code}01LI.zip"
  end

  def appendable_aggregate_line_item_list
    aggregated_line_item_ids = []
    all_aggregated_jobs = AggregatedJob.where('deadline >= :today AND deadline <= :deadline', today: Date.today, deadline: self.order.order_date)
    if self.has_files?
      all_aggregated_jobs.brand_new.each do |aj|
        if aj.has_files?
          aggregated_line_item_ids << aj.id if (self.need_printing && aj.line_items.first.need_printing || self.need_cutting && aj.line_items.first.need_cutting) && (self&.print_customer_machine&.id == aj.print_customer_machine_id || self&.vg7_print_machine_id == aj.vg7_print_machine_id || self&.cut_customer_machine&.id == aj.cut_customer_machine_id)
        end
      end
    else
      all_aggregated_jobs.brand_new.each do |aj|
        unless aj.has_files?
          aggregated_line_item_ids << aj.id if (self.need_printing && aj.line_items.first.need_printing || self.need_cutting && aj.line_items.first.need_cutting) && (self&.print_customer_machine&.id == aj.print_customer_machine_id || self&.vg7_print_machine_id == aj.vg7_print_machine_id || self&.cut_customer_machine&.id == aj.cut_customer_machine_id)
        end
      end
    end
    AggregatedJob.where(id: aggregated_line_item_ids)
  end

  def aggregate!(aj_id, new_aj)
    if new_aj
      AggregatedJob.aggregate!(LineItem.where(id: self.id))
    else
      AggregatedJob.find(aj_id).add_line_items!([self.id])
    end
  end

  def deaggregate!
    ActiveRecord::Base.transaction do
      aggregated_job = self.aggregated_job
      self.update_column(:aggregated_job_id, nil)
      aggregated_job.reload
      aggregated_job.destroy! if aggregated_job.line_items.size == 0
    end
  end

  def li_print_file_attached?
    ret = true
    if self.need_printing
      if self.print_file.attached? && !self.print_customer_machine.nil?
        ret = true
      else
        ret = false
      end
    end
    ret
  end

  def li_cut_file_attached?
    ret = true
    if self.need_cutting
      if self.cut_file.attached? && !self.cut_customer_machine.nil?
        ret = true
      else
        ret = false
      end
    end
    ret
  end

  def has_files?
    if self.print_file.attached? || self.cut_file.attached?
      return true
    else
      return false
    end
  end

  def is_aggregated?
    !self.aggregated_job_id.nil?
  end

  def to_s
    "#{self.order.order_code} - #{self.row_number}"
  end

  def fields_data_required
    if self.send_now
      if self.persisted?
        field_errors = []
        if self.submit_point.present?
          SwitchField.where(submit_point_id: self.submit_point_id, required: true).each do |field|
            if field.dependency.present?
              # Dipende da un altro campo, verifico se la dipendenza ha un valore
              unless self.fields_data[self.submit_point.switch_fields.find_by(name: 'Macchina').field_id]
                if self.fields_data[field.dependency].present?
                  condition_ok = false
                  case field.dependency_condition
                  when 'Not-equals'
                    condition_ok = true if self.fields_data[field.dependency] != field.dependency_value
                  when 'Equals'
                    condition_ok = true if self.fields_data[field.dependency] == field.dependency_value
                  when 'Contains'
                    condition_ok = true if self.fields_data[field.dependency].include?(field.dependency_value)
                  when 'Does not contain'
                    condition_ok = true unless self.fields_data[field.dependency].include?(field.dependency_value)
                  when 'Starts with'
                    condition_ok = true if self.fields_data[field.dependency].start_with?(field.dependency_value)
                  when 'Does not start with'
                    condition_ok = true unless self.fields_data[field.dependency].start_with?(field.dependency_value)
                  end
                  field_errors << field.name if condition_ok && !self.fields_data[field.field_id].present?
                end
              end
            else
              field_errors << field.name unless self.fields_data[field.field_id].present?
            end
          end
          self.errors.add(:fields_data, "Non possono essere lasciati in bianco i seguenti campi: #{field_errors.join(', ')}") if field_errors.size > 0
        else
          self.errors.add(:fields_data, "Non è presente alcun flusso switch" )
        end
      end
    end
  end
end
