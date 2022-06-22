class SwitchLogger < Logger
  def format_message(severity, timestamp, progname, msg)
    "#{msg}\n"
  end
end

logfile = File.open(Rails.root.join('log','switch.log'), 'a')
logfile.sync = true
SWITCH_LOGGER = SwitchLogger.new(logfile)
