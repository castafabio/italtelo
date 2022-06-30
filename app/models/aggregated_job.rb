class AggregatedJob < ApplicationRecord
  scope :brand_new, -> { where(status: 'brand_new') }
  scope :completed, -> { where(status: 'completed') }
  scope :unsend, -> { where(send_at: nil) }

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

  validates :status, inclusion: { in: AGGREGATED_JOB_STATUSES }

  def self.aggregate!(line_items)
    ActiveRecord::Base.transaction do
      # verifico se le righe hanno o meno dei file
      raise "Nessun lavoro selezionato. Selezionare almeno un lavoro e riprovare." if line_items.size == 0
      raise "E' presente almeno un lavoro che è già stato aggregato. Verifica e riprova." if line_items.where.not(aggregated_job_id: nil).size > 0
      raise "I lavori selezionati hanno fasi di lavoro diverse. Verifica e riprova." if !line_items.need_printing(line_items.ids) || !line_items.need_cutting(line_items.ids)
      raise "I lavori selezionati hanno macchine assegnate diverse tra loro. Verifica e riprova." if line_items.pluck(:print_customer_machine_id).uniq.size > 1 || line_items.pluck(:cut_customer_machine_id).uniq.size > 1
      raise "I lavori selezionati fanno parte di ordini differenti tra loro. Verifica e riprova." if line_items.pluck(:order_code).uniq.size > 1
      aggregated_job = AggregatedJob.create!(print_customer_machine_id: line_items.first&.print_customer_machine&.id, cut_customer_machine_id: line_items.first&.cut_customer_machine&.id)
      line_items.each do |line_item|
        line_item.print_file.purge if line_item.print_file.present?
        line_item.cut_file.purge if line_item.cut_file.present?
        line_item.update!(aggregated_job_id: aggregated_job.id)
      end
      aggregated_job.update_customer_machines!
    end
  end

  def editable?
    self.status == 'brand_new' && self.send_at.nil?
  end

  def send_to_hotfolder!
    if self.need_printing
      raise "Percorso hotfolder per la macchina #{self.print_customer_machine} non configurato, chiamare l'assistenza." unless self.print_customer_machine.hotfolder_path.present?
      print_path = "#{self.print_customer_machine.hotfolder_path}"
    end
    if self.need_cutting
      raise "Percorso hotfolder per la macchina #{self.cut_customer_machine} non configurato, chiamare l'assistenza." unless self.cut_customer_machine.hotfolder_path.present?
      cut_path = "#{self.cut_customer_machine.hotfolder_path}"
    end
    if self.need_printing && self.print_file.attached?
      FileUtils.mkdir_p(print_path)
      if self.print_number_of_files > 1
        Zip::File.open(self.to_file_path('print')) do |zipfile|
          zipfile.each do |file|
            File.delete("#{print_path}/#{file.name}") if File.exist?("#{print_path}/#{file.name}")
            zipfile.extract(file, "#{print_path}/#{file.name}")
          end
        end
      else
        FileUtils.cp self.to_file_path('print'), "#{print_path}/#{self.to_job_name('print')}"
      end
    end
    if self.need_cutting && self.cut_file.attached?
      FileUtils.mkdir_p(cut_path)
      if self.cut_number_of_files > 1
        Zip::File.open(self.to_file_path('cut')) do |zipfile|
          zipfile.each do |file|
            File.delete("#{cut_path}/#{file.name}") if File.exist?("#{cut_path}/#{file.name}")
            zipfile.extract(file, "#{cut_path}/#{file.name}")
          end
        end
      else
        FileUtils.cp self.to_file_path('cut'), "#{print_path}/#{self.to_job_name('cut')}"
      end
    end
  end

  def to_job_name(kind)
    case kind
    when 'print'
      if self.print_file.attached?
        job_name = self.print_file.blob.filename.to_s
      end
    when 'cut'
      if self.cut_file.attached?
        job_name = self.cut_file.blob.filename.to_s
      end
    else
      job_name = "#{self.id}#AJ_dummy.pdf"
    end
    job_name
  end

  def to_customer_machine
    text = "#{self.customer_machine.name}"
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
      text += "#{li.to_s};"
    end
    text
  end

  def update_customer_machines!
    self.update!( print_customer_machine_id: self.line_items.first&.print_customer_machine&.id, cut_customer_machine_id: self.line_items.first&.cut_customer_machine&.id, need_printing: self.line_items.first.need_printing, need_cutting: self.line_items.first.need_cutting )
  end

  def to_file_path(kind)
    if kind == 'print'
      if self.print_file.attached?
        ActiveStorage::Blob.service.send(:path_for, self.print_file.key)
      end
    else
      if self.cut_file.attached?
        ActiveStorage::Blob.service.send(:path_for, self.cut_file.key)
      end
    end
  end

  def to_switch_name(kind)
    code = self.id.to_s.rjust(7, '0')
    "#{code}01AJ.zip"
  end

  def appendable_line_item_list
    line_item_ids = []
    line_item_to_exclude = []
    all_line_items = LineItem.unsend.where(aggregated_job_id: nil, order_code: self.line_items.first.order_code)
    all_line_items.each do |line_item|
      ret = []
      ret << (self.line_items.first.need_printing == line_item.need_printing)
      ret << (self.line_items.first.print_customer_machine_id == line_item&.print_customer_machine&.id)
      ret << (self.line_items.first.need_cutting == line_item.need_cutting)
      ret << (self.line_items.first.cut_customer_machine_id == line_item&.cut_customer_machine&.id)
      ret << (self.line_items.first.order_code == line_item.order_code)
      if ret.uniq.size == 1 && ret == true
        line_item_ids << line_item
      end
      if ret.uniq.size > 1
        line_item_to_exclude << line_item
      end
      all_line_items = all_line_items.where.not(id: line_item_to_exclude)
    end
    all_line_items.each do |line_item|
      if self.need_printing
        line_item_ids << line_item if (self.print_customer_machine_id == line_item&.print_customer_machine&.id)
      end
      if self.need_cutting
        line_item_ids << line_item if (self.cut_customer_machine_id == line_item&.cut_customer_machine&.id)
      end
    end
    LineItem.where(id: line_item_ids)
  end

  def add_line_items!(line_item_list)
    print_machine = self.line_items.pluck(:print_customer_machine_id)
    cut_machine = self.line_items.pluck(:cut_customer_machine_id)
    order_code = self.line_items.pluck(:order_code)
    line_items = LineItem.where(id: line_item_list)
    line_items.each do |line_item|
      raise "I lavori selezionati hanno lavorazioni diverse. Verifica e riprova." if !self.line_items.need_printing(self.line_items)
      raise "I lavori selezionati hanno lavorazioni diverse. Verifica e riprova." if !self.line_items.need_cutting(self.line_items)
      if self.need_printing
        print_machine << line_item.print_customer_machine_id
        raise "I lavori selezionati hanno macchine da stampa diverse. Verifica e riprova." if print_machine.uniq.size > 1
      end
      if self.need_cutting
        cut_machine << line_item.cut_customer_machine_id
        raise "I lavori selezionati hanno macchine da taglio diverse. Verifica e riprova." if cut_machine.uniq.size > 1
      end
      order_code << line_item.order_code
      raise "I lavori selezionati fanno parte di ordini differenti tra loro. Verifica e riprova." if order_code.uniq.size > 1
      line_item.print_file.purge if line_item.print_file.attached?
      line_item.cut_file.purge if line_item.cut_file.attached?
      line_item.update_column(:aggregated_job_id, self.id)
    end
  end

  def to_s
    code
  end

  def calculate_ink_total
    result = {}
    self.printers.where.not(ink: nil).pluck(:ink).each do |inks|
      inks.split(';').each do |color|
        key, value = color.split(':')
        next if key.blank?
        key = key.downcase.strip
        if result[key].present?
          result[key] = result[key] + value.to_f
        else
          result[key] = value.to_f
        end
      end
    end
    result
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
