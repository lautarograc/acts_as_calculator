# frozen_string_literal: true

require "liquid"

module ActsAsCalculator
  class RenderLiquid
    FILE_SYSTEM_TAGS = %w[include render].freeze

    ITERATING_TAGS = %w[tablerow].freeze

    RESOURCE_LIMITS = {
      render_length_limit: 2_000_000,
      render_score_limit: 200_000,
      assign_score_limit: 2_000_000
    }.freeze

    MAX_ITERATIONS = 10_000

    class IterationBudget
      def initialize(limit)
        @limit = limit
        @remaining = limit
      end

      def reserve(collection)
        size = countable_size(collection)

        exhausted! if !size.nil? && size > remaining
      end

      def spend(count)
        @remaining -= count

        exhausted! if remaining.negative?
      end

      private

      attr_reader :limit, :remaining

      def countable_size(collection)
        case collection
        when ::Range, ::Array, ::Hash then collection.size
        end
      end

      def exhausted!
        raise Liquid::MemoryError, "template exceeded #{limit} loop iterations"
      end
    end

    class BoundedFor < Liquid::For
      private

      def collection_segment(context)
        budget = context.registers[:iteration_budget]
        budget&.reserve(context.evaluate(@collection_name))

        super.tap { |segment| budget&.spend(segment.length) }
      end
    end

    SANDBOX_TAGS = Liquid::Tags::STANDARD_TAGS
                   .reject { |name, _| (FILE_SYSTEM_TAGS + ITERATING_TAGS).include?(name) }
                   .merge("for" => BoundedFor)
                   .freeze

    SANDBOX = Liquid::Environment.build(
      error_mode: :strict,
      file_system: Liquid::BlankFileSystem.new,
      tags: SANDBOX_TAGS
    ) do |environment|
      environment.default_resource_limits = RESOURCE_LIMITS
      environment.register_filter(LiquidFilters)
    end

    def self.call(source:, assigns: {})
      Liquid::Template
        .parse(source.to_s, environment: SANDBOX, line_numbers: true)
        .render!(assigns,
                 registers: { iteration_budget: IterationBudget.new(MAX_ITERATIONS) },
                 strict_filters: true)
    rescue Liquid::Error => e
      raise TemplateRenderError, e.to_s
    end
  end
end
