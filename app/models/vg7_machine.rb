class Vg7Machine < ApplicationRecord
  has_and_belongs_to_many :customer_machines, dependent: :nullify

  validates :description, presence: true

  after_create :set_customer_machine

  def self.empty_customer_machines
    text = ""
    Vg7Machine.all.each do |machine|
      if CustomerMachine.where(vg7_machine_reference: machine.vg7_machine_reference).size == 0
        text += "#{machine.vg7_machine_reference}, "
      end
    end
    text
  end

  def to_s
    description
  end

  private

  def set_customer_machine
    CustomerMachine.where(vg7_machine_reference: self.vg7_machine_reference).each do |cm|
      cm.update!(vg7_machine_ids: self.id)
    end
  end
end
