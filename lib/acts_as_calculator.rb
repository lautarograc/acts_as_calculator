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
  DEFAULT_SCOPE = "default"

  def self.table_name_prefix
    "calculator_"
  end
end

require_relative "acts_as_calculator/cast_date"
require_relative "acts_as_calculator/cast_json_safe"
require_relative "acts_as_calculator/calculator_cache"
require_relative "acts_as_calculator/find_owned_record"
require_relative "acts_as_calculator/build_lookups"
require_relative "acts_as_calculator/resolve_formula_version"
require_relative "acts_as_calculator/persist_run"
require_relative "acts_as_calculator/evaluate_formula"

require_relative "acts_as_calculator/calculable" if defined?(::ActiveSupport)
require_relative "acts_as_calculator/engine" if defined?(::Rails::Engine)
