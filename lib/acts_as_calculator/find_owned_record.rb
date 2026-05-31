# frozen_string_literal: true

module ActsAsCalculator
  class FindOwnedRecord
    def self.call(...)
      new(...).call
    end

    def initialize(relation:, key:, scope: nil, owner: nil)
      @relation = relation
      @key = key.to_s
      @scope = (scope || DEFAULT_SCOPE).to_s
      @owner = owner
    end

    def call
      owned || global
    end

    private

    attr_reader :relation, :key, :scope, :owner

    def owned
      return nil if owner.nil?

      candidates.owned_by(owner).first
    end

    def global
      candidates.global.first
    end

    def candidates
      relation.where(key:, scope:)
    end
  end
end
