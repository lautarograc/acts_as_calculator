# frozen_string_literal: true

RSpec.describe ActsAsCalculator::ImportSummary do
  def outcome(status, kind: :formula, key: "net_pay", detail: nil)
    ActsAsCalculator::ImportOutcome.build(kind:, status:, key:, scope: "payroll", detail:)
  end

  it "counts every status, including the ones that did not happen" do
    summary = described_class.new(source: "payroll.json", outcomes: [outcome(:created), outcome(:skipped)])

    expect(summary.counts).to eq(created: 1, updated: 0, skipped: 1, failed: 0)
  end

  it "is a success when nothing failed" do
    expect(described_class.new(source: "x", outcomes: [outcome(:skipped)])).to be_success
  end

  it "is not a success when anything failed, and collects the failures" do
    failure = outcome(:failed, detail: "boom")
    summary = described_class.new(source: "x", outcomes: [outcome(:created), failure])

    expect(summary).not_to be_success
    expect(summary.failures).to eq([failure])
  end

  it "prints the source, the tally and one line per entry" do
    summary = described_class.new(source: "payroll.json",
                                  outcomes: [outcome(:created, detail: "version 1"),
                                             outcome(:failed, kind: :template, key: "payslip", detail: "boom")])

    expect(summary.to_s).to eq(<<~REPORT.chomp)
      acts_as_calculator: imported payroll.json — 1 created, 0 updated, 0 skipped, 1 failed
        created formula "net_pay" (scope "payroll") — version 1
        failed template "payslip" (scope "payroll") — boom
    REPORT
  end

  it "omits the dash when an outcome has no detail" do
    expect(described_class.new(source: "x", outcomes: [outcome(:skipped)]).to_s)
      .to end_with(%(skipped formula "net_pay" (scope "payroll")))
  end
end
