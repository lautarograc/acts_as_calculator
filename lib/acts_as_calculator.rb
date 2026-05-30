# frozen_string_literal: true

require "bigdecimal"
require "dentaku"

require_relative "acts_as_calculator/version"
require_relative "acts_as_calculator/errors"
require_relative "acts_as_calculator/cast_decimal"
require_relative "acts_as_calculator/result"
require_relative "acts_as_calculator/tier"
require_relative "acts_as_calculator/variable_spec"
require_relative "acts_as_calculator/find_tier"
require_relative "acts_as_calculator/function_registry"
require_relative "acts_as_calculator/build_calculator"
require_relative "acts_as_calculator/evaluate_expression"
require_relative "acts_as_calculator/resolve_variables"
require_relative "acts_as_calculator/divide_proportionally"
require_relative "acts_as_calculator/distribute_remainder"
require_relative "acts_as_calculator/apportionment"
require_relative "acts_as_calculator/apportion_amount"
require_relative "acts_as_calculator/aggregation"
require_relative "acts_as_calculator/aggregate_results"

module ActsAsCalculator
end
