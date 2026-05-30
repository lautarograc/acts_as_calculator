# frozen_string_literal: true

module ActsAsCalculator
  Tier = Data.define(:from, :to, :value) do
    def self.build(source)
      return source if source.is_a?(Tier)

      attributes = source.respond_to?(:to_h) ? source.to_h : read_from(source)
      attributes = attributes.transform_keys(&:to_sym)

      new(from: attributes[:from], to: attributes[:to], value: attributes[:value])
    end

    def self.read_from(source)
      { from: source.from, to: source.to, value: source.value }
    end
    private_class_method :read_from

    def covers?(amount)
      amount >= lower_bound && amount < upper_bound
    end

    def lower_bound
      from || -Float::INFINITY
    end

    def upper_bound
      to || Float::INFINITY
    end
  end
end
