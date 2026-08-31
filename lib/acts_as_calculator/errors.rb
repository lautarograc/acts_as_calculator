# frozen_string_literal: true

module ActsAsCalculator
  class Error < StandardError; end

  class EvaluationError < Error; end
  class MissingVariableError < Error; end
  class VariableResolutionError < Error; end
  class UnknownSourceTypeError < Error; end
  class MissingLookupTableError < Error; end
  class TierNotFoundError < Error; end
  class UnknownStrategyError < Error; end
  class ApportionmentError < Error; end
  class AggregationError < Error; end
  class FormulaNotFoundError < Error; end
  class NoEffectiveVersionError < Error; end
  class TemplateNotFoundError < Error; end
  class TemplateRenderError < Error; end
  class UnsafeAssignError < Error; end
  class PartialSupersedeError < Error; end
  class ImportError < Error; end
  class LookupTableInUseError < ImportError; end
end
