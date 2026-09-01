# frozen_string_literal: true

RSpec.describe ActsAsCalculator::EvaluateFormulaCall do
  let(:employee) { build_employee(salary: 1000, days_worked: 20) }

  def publish(key, expression, variables: [], effective_from: Factories::JANUARY, formula_calls: nil)
    formula = ActsAsCalculator::Formula.find_by(key:, scope: "payroll") || build_formula(key:, scope: "payroll")

    ActsAsCalculator::PublishFormulaVersion.(formula:, expression:, effective_from:, variables:, formula_calls:)
  end

  def attribute(name)
    { name:, source_type: "attribute" }
  end

  def evaluate(version, **options)
    described_class.(formula_version: version, calculable: employee, as_of: Date.new(2026, 6, 1), **options)
  end

  describe "nesting" do
    it "evaluates a formula that calls another" do
      publish("gross", "salary", variables: [attribute("salary")])
      net = publish("net", "@gross * 0.8")

      expect(evaluate(net).value).to eq(BigDecimal("800"))
    end

    it "evaluates an arbitrarily deep chain" do
      publish("d", "salary", variables: [attribute("salary")])
      publish("c", "@d + 1")
      publish("b", "@c + 1")
      a = publish("a", "@b + 1")

      expect(evaluate(a).value).to eq(BigDecimal("1003"))
    end

    it "mixes called formulas with its own variables in one expression" do
      publish("gross", "salary", variables: [attribute("salary")])
      net = publish("net", "@gross - deduction", variables: [{ name: "deduction", source_type: "context" }])

      expect(evaluate(net, context: { "deduction" => 250 }).value).to eq(BigDecimal("750"))
    end

    it "calls the same formula from two places in one expression" do
      publish("gross", "salary", variables: [attribute("salary")])
      net = publish("net", "@gross + @gross")

      expect(evaluate(net).value).to eq(BigDecimal("2000"))
    end

    it "keeps two keys apart when one prefixes the other" do
      publish("tax", "100")
      publish("tax_credit", "40")
      net = publish("net", "@tax - @tax_credit")

      expect(evaluate(net).value).to eq(BigDecimal("60"))
    end
  end

  describe "each formula resolving its own inputs" do
    it "runs a called formula's lookup table independently of the caller" do
      build_lookup_table(key: "federal", scope: "payroll",
                         tiers: [{ from: 0, to: 5_000, value: 0.1 }, { from: 5_000, to: nil, value: 0.32 }])
      publish("tax", "salary * rate",
              variables: [attribute("salary"),
                          { name: "rate", source_type: "lookup",
                            source_config: { table: "federal", using: "salary" } }])
      net = publish("net", "salary - @tax", variables: [attribute("salary")])

      expect(evaluate(net).value).to eq(BigDecimal("900.0"))
    end

    it "does not let a callee borrow a variable only the caller declared" do
      publish("gross", "salary")
      net = publish("net", "@gross", variables: [attribute("salary")])

      expect { evaluate(net) }
        .to raise_error(ActsAsCalculator::FormulaCallError, /net -> gross failed/)
    end

    it "resolves a callee's own declaration of a name the caller also declares, from its own source" do
      publish("gross", "salary", variables: [{ name: "salary", source_type: "context" }])
      net = publish("net", "@gross - salary", variables: [attribute("salary")])

      expect(evaluate(net, context: { "salary" => 1200 }).value).to eq(BigDecimal("200"))
    end

    it "passes context down, which is the one channel a caller shares" do
      publish("bonus", "rate * 100", variables: [{ name: "rate", source_type: "context" }])
      net = publish("net", "@bonus")

      expect(evaluate(net, context: { "rate" => 3 }).value).to eq(BigDecimal("300"))
    end
  end

  describe "version pinning" do
    it "uses the version in force on as_of when nothing is pinned" do
      publish("tax", "100", effective_from: Date.new(2026, 1, 1))
      publish("tax", "200", effective_from: Date.new(2026, 7, 1))
      net = publish("net", "@tax")

      expect([evaluate(net, as_of: Date.new(2026, 3, 1)).value,
              evaluate(net, as_of: Date.new(2026, 8, 1)).value])
        .to eq([BigDecimal("100"), BigDecimal("200")])
    end

    it "holds a pinned version steady as the date moves past it" do
      pinned = publish("tax", "100", effective_from: Date.new(2026, 1, 1))
      publish("tax", "200", effective_from: Date.new(2026, 7, 1))
      net = publish("net", "@tax", formula_calls: { "calls" => [{ "key" => "tax", "version_id" => pinned.id }] })

      expect(evaluate(net, as_of: Date.new(2026, 8, 1)).value).to eq(BigDecimal("100"))
    end

    it "records the pin on the version, so it survives a reload" do
      pinned = publish("tax", "100")
      net = publish("net", "@tax", formula_calls: { "calls" => [{ "key" => "tax", "version_id" => pinned.id }] })

      expect(net.reload.formula_calls).to eq("calls" => [{ "key" => "tax", "version_id" => pinned.id }])
    end

    it "pins one call and leaves the other on as_of" do
      pinned = publish("tax", "100", effective_from: Date.new(2026, 1, 1))
      publish("tax", "200", effective_from: Date.new(2026, 7, 1))
      publish("levy", "1", effective_from: Date.new(2026, 1, 1))
      publish("levy", "5", effective_from: Date.new(2026, 7, 1))
      net = publish("net", "@tax + @levy",
                    formula_calls: { "calls" => [{ "key" => "tax", "version_id" => pinned.id }] })

      expect(evaluate(net, as_of: Date.new(2026, 8, 1)).value).to eq(BigDecimal("105"))
    end

    it "fails loudly when a pin points at a version that is gone" do
      publish("tax", "100")
      net = publish("net", "@tax", formula_calls: { "calls" => [{ "key" => "tax", "version_id" => 999_999 }] })

      expect { evaluate(net) }.to raise_error(ActsAsCalculator::FormulaCallError, /does not exist/)
    end
  end

  describe "caching" do
    it "evaluates a formula reached by two branches only once" do
      publish("base", "salary", variables: [attribute("salary")])
      publish("b", "@base")
      publish("c", "@base")
      a = publish("a", "@b + @c")
      allow(ActsAsCalculator::ResolveVariables).to receive(:call).and_call_original

      expect(evaluate(a).value).to eq(BigDecimal("2000"))
      expect(ActsAsCalculator::ResolveVariables).to have_received(:call).exactly(4).times
    end

    it "starts a fresh cache per chain, so a later call sees current data" do
      publish("gross", "salary", variables: [attribute("salary")])
      net = publish("net", "@gross")

      first = evaluate(net).value
      employee.update!(salary: 2000)

      expect([first, evaluate(net).value]).to eq([BigDecimal("1000"), BigDecimal("2000")])
    end

    it "leaves no cache behind on the thread once the chain ends" do
      net = publish("net", "1 + 1")

      evaluate(net)

      expect(ActsAsCalculator::FormulaCallCache.current).to be_nil
    end

    it "clears the cache even when the chain raises" do
      publish("gross", "salary")
      net = publish("net", "@gross")

      expect { evaluate(net) }.to raise_error(ActsAsCalculator::FormulaCallError)
      expect(ActsAsCalculator::FormulaCallCache.current).to be_nil
    end
  end

  describe "failing fast" do
    it "names the chain when a called formula cannot resolve a variable" do
      publish("gross", "bonus", variables: [{ name: "bonus", source_type: "context" }])
      net = publish("net", "@gross")

      expect { evaluate(net) }
        .to raise_error(ActsAsCalculator::FormulaCallError, /net -> gross failed: .*bonus/)
    end

    it "names the whole chain when the failure is several levels down" do
      publish("c", "bonus", variables: [{ name: "bonus", source_type: "context" }])
      publish("b", "@c")
      a = publish("a", "@b")

      expect { evaluate(a) }
        .to raise_error(ActsAsCalculator::FormulaCallError, /a -> b -> c failed/)
    end

    it "reports a callee that has no version covering the date" do
      publish("tax", "100", effective_from: Date.new(2030, 1, 1))
      net = publish("net", "@tax")

      expect { evaluate(net) }
        .to raise_error(ActsAsCalculator::FormulaCallError, /net -> tax failed: .*no active version/)
    end

    it "reports an arithmetic failure inside a callee" do
      publish("gross", "salary / 0", variables: [attribute("salary")])
      net = publish("net", "@gross")

      expect { evaluate(net) }
        .to raise_error(ActsAsCalculator::FormulaCallError, /net -> gross failed/)
    end

    it "stops a cycle that reached evaluation instead of recursing forever" do
      a = build_formula(key: "a", scope: "payroll")
      b = build_formula(key: "b", scope: "payroll")
      build_version(formula: b, expression: "@a")
      version = build_version(formula: a, expression: "@b")

      expect { evaluate(version) }
        .to raise_error(ActsAsCalculator::FormulaCallCycleError, /a -> b -> a/)
    end
  end

  describe "the breakdown" do
    it "keeps the authored expression and records what each call returned" do
      publish("gross", "salary", variables: [attribute("salary")])
      net = publish("net", "@gross * 0.8")

      breakdown = evaluate(net).breakdown

      expect(breakdown[:expression]).to eq("@gross * 0.8")
      expect(breakdown[:evaluated_expression]).to eq("__call_0 * 0.8")
      expect(breakdown[:calls].map { |call| [call[:key], call[:value]] }).to eq([["gross", BigDecimal("1000")]])
    end

    it "adds no call keys to a formula that calls nothing" do
      version = publish("net", "1 + 1")

      expect(evaluate(version).breakdown.keys).to contain_exactly(:expression, :inputs, :value)
    end
  end
end
