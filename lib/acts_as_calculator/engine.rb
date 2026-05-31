# frozen_string_literal: true

require "action_dispatch"
require "rails"
require "rails/engine"
require "active_record"

module ActsAsCalculator
  class Engine < ::Rails::Engine
    isolate_namespace ActsAsCalculator

    config.generators do |generators|
      generators.test_framework :rspec
    end
  end
end
