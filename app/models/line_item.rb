class LineItem < ApplicationRecord
  scope :unsend, -> { where(send_at: nil) }

  # belongs_to :customer_machine, optional: true
  belongs_to :print_customer_machine, class_name: 'CustomerMachine', optional: true
  belongs_to :cut_customer_machine, class_name: 'CustomerMachine', optional: true
  belongs_to :old_print_customer_machine, class_name: 'CustomerMachine', optional: true
  belongs_to :old_cut_customer_machine, class_name: 'CustomerMachine', optional: true
  belongs_to :aggregated_job, optional: true
  belongs_to :italtelo_user, optional: true

  has_many :printers, as: :resource, dependent: :destroy
  has_many :cutters, as: :resource, dependent: :destroy

  has_one_attached :print_file
  has_one_attached :cut_file

  attr_accessor :send_now

  validates :article_code, presence: true
  validates :article_description, presence: true

  def self.aggregable
    LineItem.where(aggregated_job_id: nil).where("line_items.print_customer_machine_id IS NOT NULL OR line_items.cut_customer_machine_id IS NOT NULL")
  end

  def self.need_printing(line_items)
    line_items = LineItem.where(id: line_items)
    ret = []
    line_items.each do |line_item|
      ret << line_item.need_printing
    end
    if ret.uniq.size == 1
      ret = true
    else
      ret = false
    end
    ret
  end

  def self.need_cutting(line_items)
    line_items = LineItem.where(id: line_items)
    ret = []
    line_items.each do |line_item|
      ret << line_item.need_cutting
    end
    if ret.uniq.size == 1
      ret = true
    else
      ret = false
    end
    ret
  end

  def is_efkal?
    self.cut_customer_machine.import_job == "efkal"
  end

  def update_old_customer_machine!(kind)
    if kind == 'print'
      if self.print_customer_machine.present?
        self.update!(old_print_customer_machine_id: self.print_customer_machine.id) if self.old_print_customer_machine_id.nil?
      end
    else
      if self.cut_customer_machine.present?
        self.update!(old_cut_customer_machine_id: self.cut_customer_machine.id) if self.old_cut_customer_machine_id.nil?
      end
    end
  end

  def send_to_hotfolder!
    if !self.is_efkal?
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
          FileUtils.cp self.to_file_path('cut'), "#{cut_path}/#{self.to_job_name('cut')}"
        end
      end
    end
  end

  def has_customer_machine?
    ret = []
    if self.need_printing
      ret << self.need_printing && self.print_customer_machine.present?
    end
    if self.need_cutting
      ret << self.need_cutting && self.cut_customer_machine.present?
    end
    if ret.uniq.size == 1
      ret = true
    else
      ret = false
    end
    ret
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

  def has_errors?
    return false if self.error_message == nil
  end

  def editable?
    self.aggregated_job.nil?
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
    "#{code}01LI.zip"
  end

  def appendable_aggregate_line_item_list
    aggregated_line_item_ids = []
    all_aggregated_jobs = AggregatedJob.unsend.brand_new.joins(:line_items).where("line_items.order_code LIKE :order_code", order_code: self.order_code)
    all_aggregated_jobs.each do |aj|
      ret = []
      if self.need_printing
        ret << (self.need_printing && aj.need_printing && (self&.print_customer_machine&.id == aj.print_customer_machine_id))
      end
      if self.need_cutting
        ret << (self.need_cutting && aj.need_cutting && (self&.cut_customer_machine&.id == aj.cut_customer_machine_id))
      end
      ret << (self.order_code == aj.line_items.first.order_code)
      if ret.uniq.size == 1 && ret.uniq.first == true
        aggregated_line_item_ids << aj.id
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

  def is_aggregated?
    !self.aggregated_job_id.nil?
  end

  def need_cutting
    ret = false
    if self.cut_reference.present?
      ret = true
    end
    ret
  end

  def need_printing
    ret = false
    if self.print_reference.present?
      ret = true
    end
    ret
  end

  def to_s
    "#{self.order_code} - #{self.order_line_item}"
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

  def check_aggregated_job
    ActiveRecord::Base.transaction do
      if self.aggregated_job.present?
        if self.aggregated_job.line_items.pluck(:status).uniq.size == 1 && self.aggregated_job.line_items.pluck(:status).uniq.first == 'completed'
          self.aggregated_job.update!(status: 'completed')
        end
      end
    end
  end
end
