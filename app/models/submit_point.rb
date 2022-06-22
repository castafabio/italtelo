class SubmitPoint < ApplicationRecord
  scope :for_line_items, -> { where(kind: ['line_item', 'all']) }
  scope :for_aggregated_jobs, -> { where(kind: ['aggregated_job', 'all']) }

  belongs_to :operation, optional: true
  has_many :switch_fields, dependent: :nullify
  has_many :line_items, dependent: :nullify
  has_many :aggregated_jobs, dependent: :nullify

  validates :kind, inclusion: { in: SUBMIT_POINT_KINDS }
  validates :name, presence: true

  def self.get_kinds
    SUBMIT_POINT_KINDS - ['aggregation']
  end

  def to_id
    "#{self.class.name}-#{id}".parameterize
  end

  def to_s
    "#{name}"
  end
end
