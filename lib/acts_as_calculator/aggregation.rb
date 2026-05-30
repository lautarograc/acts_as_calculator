# frozen_string_literal: true

module ActsAsCalculator
  module Aggregation
    def self.sum(records, formula:, as_of: nil, group_by: nil)
      AggregateResults.(records:, formula:, as_of:, group_by:)
    end
  end
end
