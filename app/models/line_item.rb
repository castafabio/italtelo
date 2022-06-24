class LineItem < ApplicationRecord
  scope :unsend, -> { where(send_at: nil) }

  belongs_to :customer_machine
  belongs_to :aggregated_job, optional: true

  has_one_attached :attached_file

  attr_accessor :send_now

  validates :row_number, presence: true
  validates :article_code, presence: true
  validates :article_description, presence: true

  def self.aggregable
    line_item_ids = []
    LineItem.where(aggregated_job_id: nil).each do |line_item|
      if line_item.customer_machine.present?
        line_item_ids << line_item.id
      end
    end
    LineItem.where(id: line_item_ids)
  end

  def send_to_hotfolder!
    raise "Percorso hotfolder per la macchina #{self.customer_machine} non configurato, chiamare l'assistenza." if self.customer_machine.hotfolder_path.nil?
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

  def has_errors?
    return false if self.error_message == nil
  end

  def editable?
    self.aggregated_job.nil?
  end

  def to_file_path
    ActiveStorage::Blob.service.send(:path_for, self.attached_file.key)
  end

  def to_switch_name(kind)
    code = self.id.to_s.rjust(7, '0')
    "#{code}01LI.zip"
  end

  def appendable_aggregate_line_item_list
    aggregated_line_item_ids = []
    all_aggregated_jobs = AggregatedJob.unsend.brand_new
    all_aggregated_jobs.each do |aj|
      aggregated_line_item_ids << aj.id if (self.need_printing && aj.line_items.first.need_printing || self.need_cutting && aj.line_items.first.need_cutting) && (self&.customer_machine&.id == aj.customer_machine_id)
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

  def to_s
    "#{self.order_code} - #{self.row_number}"
  end

  def check_aggregated_job
    ActiveRecord::Base.transaction do
      if self.aggregated_job.present?
        if self.aggregated_job.line_items.pluck(:status).size == 1 && self.aggregated_job.line_items.pluck(:status).uniq.first == 'completed'
          self.aggregated_job.update!(status: 'completed')
        end
      end
    end
  end
end
