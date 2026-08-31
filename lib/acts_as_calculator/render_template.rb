# frozen_string_literal: true

module ActsAsCalculator
  class RenderTemplate
    def self.call(...)
      new(...).call
    end

    def initialize(key: nil, scope: nil, owner: nil, version_number: nil,
                   template: nil, result: nil, results: {}, context: {})
      @key = key
      @scope = scope
      @owner = owner
      @version_number = version_number
      @template = template
      @result = result
      @results = results
      @context = context
    end

    def call
      RenderLiquid.(source: template.body, assigns:)
    end

    private

    attr_reader :key, :scope, :owner, :version_number, :result, :results, :context

    def template
      @template ||= ResolveTemplate.(key:, scope:, owner:, version_number:)
    end

    def assigns
      CastLiquidValue.(context).merge(
        "result" => CastLiquidValue.(result),
        "results" => CastLiquidValue.(results)
      )
    end
  end
end
