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
    if User.where(email: user['email']).size == 0
      usr = User.create!(user)
    end
  end
end
puts "Users imported. "



if CustomerMachine.find_by(import_job: 'epson').bus240_machine_reference.nil?
  CustomerMachine.find_by(import_job: 'epson').update(bus240_machine_reference: 11)
end

if CustomerMachine.find_by(import_job: 'protek').bus240_machine_reference.nil?
  CustomerMachine.find_by(import_job: 'protek').update(bus240_machine_reference: 13)
end

if CustomerMachine.find_by(import_job: 'summa').bus240_machine_reference.nil?
  CustomerMachine.find_by(import_job: 'summa').update(bus240_machine_reference: 14)
end

if CustomerMachine.find_by(import_job: 'colorado').bus240_machine_reference.nil?
  CustomerMachine.find_by(import_job: 'colorado').update(bus240_machine_reference: 15)
end
