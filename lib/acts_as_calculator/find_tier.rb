# frozen_string_literal: true

module ActsAsCalculator
  class FindTier
    def self.call(...)
      new(...).call
    end

    def initialize(tiers:, amount:)
      @tiers = tiers
      @amount = amount
    end

    def call
      built = tiers.map { |tier| Tier.build(tier) }

      built.find { |tier| tier.covers?(amount) } ||
        raise(TierNotFoundError, "no tier covers #{amount.inspect} in #{built.inspect}")
    end

    private

    attr_reader :tiers, :amount
  end
end
