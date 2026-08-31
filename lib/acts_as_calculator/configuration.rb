# frozen_string_literal: true

module ActsAsCalculator
  class Configuration
    attr_accessor :enable_api

    def initialize
      @enable_api = false
    end
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end

  def self.reset_configuration!
    @configuration = Configuration.new
  end
end
