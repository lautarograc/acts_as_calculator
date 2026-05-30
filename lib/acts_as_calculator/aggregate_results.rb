# frozen_string_literal: true

require "bigdecimal"

module ActsAsCalculator
  class AggregateResults
    def self.call(...)
      new(...).call
    end

    def initialize(records:, formula:, as_of: nil, group_by: nil)
      @records = records
      @formula = formula
      @as_of = as_of
      @group_by = group_by
    end

    def call
      return total(rows) if group_by.nil?

      rows.group_by { |record| group_key(record) }.transform_values { |group| total(group) }
    end

    private

    attr_reader :records, :formula, :as_of, :group_by

    def rows
      @rows ||= records.to_a
    end

    def total(group)
      group.sum(BigDecimal(0)) { |record| CastDecimal.(value_of(record)) }
    end

    def value_of(record)
      outcome = calculate(record)
      return outcome.value if outcome.respond_to?(:value)
      return outcome if outcome.is_a?(Numeric)

      raise AggregationError, "expected a Result or Numeric from #{record.inspect}, got #{outcome.inspect}"
    end

    def calculate(record)
      return formula.call(record) if formula.respond_to?(:call)
      raise AggregationError, "#{record.class} does not respond to #calculate" unless record.respond_to?(:calculate)

      as_of.nil? ? record.calculate(formula) : record.calculate(formula, as_of:)
    end

    def group_key(record)
      return group_by.call(record) if group_by.respond_to?(:call)

      record.public_send(group_by)
    end
  end
end
