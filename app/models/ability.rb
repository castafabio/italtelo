class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new

    if user.has_role? 'super_admin'
      can :manage, :all
      can :see_sidekiq, User
    elsif user.has_role? 'admin'
      can :manage, :all
      # can :manage, AggregatedJob
      # can :read, Cutter
      # can :manage, LineItem
      # can :read, Log
      # can :manage, CustomerMachine
      # can :read, Printer
      # can :manage, User
      # can [:see_aggregation], AggregatedJob
      # can [:see_administration], User
      # cannot :read, Role
      # cannot :read, SubmitPoint
      # cannot :read, SwitchField
      cannot :see_sidekiq, User
      cannot :manage, CustomerMachine
    elsif user.has_role? 'clerk'
      can :manage, :all
      # can :manage, AggregatedJob
      # can :read, Cutter
      # can :manage, LineItem
      # can :read, Printer
      # cannot [:see_aggregation], AggregatedJob
      # cannot :read, CustomerMachine
      # cannot :read, Role
      # cannot :read, SubmitPoint
      # cannot :read, SwitchField
      # cannot [:aggregate, :deaggregate, :send_to_switch, :upload_files, :delete_attachment], LineItem
      # cannot [:send_to_switch], Order
      cannot :see_sidekiq, User
      cannot :manage, CustomerMachine
    elsif user.has_role? 'production'
      can :manage, :all
      # can :manage, AggregatedJob
      # can :read, Cutter
      # can :manage, LineItem
      # can :read, Log
      # can :read, Printer
      # can [:see_aggregation], AggregatedJob
      # cannot [:see_administration], User
      # cannot :read, CustomerMachine
      # cannot :read, Role
      # cannot :read, SubmitPoint
      # cannot :read, SwitchField
      cannot :see_sidekiq, User
      cannot :read, User
      cannot :read, Role
      cannot :manage, CustomerMachine
      cannot :manage, SubmitPoint
    end
  end
end
