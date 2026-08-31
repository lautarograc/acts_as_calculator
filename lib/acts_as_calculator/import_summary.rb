# frozen_string_literal: true

module ActsAsCalculator
  ImportSummary = Data.define(:source, :outcomes) do
    def success?
      failures.empty?
    end

    def failures
      outcomes.select(&:failed?)
    end

    def counts
      IMPORT_STATUSES.to_h { |status| [status, outcomes.count { |outcome| outcome.status == status }] }
    end

    def to_s
      [headline, *outcomes.map { |outcome| "  #{outcome}" }].join("\n")
    end

    private

    def headline
      tally = counts.map { |status, count| "#{count} #{status}" }.join(", ")

      "acts_as_calculator: imported #{source} — #{tally}"
    end
  end
end
