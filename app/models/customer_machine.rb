class CustomerMachine < ApplicationRecord
  scope :printer_machines, -> { where(kind: 'printer') }
  scope :cutter_machines, -> { where(kind: 'cutter') }
  scope :import_machines, -> {where('customer_machines.path IS true OR customer_machines.ip_address IS true')}

  has_many :printers, dependent: :restrict_with_exception
  has_many :print_jobs, class_name: "LineItem", foreign_key: "print_customer_machine_id", dependent: :nullify
  has_many :cut_jobs, class_name: "LineItem", foreign_key: "cut_customer_machine_id", dependent: :nullify
  has_many :print_aggregated_jobs, class_name: "LineItem", foreign_key: "print_customer_machine_id", dependent: :nullify
  has_many :cut_aggregated_jobs, class_name: "LineItem", foreign_key: "cut_customer_machine_id", dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :kind, inclusion: { in: CUSTOMER_MACHINE_KINDS }

  def self.hour_to_seconds(time)
    print_time = 0
    time.split(':').each_with_index do |time, index|
      if index == 0
        print_time += time.to_i * 3600
      elsif index == 1
        print_time += time.to_i * 60
      else
        print_time += time.to_i
      end
    end
    print_time
  end

  def self.to_id(machine_switch_name)
    CustomerMachine.find_by(machine_switch_name: machine_switch_name).id
  end

  def self.get_machine_switch_name(customer_machine_id)
    CustomerMachine.find_by(id: customer_machine_id).machine_switch_name
  end

  def self.ping(host)
    require 'net/ping'
    check = Net::Ping::External.new(host)
    check.ping?
  end

  def is_mounted?
    ret = false
    if self.ip_address.present?
      ret = CustomerMachine.ping(self.ip_address)
    else
      ret = true
    end
    ret
  end

  def mount
    system("mount #{self.path}")
  end

  def to_s
    name
  end
end
