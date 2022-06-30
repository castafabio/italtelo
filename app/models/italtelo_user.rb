class ItalteloUser < ApplicationRecord
  scope :ordered, -> { order(:description) }

  has_many :line_items, dependent: :nullify

  def to_s
    description
  end

end
