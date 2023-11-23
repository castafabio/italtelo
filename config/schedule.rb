every 2.minute do
  runner "ImportOrders.perform_later"
end


every 5.minute do
  runner "ImportColorado.perform_later"
  runner "ImportEfkal.perform_later"
  runner "ImportEpson.perform_later"
  runner "ImportFlora.perform_later"
  runner "ImportProtek.perform_later"
  runner "ImportSumma.perform_later"
  runner "ImportVutekH5.perform_later"
  runner "ImportVutekUbuntu.perform_later"
  runner "ImportVutekWindows.perform_later"
end


every 15.minutes do
  runner "Ping.perform_later"
end

every 1.day, at: ['2:00 am', '1:00 pm'] do
  runner "Backup.perform_later"
end

every 1.day, at: ['2:00 am'] do
  runner "CheckItalteloUsers.perform_later"
end
