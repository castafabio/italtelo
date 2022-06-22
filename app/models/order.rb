class Order < ApplicationRecord
  has_many :line_items, dependent: :destroy

  validates :order_code, presence: true
  validates :order_date, presence: true
  validates :customer, presence: true

end
