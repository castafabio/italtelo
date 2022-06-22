class GestionaleLogger < Logger
  def format_message(severity, timestamp, progname, msg)
    "#{msg}\n"
  end
end

logfile = File.open(Rails.root.join('log','gestionale.log'), 'a')
logfile.sync = true
GESTIONALE_LOGGER = GestionaleLogger.new(logfile)
