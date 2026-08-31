# frozen_string_literal: true

module ActsAsCalculator
  class SupersedeFormulaVersions
    def self.call(...)
      new(...).call
    end

    def initialize(formula:, effective_from:, effective_to: nil)
      @formula = formula
      @effective_from = CastDate.(effective_from)
      @effective_to = effective_to && CastDate.(effective_to)
    end

    def call
      incumbents = overlapping
      orphaned = incumbents.find { |version| !covers_tail_of?(version) }
      raise PartialSupersedeError, uncovered_tail_message(orphaned) if orphaned

      incumbents.each { |version| supersede(version) }
    end

    private

    attr_reader :formula, :effective_from, :effective_to

    def overlapping
      versions = formula.versions.active
      versions = versions.where(effective_from: ..effective_to) if effective_to

      versions.open_ended_or_ending_on_or_after(effective_from).to_a
    end

    def covers_tail_of?(version)
      return true if effective_to.nil?

      !version.effective_to.nil? && version.effective_to <= effective_to
    end

    def supersede(version)
      if version.effective_from >= effective_from
        version.update!(status: FormulaVersion::RETIRED)
      else
        version.update!(effective_to: effective_from - 1)
      end
    end

    def uncovered_tail_message(version)
      tail = describe(effective_to + 1, version.effective_to)

      "version #{version.version_number} of formula #{formula.key.inspect} is effective " \
        "#{describe(version.effective_from, version.effective_to)}, which outlasts the new version's " \
        "#{describe(effective_from, effective_to)}. Superseding it would leave #{tail} with no active " \
        "version at all. Either extend the new version's effective_to to " \
        "#{describe_bound(version.effective_to)}, or declare a version covering #{tail} first — entries " \
        "are applied in order, so the one taking over the tail has to land before the one giving it up."
    end

    def describe(from, to)
      "#{from.iso8601}..#{describe_bound(to)}"
    end

    def describe_bound(date)
      date.nil? ? "open" : date.iso8601
    end
  end
end
