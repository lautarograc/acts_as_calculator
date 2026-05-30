# frozen_string_literal: true

module ActsAsCalculator
  class ResolveVariables
    SOURCE_TYPES = %i[attribute method lookup context].freeze

    def self.call(...)
      new(...).call
    end

    def initialize(specs:, calculable: nil, context: {}, lookups: {})
      @specs = specs
      @calculable = calculable
      @context = context
      @lookups = lookups
    end

    def call
      variables.each_with_object({}) do |spec, inputs|
        inputs[spec.name] = resolve(spec)
      end
    end

    private

    attr_reader :specs, :calculable, :context, :lookups

    def variables
      specs.map { |spec| VariableSpec.build(spec) }
    end

    def resolve(spec)
      value = fetch(spec)
      return value unless value.nil?
      raise MissingVariableError, "required variable #{spec.name.inspect} resolved to nil" if spec.required

      spec.default
    end

    def fetch(spec)
      case spec.source_type
      when :attribute then attribute_value(spec)
      when :method then method_value(spec)
      when :lookup then lookup_value(spec)
      when :context then context_value(spec.source_config[:key] || spec.name)
      else raise_unknown_source_type(spec)
      end
    end

    def attribute_value(spec)
      send_to_calculable(spec.source_config[:attribute] || spec.name)
    end

    def method_value(spec)
      send_to_calculable(spec.source_config[:method] || spec.name, *Array(spec.source_config[:args]))
    end

    def send_to_calculable(name, *args)
      return calculable.public_send(name, *args) if calculable.respond_to?(name)
      return calculable[name] if args.empty? && calculable.respond_to?(:[])

      raise_unreadable(name)
    end

    def raise_unreadable(name)
      raise VariableResolutionError, "no calculable given to read #{name.inspect} from" if calculable.nil?

      raise VariableResolutionError, "#{calculable.class} does not respond to #{name.inspect}"
    end

    def raise_unknown_source_type(spec)
      raise UnknownSourceTypeError,
            "unknown source_type #{spec.source_type.inspect} for #{spec.name.inspect} " \
            "(known: #{SOURCE_TYPES.join(", ")})"
    end

    def lookup_value(spec)
      tiers = tiers_for(spec.source_config[:table] || spec.name)
      using = spec.source_config[:using]
      return tiers if using.nil?

      FindTier.(tiers:, amount: lookup_amount(using)).value
    end

    def lookup_amount(source)
      return context_value(source) if context.key?(source.to_s) || context.key?(source.to_sym)

      send_to_calculable(source)
    end

    def tiers_for(table)
      lookups.fetch(table.to_s) do
        lookups.fetch(table.to_sym) do
          raise MissingLookupTableError, "no lookup table registered for #{table.inspect}"
        end
      end
    end

    def context_value(key)
      return context[key.to_s] if context.key?(key.to_s)

      context[key.to_sym]
    end
  end
end
