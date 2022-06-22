class Cutter < ApplicationRecord
  belongs_to :customer_machine, optional: true
  belongs_to :resource, polymorphic: true, optional: true

  after_commit :send_to_gest, on: :create

  validates :resource_id, presence: true, if: Proc.new {|p| p.resource_type.present? }
  validates :resource_type, inclusion: { in: CUTTER_MODELS }, if: Proc.new {|p| p.resource_id.present? }
  validates :cut_time, presence: true, numericality: { only_integer: true }
  validates :starts_at, presence: true
  validates :ends_at, presence: true

  def is_aggregated_job?
    self.resource_type == 'AggregatedJob'
  end

  def is_line_item?
    self.resource_type == 'LineItem'
  end

  private

  def send_to_gest
    SendToGest.perform_later(self.id, 'cutter')
  end
end
