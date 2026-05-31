# frozen_string_literal: true

require "bigdecimal"
require "date"

require "active_record"
require "rails/engine"

require "acts_as_calculator"

require_relative "support/install_migration"
require_relative "support/schema"
require_relative "support/host_models"
require_relative "support/factories"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"

  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end

  config.after { ActsAsCalculator::CalculatorCache.default.clear }

  config.include Factories
end
