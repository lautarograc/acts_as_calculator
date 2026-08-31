# frozen_string_literal: true

require "rails"
require "action_controller/railtie"
require "rack/test"

module CalculatorHost
  class Application < ::Rails::Application
    config.root = File.expand_path("host_app", __dir__)
    config.eager_load = false
    config.enable_reloading = false
    config.secret_key_base = "acts_as_calculator_spec_secret_key_base"
    config.public_file_server.enabled = false
    config.cache_store = :null_store
    config.logger = ::Logger.new(IO::NULL)
    config.hosts.clear
    config.action_dispatch.show_exceptions = :none
  end
end

Rails.application.initialize!

Rails.application.routes.draw do
  mount ActsAsCalculator::Engine => "/calculator"
end
