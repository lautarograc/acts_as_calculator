# frozen_string_literal: true

require "bigdecimal"
require "dentaku"
require "liquid"

require_relative "acts_as_calculator/version"
require_relative "acts_as_calculator/errors"
require_relative "acts_as_calculator/configuration"
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
require_relative "acts_as_calculator/formula_version_drop"
require_relative "acts_as_calculator/result_drop"
require_relative "acts_as_calculator/cast_liquid_value"
require_relative "acts_as_calculator/liquid_filters"
require_relative "acts_as_calculator/render_liquid"

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
require_relative "acts_as_calculator/resolve_template"
require_relative "acts_as_calculator/promote_template"
require_relative "acts_as_calculator/render_template"
require_relative "acts_as_calculator/import_outcome"
require_relative "acts_as_calculator/import_summary"
require_relative "acts_as_calculator/read_import_file"
require_relative "acts_as_calculator/resolve_import_owner"
require_relative "acts_as_calculator/find_lookup_table_references"
require_relative "acts_as_calculator/supersede_formula_versions"
require_relative "acts_as_calculator/cast_variable_attributes"
require_relative "acts_as_calculator/publish_formula_version"
require_relative "acts_as_calculator/publish_template"
require_relative "acts_as_calculator/import_lookup_table"
require_relative "acts_as_calculator/import_formula"
require_relative "acts_as_calculator/import_template"
require_relative "acts_as_calculator/import_definitions"
require_relative "acts_as_calculator/serialize_formula_version"
require_relative "acts_as_calculator/serialize_formula"
require_relative "acts_as_calculator/serialize_template"
require_relative "acts_as_calculator/serialize_import_summary"

require_relative "acts_as_calculator/calculable" if defined?(::ActiveSupport)
require_relative "acts_as_calculator/engine" if defined?(::Rails::Engine)
