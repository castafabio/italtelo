puts ' Importing roles... '
if Role.where(code: 'super_admin').size == 0
  Role.create!(code: 'super_admin', name: 'Super Amministratore', value: 10)
end

if Role.where(code: 'admin').size == 0
  Role.create!(code: 'admin', name: 'Amministratore', value: 20)
end

if Role.where(code: 'clerk').size == 0
  Role.create!(code: 'clerk', name: 'Amministrazione', value: 30)
end

if Role.where(code: 'production').size == 0
  Role.create!(code: 'production', name: 'Produzione', value: 40)
end
puts ' Roles imported. '


puts "Importing Users..."
# Users
json = ActiveSupport::JSON.decode(File.read('db/seeds/users.json'))
json.each do |environment, users|
  next if environment == 'development' && Rails.env != 'development'
  users.each do |user|
    usr = User.create!(user)
  end
end
puts "Users imported. "

puts "Customizations ... "
if Customization.where(parameter: 'switch_token').size == 0
  Customization.create!(parameter: 'switch_token', value: '0')
end

if Customization.where(parameter: 'switch_url').size == 0
  Customization.create!(parameter: 'switch_url', value: 'http://', notes: 'Url server switch')
end

if Customization.where(parameter: 'switch_port').size == 0
  Customization.create!(parameter: 'switch_port', value: '51088', notes: 'Porta server switch')
end

if Customization.where(parameter: 'switch_user').size == 0
  Customization.create!(parameter: 'switch_user', value: 'Administrator', notes: 'Utente switch')
end

if Customization.where(parameter: 'switch_psw').size == 0
  Customization.create!(parameter: 'switch_psw', value: '', notes: 'Password utente switch')
end
