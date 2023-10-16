class Printer < ApplicationRecord
  belongs_to :customer_machine
  belongs_to :resource, polymorphic: true, optional: true

  after_commit :send_to_gest, on: :create

  validates :resource_id, presence: true, if: Proc.new {|p| p.resource_type.present? }
  validates :resource_type, inclusion: { in: PRINTER_MODELS }, if: Proc.new {|p| p.resource_id.present? }
  validates :customer_machine_id, inclusion: { in: Proc.new { CustomerMachine.ids } }
  validates :file_name, presence: true
  validates :starts_at, presence: true
  validates :print_time, presence: true

  def is_aggregated_job?
    self.resource_type == 'AggregatedJob'
  end

  def is_line_item?
    self.resource_type == 'LineItem'
  end

  private

  def send_to_gest
    UpdateItalteloTable.perform_later(self.id, 'printer') if self.resource.present?
  end
end
