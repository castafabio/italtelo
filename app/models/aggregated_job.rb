class AggregatedJob < ApplicationRecord
  scope :brand_new, -> { where(status: 'brand_new') }
  scope :completed, -> { where(status: 'completed') }

  belongs_to :submit_point, optional: true
  belongs_to :print_customer_machine, class_name: 'CustomerMachine', optional: true
  belongs_to :cut_customer_machine, class_name: 'CustomerMachine', optional: true

  has_one_attached :print_file
  has_one_attached :cut_file

  has_many :line_items, dependent: :nullify
  has_many :orders, -> { distinct }, through: :line_items
  has_many :printers, as: :resource, dependent: :destroy
  has_many :cutters, as: :resource, dependent: :destroy

  before_validation :set_code, on: :create

  attr_accessor :appendable_line_items, :send_now

  validates :deadline, presence: true
  validates :status, inclusion: { in: AGGREGATED_JOB_STATUSES }
  validate :fields_data_required

  def self.aggregate!(line_items)
    ActiveRecord::Base.transaction do
      # verifico se le righe hanno o meno dei file
      file_present = []
      deadline = nil
      line_items.each do |line_item|
        if line_item.need_printing && line_item.print_file.attached?
          file_present << 0
        else
          file_present << 1
        end
        if line_item.need_cutting && line_item.cut_file.attached?
          file_present << 0
        else
          file_present << 1
        end
        deadline = line_item.order.order_date
      end
      raise "Nessun lavoro selezionato. Selezionare almeno un lavoro e riprovare." if line_items.size == 0
      raise "E' presente almeno un lavoro che è già stato aggregato. Verifica e riprova." if line_items.where.not(aggregated_job_id: nil).size > 0
      raise "I lavori selezionati hanno clienti diversi. Verifica e riprova." if line_items.map { |li| li.order.customer}.uniq.size > 1
      raise "I lavori selezionati sono di ordini diversi. Verifica e riprova." if line_items.map { |li| li.order.order_code}.uniq.size > 1
      raise "I lavori selezionati hanno materiali diversi. Verifica e riprova." if line_items.pluck(:material).uniq.size > 1
      raise "I lavori selezionati hanno scala diversa. Verifica e riprova." if line_items.pluck(:scale).uniq.size > 1
      raise "Devono essere presenti i file. Verifica e riprova." if file_present.uniq.size > 1
      raise "I lavori selezionati hanno fasi di lavoro diverse. Verifica e riprova." if line_items.pluck(:need_printing).uniq.size > 1 || line_items.pluck(:need_cutting).uniq.size > 1
      raise "Il lavoro richiede la stampa, selezionare almeno una macchina da stampa. Verifica e riprova." if line_items.pluck(:need_printing).include?(true) && line_items.pluck(:print_customer_machine_id).include?(nil)
      aggregated_job = AggregatedJob.create!(deadline: deadline, print_customer_machine_id: line_items.first.print_customer_machine.id, cut_customer_machine_id: line_items&.first&.cut_customer_machine_id&.id)
      line_items.each do |line_item|
        line_item.update!(aggregated_job_id: aggregated_job.id)
      end
      aggregated_job.update_customer_machines!
      if (!aggregated_job.can_upload_cut_files? && !aggregated_job.can_upload_print_files?)
        aggregated_job.update!(tilia: true)
      end
    end
  end

  def update_line_items_machines!(kind, customer_machine_id)
    self.line_items.each do |line_item|
      if kind == 'print'
        line_item.update!(print_customer_machine_id: customer_machine_id)
      else
        line_item.update!(cut_customer_machine_id: customer_machine_id)
      end
    end
  end

  def to_customer_machine(kind)
    text = ""
    if kind == 'print'
      text += "#{self.print_customer_machine.name}"
    else
      text += "#{self.cut_customer_machine.name}"
    end
    text
  end

  def has_errors?
    ret = false
    self.line_items.each do |line_item|
      ret = false if line_item.has_errors?
    end
    ret
  end

  def metadata_id_nesting
    text = ""
    self.line_items.each do |li|
      text += "#{li.row_number};"
    end
    text
  end

  def update_customer_machines!
    self.update!( print_customer_machine_id: self.line_items.first.print_customer_machine_id, cut_customer_machine_id: self.line_items.first.cut_customer_machine_id, need_printing: self.line_items.first.print_customer_machine_id.present?, need_cutting: self.line_items.first.cut_customer_machine_id.present? )
  end

  def aj_print_file_attached?
    ret = true
    if self.need_printing
      if self.print_file.attached?
        ret = true
      else
        ret = false
      end
    end
    ret
  end

  def aj_cut_file_attached?
    ret = true
    if self.need_cutting
      if self.cut_file.attached?
        ret = true
      else
        ret = false
      end
    end
    ret
  end

  def print_file_uploaded?
    self.can_upload_print_files? && self.print_file.present? && self.print_file.attached?
  end

  def cut_file_uploaded?
    self.can_upload_cut_files? && self.cut_file.present? && self.cut_file.attached?
  end

  def can_upload_print_files?
    # Il controllo sul fatto che possa aggregare solo righe tutte con o senza file lo faccio prima
    self.need_printing && !self.line_items.first.print_file.attached?
  end

  def can_upload_cut_files?
    self.need_cutting && !self.line_items.first.cut_file.attached?
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
    "#{code}01AJ.zip"
  end

  def appendable_line_item_list
    line_item_ids = []
    line_item_to_exclude = []
    all_line_items = LineItem.joins(:order).where('orders.order_date >= :deadline', deadline: self.deadline).where(aggregated_job_id: nil)
    all_line_items.each do |line_item|
      ret = []
      ret << (self.line_items.first.order.customer == line_item.order.customer)
      ret << (self.line_items.first.order.order_code == line_item.order.order_code)
      ret << (self.line_items.first.material == line_item.material)
      ret << (self.line_items.first.scale == line_item.scale)
      ret << (self.line_items.first.need_printing == line_item.need_printing)
      ret << (self.line_items.first.print_customer_machine_id == line_item.print_customer_machine_id)
      ret << (self.line_items.first.need_cutting == line_item.need_cutting)
      ret << (self.line_items.first.cut_number_of_files > 0 == line_item.cut_number_of_files > 0)
      if ret.uniq.size == 1 && ret == true
        line_item_ids << line_item
      end
      if ret.uniq.size > 1
        line_item_to_exclude << line_item
      end
      all_line_items = all_line_items.where.not(id: line_item_to_exclude)
    end
    if self.has_files?
      all_line_items.each do |line_item|
        if line_item.has_files?
          line_item_ids << line_item if (self.print_customer_machine_id == line_item&.print_customer_machine&.id)
        end
      end
    else
      all_line_items.each do |line_item|
        unless line_item.has_files?
          line_item_ids << line_item if (self.print_customer_machine_id == line_item&.print_customer_machine&.id)
        end
      end
    end
    LineItem.where(id: line_item_ids)
  end

  def add_line_items!(line_item_list)
    customer = self.line_items.map { |li| li.order.customer }
    order_code = self.line_items.map { |li| li.order.order_code }
    material = self.line_items.pluck(:material)
    scale = self.line_items.pluck(:scale)
    need_print = self.line_items.pluck(:need_printing)
    need_cut = self.line_items.pluck(:need_cutting)
    cut_number_of_files = self.line_items.pluck(:cut_number_of_files)
    print_machine = self.line_items.pluck(:print_customer_machine_id)
    cut_machine = self.line_items.pluck(:cut_customer_machine_id)
    line_items = LineItem.where(id: line_item_list)
    line_items.each do |line_item|
      customer << line_item.order.customer
      raise "I lavori selezionati hanno clienti diversi. Verifica e riprova." if customer.uniq.size > 1
      order_code << line_item.order.order_code
      raise "I lavori selezionati sono di ordini diversi. Verifica e riprova." if order_code.uniq.size > 1
      material << line_item.material
      raise "I lavori selezionati hanno materiali diversi. Verifica e riprova." if material.uniq.size > 1
      scale << line_item.scale
      raise "I lavori selezionati hanno scala diversa. Verifica e riprova." if scale.uniq.size > 1
      need_cut << line_item.need_cutting
      raise "I lavori selezionati hanno lavorazioni diverse. Verifica e riprova." if need_cut.uniq.size > 1
      need_print << line_item.need_printing
      raise "I lavori selezionati hanno lavorazioni diverse. Verifica e riprova." if need_print.uniq.size > 1
      cut_number_of_files << line_item.cut_number_of_files
      raise "I lavori selezionati devono avere almeno un file di taglio caricato. Verifica e riprova." if cut_number_of_files.uniq.size > 1
      print_machine << line_item.print_customer_machine_id
      raise "I lavori selezionati hanno macchine fisiche diverse. Verifica e riprova." if print_machine.uniq.size > 1
      line_item.update_column(:aggregated_job_id, self.id)
    end
  end

  def compiled?
    self.fields_data.present?
  end

  def has_files?
    self.line_items.each do |li|
      if li.print_file.attached? || li.cut_file.attached?
        return true
      else
        return false
      end
    end
  end

  def to_s
    code
  end

  def fields_data_required
    if self.send_now
      if self.persisted?
        field_errors = []
        if self.submit_point.present?
          SwitchField.where(submit_point_id: self.submit_point_id, required: true).each do |field|
            if field.dependency.present?
              # Dipende da un altro campo, verifico se la dipendenza ha un valore
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

  private

  def set_code
    if self.code.blank?
      year = Date.today.year.to_s[2..3]
      if AggregatedJob.all.size > 0 && AggregatedJob.last.created_at.year == Date.today.year
        counter = AggregatedJob.last.code.split('-').first.to_i + 1
      else
        counter = 1
      end
      self.code = "#{counter}-#{year}"
    end
  end
end
