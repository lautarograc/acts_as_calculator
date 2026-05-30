# frozen_string_literal: true

require "bigdecimal"

module ActsAsCalculator
  class ApportionAmount
    def self.call(...)
      new(...).call
    end

    def initialize(amount:, among:, by: nil, strategy: :proportional,
                   precision: Apportionment::DEFAULT_PRECISION)
      @amount = amount
      @among = among
      @by = by
      @strategy = strategy
      @precision = precision
    end

    def call
      raise ApportionmentError, "cannot apportion among an empty collection" if members.empty?

      shares = Apportionment.strategy(strategy).call(amount: total, weights:, precision:)

      members.zip(weights, shares).map do |member, weight, share|
        Apportionment::Share.new(member:, weight:, amount: share)
      end
    end

    private

    attr_reader :amount, :among, :by, :strategy, :precision

    def total
      @total ||= CastDecimal.(amount)
    end

    def members
      @members ||= among.to_a
    end

    def weights
      @weights ||= members.map { |member| weight_for(member) }
    end

    def weight_for(member)
      return BigDecimal(1) if by.nil? || strategy.to_sym == :equal

      weight = CastDecimal.(raw_weight(member))
      raise ApportionmentError, "negative weight #{weight.to_f} from #{by.inspect}" if weight.negative?

      weight
    end

    def raw_weight(member)
      value = by.respond_to?(:call) ? by.call(member) : member.public_send(by)
      raise ApportionmentError, "#{by.inspect} returned nil for #{member.inspect}" if value.nil?

      value
    end
  end
end
