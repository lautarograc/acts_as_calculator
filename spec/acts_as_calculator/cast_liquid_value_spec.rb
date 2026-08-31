# frozen_string_literal: true

RSpec.describe ActsAsCalculator::CastLiquidValue do
  it "passes primitives through untouched" do
    expect(described_class.({ "a" => 1, "b" => 2.5, "c" => "s", "d" => true, "e" => nil }))
      .to eq({ "a" => 1, "b" => 2.5, "c" => "s", "d" => true, "e" => nil })
  end

  it "stringifies symbol keys and values so a template can look them up" do
    expect(described_class.({ total: :paid })).to eq({ "total" => "paid" })
  end

  it "renders a BigDecimal as a plain decimal string rather than engineering notation" do
    expect(described_class.(BigDecimal("1000"))).to eq("1000.0")
  end

  it "keeps dates and times as themselves so the date filter can format them" do
    date = Date.new(2026, 6, 1)

    expect(described_class.(date)).to be(date)
  end

  it "recurses through nested containers" do
    expect(described_class.({ lines: [{ amount: BigDecimal("2.5") }] }))
      .to eq({ "lines" => [{ "amount" => "2.5" }] })
  end

  it "wraps a Result in a drop rather than assigning it raw" do
    cast = described_class.(ActsAsCalculator::Result.new(value: BigDecimal("5")))

    expect(cast).to be_a(ActsAsCalculator::ResultDrop)
  end

  it "lets a host supply its own drop" do
    drop = Class.new(Liquid::Drop).new

    expect(described_class.(drop)).to be(drop)
  end

  it "accepts ActiveSupport::TimeWithZone, which is neither a Date nor a Time" do
    zoned = ActiveSupport::TimeWithZone.new(Time.utc(2026, 6, 1), ActiveSupport::TimeZone["UTC"])

    expect(described_class.(zoned)).to be(zoned)
  end

  it "refuses an unknown object that merely quacks like a time" do
    impostor = Class.new do
      def strftime(format) = format
      def to_time = Time.now
    end.new

    expect { described_class.(impostor) }.to raise_error(ActsAsCalculator::UnsafeAssignError)
  end

  describe "refusing everything else" do
    it "refuses a plain object" do
      expect { described_class.(Object.new) }
        .to raise_error(ActsAsCalculator::UnsafeAssignError, /wrap it in a Liquid::Drop/)
    end

    it "refuses an ActiveRecord model, whose attributes are one bracket lookup away" do
      expect { described_class.(build_employee) }
        .to raise_error(ActsAsCalculator::UnsafeAssignError, /SpecEmployee/)
    end

    it "refuses a formula version rather than exposing the record behind a Result" do
      expect { described_class.(build_version) }
        .to raise_error(ActsAsCalculator::UnsafeAssignError, /FormulaVersion/)
    end

    it "refuses an unsafe value nested inside a hash" do
      expect { described_class.({ employee: build_employee }) }
        .to raise_error(ActsAsCalculator::UnsafeAssignError)
    end

    it "refuses an unsafe value nested inside an array" do
      expect { described_class.([1, Object.new]) }
        .to raise_error(ActsAsCalculator::UnsafeAssignError)
    end
  end
end
