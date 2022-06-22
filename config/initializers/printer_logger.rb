class PrinterLogger < Logger
  def format_message(severity, timestamp, progname, msg)
    "#{msg}\n"
  end
end

logfile = File.open(Rails.root.join('log','printer.log'), 'a')
logfile.sync = true
PRINTER_LOGGER = PrinterLogger.new(logfile)
