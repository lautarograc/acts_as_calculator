# frozen_string_literal: true

require "stringio"
require "rails/generators"
require "generators/acts_as_calculator/install/install_generator"

module InstallMigration
  module_function

  def generate(destination)
    silently { ActsAsCalculator::Generators::InstallGenerator.start([], destination_root: destination) }

    Dir[File.join(destination, "db", "migrate", "*_create_acts_as_calculator_tables.rb")].first
  end

  def silently
    original = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = original
  end
end
