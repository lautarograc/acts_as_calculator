# frozen_string_literal: true

require "tmpdir"
require "logger"

ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

Dir.mktmpdir("acts_as_calculator_schema") do |destination|
  require InstallMigration.generate(destination)
end

CreateActsAsCalculatorTables.migrate(:up)

ActiveRecord::Base.connection.create_table :spec_departments, force: true do |t|
  t.string :name
end

ActiveRecord::Base.connection.create_table :spec_employees, force: true do |t|
  t.string :name
  t.decimal :salary, precision: 12, scale: 2
  t.integer :days_worked
  t.bigint :spec_department_id
end

ActiveRecord::Base.connection.create_table :spec_orders, force: true do |t|
  t.decimal :subtotal, precision: 12, scale: 2
end

%w[
  record formula formula_version variable lookup_table lookup_table_entry template run
].each do |model|
  require File.expand_path("../../app/models/acts_as_calculator/#{model}", __dir__)
end
