# frozen_string_literal: true

module ActsAsCalculator
  class ParseFormulaExpression
    CALL_PATTERN = /@([A-Za-z_][A-Za-z0-9_]*)/

    def self.call(...)
      new(...).call
    end

    def self.substitute(expression)
      expression.to_s.gsub(CALL_PATTERN) { yield(::Regexp.last_match(1)) }
    end

    def initialize(expression:, scope: nil, owner: nil, pins: nil, validate: true)
      @expression = expression.to_s
      @scope = (scope || DEFAULT_SCOPE).to_s
      @owner = owner
      @pins = FormulaCall.pins(pins)
      @validate = validate
    end

    def call
      referenced_keys.map { |key| build_call(key) }
    end

    private

    attr_reader :expression, :scope, :owner, :pins, :validate

    def referenced_keys
      expression.scan(CALL_PATTERN).flatten.uniq
    end

    def build_call(key)
      verify(key) if validate

      FormulaCall.build(key:, version_id: pins[key])
    end

    def verify(key)
      return if FindOwnedRecord.(relation: Formula.all, key:, scope:, owner:)

      raise FormulaNotFoundError,
            "expression references @#{key} but no formula #{key.inspect} exists " \
            "in scope #{scope.inspect} for #{describe_owner}"
    end

    def describe_owner
      owner.nil? ? "no owner" : "#{owner.class}##{owner.id} (or globally)"
    end
  end
end
