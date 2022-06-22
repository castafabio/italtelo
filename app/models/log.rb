class Log < ApplicationRecord
  validates :action, presence: true
  validates :description, presence: true
  validates :kind, presence: true

  def to_id
    "#{self.class.name}-#{id}".parameterize
  end

  def to_s
    "#{description}"
  end
end
