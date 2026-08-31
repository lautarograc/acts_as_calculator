# frozen_string_literal: true

RSpec.describe ActsAsCalculator::LiquidFilters do
  def render(source, assigns = {})
    ActsAsCalculator::RenderLiquid.(source:, assigns: ActsAsCalculator::CastLiquidValue.(assigns))
  end

  describe "currency" do
    it "rounds to two places and groups thousands" do
      expect(render("{{ amount | currency }}", { amount: BigDecimal("1234567.891") })).to eq("1,234,567.89")
    end

    it "rounds half up, the same way core's round_currency function does" do
      expect(render("{{ amount | currency }}", { amount: BigDecimal("2.345") })).to eq("2.35")
      expect(ActsAsCalculator::FunctionRegistry::ROUND_CURRENCY.(BigDecimal("2.345"), 2))
        .to eq(BigDecimal("2.35"))
    end

    it "pads a short fraction out to the requested precision" do
      expect(render("{{ amount | currency }}", { amount: 5 })).to eq("5.00")
    end

    it "takes an optional unit and precision" do
      expect(render('{{ amount | currency: "€", 0 }}', { amount: BigDecimal("1234.6") })).to eq("€1,235")
    end

    it "keeps the sign outside the grouping" do
      expect(render("{{ amount | currency }}", { amount: BigDecimal("-1234.5") })).to eq("-1,234.50")
    end

    it "renders a Result drop by its value" do
      result = ActsAsCalculator::Result.new(value: BigDecimal("1000"))

      expect(render("{{ result | currency }}", { result: })).to eq("1,000.00")
    end

    it "renders a missing value as blank rather than raising" do
      expect(render("[{{ nothing | currency }}]")).to eq("[]")
    end
  end

  describe "percentage" do
    it "reads its input as a fraction of one" do
      expect(render("{{ rate | percentage }}", { rate: BigDecimal("0.2205") })).to eq("22.05%")
    end

    it "honours a precision argument" do
      expect(render("{{ rate | percentage: 0 }}", { rate: BigDecimal("0.075") })).to eq("8%")
    end

    it "renders a missing value as blank" do
      expect(render("[{{ nothing | percentage }}]")).to eq("[]")
    end
  end

  describe "date" do
    it "formats a Date with strftime, as the plan's example does" do
      expect(render('{{ period | date: "%b %Y" }}', { period: Date.new(2026, 6, 1) })).to eq("Jun 2026")
    end

    it "defaults to ISO 8601" do
      expect(render("{{ period | date }}", { period: Date.new(2026, 6, 1) })).to eq("2026-06-01")
    end

    it "parses an ISO date string" do
      expect(render('{{ period | date: "%Y" }}', { period: "2026-06-01" })).to eq("2026")
    end

    it "renders an unparseable or missing date as blank" do
      expect(render("[{{ period | date }}][{{ nothing | date }}]", { period: "not a date" })).to eq("[][]")
    end
  end

  it "still offers Liquid's standard filters alongside its own" do
    expect(render("{{ name | upcase }}", { name: "ada" })).to eq("ADA")
  end
end
