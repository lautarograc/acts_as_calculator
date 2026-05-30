# frozen_string_literal: true

module ActsAsCalculator
  Result = Data.define(:value, :breakdown, :formula_version, :as_of) do
    def initialize(value:, breakdown: {}, formula_version: nil, as_of: nil)
      super(value:, breakdown: deep_copy(breakdown), formula_version:, as_of:)
    end

    def inputs
      breakdown.fetch(:inputs, {})
    end

    def expression
      breakdown[:expression]
    end

    private

    def deep_copy(value)
      case value
      when Hash then value.to_h { |key, nested| [deep_copy(key), deep_copy(nested)] }.freeze
      when Array then value.map { |nested| deep_copy(nested) }.freeze
      when String then -value
      else value
      end
    end
  end
end
