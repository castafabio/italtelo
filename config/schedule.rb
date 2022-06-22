every 5.minute do
  runner "ImportColorado.perform_later"
  runner "ImportEfiXf.perform_later"
  runner "ImportKongsberg.perform_later"
  runner "ImportOrders.perform_later"
  runner "ImportRasterlink.perform_later"
  runner "ImportVutekH5.perform_later"
  runner "ImportVutekUbuntu.perform_later"
  runner "ImportZund.perform_later"
end

every 15.minutes do
  runner "Ping.perform_later"
end

every 1.day, at: ['2:00 am', '1:00 pm'] do
  runner "Backup.perform_later"
end
