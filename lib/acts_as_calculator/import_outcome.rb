# frozen_string_literal: true

module ActsAsCalculator
  IMPORT_STATUSES = %i[created updated skipped failed].freeze

  ImportOutcome = Data.define(:kind, :status, :key, :scope, :detail) do
    def self.build(kind:, status:, key:, scope:, detail: nil)
      new(kind: kind.to_sym, status: status.to_sym, key: key.to_s, scope: scope.to_s, detail:)
    end

    def failed?
      status == :failed
    end

    def to_s
      "#{status} #{kind} #{key.inspect} (scope #{scope.inspect})#{detail && " — #{detail}"}"
    end
  end
end
