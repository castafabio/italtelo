class CustomerMachineLogger < Logger
  def format_message(severity, timestamp, progname, msg)
    "#{msg}\n"
  end
end

logfile = File.open(Rails.root.join('log','customer_machine.log'), 'a')
logfile.sync = true
CUSTOMER_MACHINE_LOGGER = CustomerMachineLogger.new(logfile)
