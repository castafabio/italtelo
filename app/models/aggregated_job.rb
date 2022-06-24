class AggregatedJob < ApplicationRecord
  scope :brand_new, -> { where(status: 'brand_new') }
  scope :completed, -> { where(status: 'completed') }
  scope :unsend, -> { where(send_at: nil) }

  belongs_to :customer_machine

  has_one_attached :attached_file

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
      raise "I lavori selezionati hanno fasi di lavoro diverse. Verifica e riprova." if line_items.pluck(:need_printing).uniq.size > 1 || line_items.pluck(:need_cutting).uniq.size > 1
      raise "I lavori selezionati hanno macchine assegnate diverse tra loro. Verifica e riprova." if line_items.pluck(:customer_machine_id).uniq.size > 1
      aggregated_job = AggregatedJob.create!(customer_machine_id: line_items.first.customer_machine.id)
      line_items.each do |line_item|
        line_item.attached_file.purge if line_item.attached_file.present?
        line_item.update!(aggregated_job_id: aggregated_job.id)
      end
      aggregated_job.update_customer_machines!
    end
  end

  def editable?
    self.status == 'brand_new'
  end

  def send_to_hotfolder!
    raise "Percorso hotfolder per la macchina #{self.customer_machine} non configurato, chiamare l'assistenza." unless self.customer_machine.hotfolder_path.present?
    hotfolder_path = "#{self.customer_machine.hotfolder_path}"
    FileUtils.mkdir_p(hotfolder_path)
    if self.number_of_files > 1
      Zip::File.open(self.to_file_path) do |zipfile|
        zipfile.each do |file|
          File.delete("#{hotfolder_path}/#{file.name}") if File.exist?("#{hotfolder_path}/#{file.name}")
          zipfile.extract(file, "#{hotfolder_path}/#{file.name}")
        end
      end
    else
      FileUtils.cp self.to_file_path, "#{hotfolder_path}/#{self.to_job_name}"
    end
  end

  def to_job_name
    if self.attached_file.attached?
      job_name = self.attached_file.blob.filename.to_s
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
      text += "#{li.row_number};"
    end
    text
  end

  def update_customer_machines!
    self.update!( customer_machine_id: self.line_items.first.customer_machine.id, need_printing: self.line_items.first.need_printing, need_cutting: self.line_items.first.need_cutting )
  end

  def to_file_path
    ActiveStorage::Blob.service.send(:path_for, self.attached_file.key)
  end

  def to_switch_name(kind)
    code = self.id.to_s.rjust(7, '0')
    "#{code}01AJ.zip"
  end

  def appendable_line_item_list
    line_item_ids = []
    line_item_to_exclude = []
    all_line_items = LineItem.unsend.where(aggregated_job_id: nil)
    all_line_items.each do |line_item|
      ret = []
      ret << (self.line_items.first.need_printing == line_item.need_printing)
      ret << (self.line_items.first.customer_machine_id == line_item.customer_machine.id)
      ret << (self.line_items.first.need_cutting == line_item.need_cutting)
      if ret.uniq.size == 1 && ret == true
        line_item_ids << line_item
      end
      if ret.uniq.size > 1
        line_item_to_exclude << line_item
      end
      all_line_items = all_line_items.where.not(id: line_item_to_exclude)
    end
    all_line_items.each do |line_item|
      line_item_ids << line_item if (self.customer_machine_id == line_item&.customer_machine&.id)
    end
    LineItem.where(id: line_item_ids)
  end

  def add_line_items!(line_item_list)
    need_print = self.line_items.pluck(:need_printing)
    need_cut = self.line_items.pluck(:need_cutting)
    customer_machine = self.line_items.pluck(:customer_machine_id)
    line_items = LineItem.where(id: line_item_list)
    line_items.each do |line_item|
      need_cut << line_item.need_cutting
      raise "I lavori selezionati hanno lavorazioni diverse. Verifica e riprova." if need_cut.uniq.size > 1
      need_print << line_item.need_printing
      raise "I lavori selezionati hanno lavorazioni diverse. Verifica e riprova." if need_print.uniq.size > 1
      customer_machine << line_item.customer_machine_id
      raise "I lavori selezionati hanno macchine fisiche diverse. Verifica e riprova." if customer_machine.uniq.size > 1
      line_item.attached_file.purge if line_item.attached_file.attached?
      line_item.update_column(:aggregated_job_id, self.id)
    end
  end

  def compiled?
    self.fields_data.present?
  end

  def has_files?
    self.line_items.each do |li|
      if li.attached_file.attached?
        return true
      else
        return false
      end
    end
  end

  def to_s
    code
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
