class Customization < ApplicationRecord
  validates :parameter, presence: true

  def self.switch_token
    Customization.where(parameter: 'switch_token').first.value
  end

  def self.switch_url
    Customization.where(parameter: 'switch_url').first.value
  end

  def self.switch_port
    Customization.where(parameter: 'switch_port').first.value
  end

  def self.switch_user
    Customization.where(parameter: 'switch_user').first.value
  end

  def self.switch_psw
    Customization.where(parameter: 'switch_psw').first.value
  end

  def is_switch_related?
    self.parameter.include?('switch_')
  end
end
