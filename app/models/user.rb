class User < ApplicationRecord
  has_and_belongs_to_many :roles
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  validates :first_name, length: { maximum: 64 }, presence: true
  validates :last_name, length: { maximum: 64 }, presence: true

  after_create :assign_role

  def is_printing?
    self.last_name != 'Widegest'
  end

  def has_role?(code)
    self.roles.where(code: code).size > 0
  end

  def has_roles?
    self.roles.size > 0
  end

  def self.non_admin
    user_ids = []
    User.all.each do |user|
      user_ids << user.id unless user.has_role?('super_admin')
    end
    User.where(id: user_ids).where.order(:first_name)
  end

  def to_s
    "#{last_name} #{first_name}"
  end

  def to_id
    "#{self.class.name}-#{id}".parameterize
  end

  def self.working_users
    user_ids = []
    User.all.each do |usr|
      user_ids << usr.id unless usr.has_role?('super_admin')
    end
    User.where(id: user_ids).order(:first_name)
  end

  private

  def assign_role
    self.roles << Role.first
  end
end
