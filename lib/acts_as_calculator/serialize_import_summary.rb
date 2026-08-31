# frozen_string_literal: true

module ActsAsCalculator
  class SerializeImportSummary
    def self.call(summary:)
      { source: summary.source,
        success: summary.success?,
        counts: summary.counts,
        outcomes: summary.outcomes.map { |outcome| serialize_outcome(outcome) } }
    end

    def self.serialize_outcome(outcome)
      { kind: outcome.kind, status: outcome.status, key: outcome.key,
        scope: outcome.scope, detail: outcome.detail }
    end
    private_class_method :serialize_outcome
  end
end
