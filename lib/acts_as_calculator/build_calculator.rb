# frozen_string_literal: true

require "dentaku"

module ActsAsCalculator
  class BuildCalculator
    def self.call(...)
      new(...).call
    end

    def initialize(functions: FunctionRegistry.default, case_sensitive: false)
      @functions = functions
      @case_sensitive = case_sensitive
    end

    def call
      functions.install(Dentaku::Calculator.new(case_sensitive:))
    end

    private

    attr_reader :functions, :case_sensitive
  end
end
