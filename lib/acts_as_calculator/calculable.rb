# frozen_string_literal: true

require "active_support/concern"
require "active_support/core_ext/class/attribute"

module ActsAsCalculator
  module Calculable
    extend ::ActiveSupport::Concern

    RESERVED_KEYWORDS = %i[as_of scope owner dry_run].freeze

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

    def calculate(key, as_of: nil, scope: nil, owner: nil, dry_run: false, **context)
      EvaluateFormula.(
        calculable: self,
        key:,
        scope: scope || calculator_scope_name,
        owner: owner || calculator_owner,
        as_of:,
        context:,
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

    def render(*, **)
      raise NotImplementedError,
            "ActsAsCalculator::Calculable#render arrives with Liquid template rendering in Phase 3"
    end
  end
end
