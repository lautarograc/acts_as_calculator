# frozen_string_literal: true

require "active_support/concern"
require "active_support/core_ext/class/attribute"

module ActsAsCalculator
  module Calculable
    extend ::ActiveSupport::Concern

    included do
      has_many :calculator_runs,
               class_name: "ActsAsCalculator::Run",
               as: :calculable,
               inverse_of: :calculable

      class_attribute :calculator_scope_name, instance_writer: false, default: DEFAULT_SCOPE
    end

    class_methods do
      def calculator_scope(name)
        self.calculator_scope_name = name.to_s
      end
    end

    def calculate(key, as_of: nil, scope: nil, owner: nil, dry_run: false, context: {}, **extra)
      EvaluateFormula.(
        calculable: self,
        key:,
        scope: scope || calculator_scope_name,
        owner: owner || calculator_owner,
        as_of:,
        context: extra.merge(context),
        dry_run:
      )
    end

    def calculate_as_of(key, as_of, **context)
      calculate(key, as_of:, **context)
    end

    def calculation_history(key = nil, limit: nil)
      runs = calculator_runs.recent_first
      runs = runs.for_formula_key(key) unless key.nil?
      limit.nil? ? runs : runs.limit(limit)
    end

    def calculator_owner
      nil
    end

    def render(key, calculate: nil, result: nil, results: {}, as_of: nil, scope: nil,
               owner: nil, version_number: nil, dry_run: false, context: {}, **extra)
      assigns = extra.merge(context)
      computed = calculator_render_results(calculate, as_of:, scope:, owner:, dry_run:, context: assigns)

      RenderTemplate.(
        key:, version_number:, context: assigns,
        scope: scope || calculator_scope_name,
        owner: owner || calculator_owner,
        result: result || (computed.values.first unless calculate.is_a?(Array)),
        results: results.merge(computed)
      )
    end

    private

    def calculator_render_results(keys, as_of:, scope:, owner:, dry_run:, context:)
      Array(keys).to_h do |formula_key|
        [formula_key.to_s, calculate(formula_key, as_of:, scope:, owner:, dry_run:, context:)]
      end
    end
  end
end
