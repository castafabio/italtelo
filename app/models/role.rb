class Role < ApplicationRecord
  default_scope { order(value: :asc) }

  has_and_belongs_to_many :users

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true, uniqueness: true
  validates :value, presence: true, numericality: { only_integer: true }, uniqueness: true
end
