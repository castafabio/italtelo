class CutterLogger < Logger
  def format_message(severity, timestamp, progname, msg)
    "#{msg}\n"
  end
end

logfile = File.open(Rails.root.join('log','cutter.log'), 'a')
logfile.sync = true
CUTTER_LOGGER = CutterLogger.new(logfile)
