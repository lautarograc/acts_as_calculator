# frozen_string_literal: true

RSpec.describe ActsAsCalculator::ImportFormula do
  let(:declared) do
    { "key" => "net_pay", "scope" => "payroll", "expression" => "salary - tax",
      "effective_from" => "2026-01-01", "effective_to" => nil, "status" => "active",
      "variables" => [{ "name" => "salary", "source_type" => "attribute" },
                      { "name" => "tax", "source_type" => "context", "required" => false }] }
  end

  def import(attributes = declared)
    described_class.(attributes:)
  end

  def formula
    ActsAsCalculator::Formula.find_by!(key: "net_pay", scope: "payroll")
  end

  describe "when the formula does not exist" do
    it "creates the formula and its first version" do
      outcome = import

      expect(outcome).to have_attributes(status: :created, kind: :formula, detail: "version 1")
      expect(formula.versions.sole).to have_attributes(
        version_number: 1, expression: "salary - tax", effective_from: Date.new(2026, 1, 1),
        effective_to: nil, status: "active"
      )
    end

    it "creates the declared variables" do
      import

      expect(formula.versions.sole.variables.order(:name).map { |v| [v.name, v.source_type, v.required] })
        .to eq([%w[salary attribute] + [true], %w[tax context] + [false]])
    end

    it "defaults status to active, scope to the gem default and variables to none" do
      described_class.(attributes: { "key" => "flat", "expression" => "1", "effective_from" => "2026-01-01" })

      version = ActsAsCalculator::Formula.find_by!(key: "flat", scope: ActsAsCalculator::DEFAULT_SCOPE).versions.sole
      expect(version).to have_attributes(status: "active", version_number: 1)
      expect(version.variables).to be_empty
    end

    it "records the change_note when given" do
      import({ **declared, "change_note" => "2026 rates" })

      expect(formula.versions.sole.change_note).to eq("2026 rates")
    end

    it "raises when the expression is missing" do
      expect { import(declared.except("expression")) }
        .to raise_error(ActsAsCalculator::ImportError, /has no expression/)
    end

    it "raises when effective_from is missing" do
      expect { import(declared.except("effective_from")) }
        .to raise_error(ActsAsCalculator::ImportError, /has no effective_from/)
    end

    it "raises when a variable has no name" do
      expect { import({ **declared, "variables" => [{ "source_type" => "context" }] }) }
        .to raise_error(ActsAsCalculator::ImportError, /variable with no name/)
    end
  end

  describe "when an identical version already exists" do
    before { import }

    it "is a no-op" do
      expect(import.status).to eq(:skipped)
      expect(formula.versions.count).to eq(1)
    end

    it "ignores the order variables are declared in" do
      expect(import({ **declared, "variables" => declared["variables"].reverse }).status).to eq(:skipped)
    end

    it "treats an omitted effective_to as the null it stored" do
      expect(import(declared.except("effective_to")).status).to eq(:skipped)
    end

    it "matches on content, not status — publishing a draft is not new content" do
      expect(import({ **declared, "status" => "draft" }).status).to eq(:skipped)
    end

    it "matches a version that is no longer the active one" do
      import({ **declared, "expression" => "salary" })

      expect(import.status).to eq(:skipped)
      expect(formula.versions.count).to eq(2)
    end
  end

  describe "when the content differs" do
    before { import }

    it "adds a new version rather than editing the old one" do
      outcome = import({ **declared, "expression" => "salary - tax - pension" })

      expect(outcome).to have_attributes(status: :updated, detail: "version 2")
      expect(formula.versions.order(:version_number).map(&:expression))
        .to eq(["salary - tax", "salary - tax - pension"])
    end

    it "bumps the version when only the variables changed" do
      import({ **declared, "variables" => [{ "name" => "salary", "source_type" => "method" }] })

      expect(formula.versions.count).to eq(2)
    end

    it "bumps the version when only required changed" do
      changed = declared["variables"].map { |variable| { **variable, "required" => true } }

      expect(import({ **declared, "variables" => changed }).status).to eq(:updated)
    end

    it "bumps the version when only source_config changed" do
      changed = [{ "name" => "salary", "source_type" => "attribute", "source_config" => { "attribute" => "base" } },
                 declared["variables"].last]

      expect(import({ **declared, "variables" => changed }).status).to eq(:updated)
    end

    it "retires the version it replaces rather than rewriting it" do
      first = formula.versions.sole
      import({ **declared, "expression" => "salary" })

      expect(first.reload).to have_attributes(expression: "salary - tax", status: "retired")
      expect(formula.versions.active.sole.expression).to eq("salary")
    end

    it "closes out the incumbent when the new version starts later" do
      first = formula.versions.sole
      import({ **declared, "expression" => "salary", "effective_from" => "2026-07-01" })

      expect(first.reload).to have_attributes(status: "active", effective_to: Date.new(2026, 6, 30))
    end

    it "leaves the incumbent alone when the newcomer is only a draft" do
      first = formula.versions.sole
      import({ **declared, "expression" => "salary", "status" => "draft" })

      expect(first.reload.status).to eq("active")
    end

    it "reuses the same formula row" do
      import({ **declared, "expression" => "salary" })

      expect(ActsAsCalculator::Formula.where(key: "net_pay", scope: "payroll").count).to eq(1)
    end

    it "refuses a bounded version that would leave the incumbent's tail uncovered" do
      expect { import({ **declared, "expression" => "salary", "effective_to" => "2026-06-30" }) }
        .to raise_error(ActsAsCalculator::PartialSupersedeError, /2026-07-01\.\.open with no active version/)
    end

    it "keeps the date the refused import would have orphaned resolvable" do
      expect { import({ **declared, "expression" => "salary", "effective_to" => "2026-06-30" }) }
        .to raise_error(ActsAsCalculator::PartialSupersedeError)

      expect(ActsAsCalculator::ResolveFormulaVersion.(key: "net_pay", scope: "payroll",
                                                      as_of: Date.new(2026, 10, 1)).expression)
        .to eq("salary - tax")
    end

    it "accepts the bounded version once something else has taken over the tail" do
      import({ **declared, "expression" => "salary * 2", "effective_from" => "2026-07-01" })
      import({ **declared, "expression" => "salary", "effective_to" => "2026-06-30" })

      expect(formula.versions.active.order(:effective_from).map { |v| [v.expression, v.effective_to] })
        .to eq([["salary", Date.new(2026, 6, 30)], ["salary * 2", nil]])
    end
  end

  describe "owner scoping" do
    let(:department) { SpecDepartment.create!(name: "Engineering") }
    let(:owned) { { **declared, "owner" => { "type" => "SpecDepartment", "id" => department.id } } }

    it "creates a separate formula rather than versioning the global one" do
      import
      expect(import(owned).status).to eq(:created)

      expect(ActsAsCalculator::Formula.where(key: "net_pay", scope: "payroll").count).to eq(2)
      expect(ActsAsCalculator::Formula.global.find_by!(key: "net_pay", scope: "payroll").versions.count).to eq(1)
    end

    it "is idempotent per owner" do
      import(owned)

      expect(import(owned).status).to eq(:skipped)
    end
  end

  describe "formula calls" do
    let(:calling) do
      { "key" => "take_home", "scope" => "payroll", "expression" => "@net_pay * 0.9",
        "effective_from" => "2026-01-01" }
    end

    def version_of(key)
      ActsAsCalculator::Formula.find_by!(key:, scope: "payroll").versions.order(:version_number).last
    end

    it "records the calls the expression makes" do
      import
      import(calling)

      expect(version_of("take_home").formula_calls)
        .to eq("calls" => [{ "key" => "net_pay", "version_id" => nil }])
    end

    it "records an empty document for a formula that calls nothing" do
      import

      expect(version_of("net_pay").formula_calls).to eq("calls" => [])
    end

    it "records a version pin declared in the formula_calls field" do
      import
      pinned = version_of("net_pay")
      import({ **calling, "formula_calls" => { "calls" => [{ "key" => "net_pay", "version_id" => pinned.id }] } })

      expect(version_of("take_home").formula_calls)
        .to eq("calls" => [{ "key" => "net_pay", "version_id" => pinned.id }])
    end

    it "accepts formula_calls as a bare list too" do
      import
      import({ **calling, "formula_calls" => [{ "key" => "net_pay", "version_id" => version_of("net_pay").id }] })

      expect(version_of("take_home").formula_calls.fetch("calls").sole["version_id"])
        .to eq(version_of("net_pay").id)
    end

    it "is idempotent for a formula that calls another" do
      import
      import(calling)

      expect(import(calling).status).to eq(:skipped)
    end

    it "publishes a new version when only the pin changed" do
      import
      first = version_of("net_pay")
      import(calling)

      outcome = import({ **calling,
                         "formula_calls" => { "calls" => [{ "key" => "net_pay", "version_id" => first.id }] } })

      expect(outcome.status).to eq(:updated)
      expect(version_of("take_home").version_number).to eq(2)
    end

    it "refuses an expression that calls a formula the file never defines" do
      expect { import({ **calling, "expression" => "@nowhere * 2" }) }
        .to raise_error(ActsAsCalculator::FormulaNotFoundError, /@nowhere/)
    end

    it "refuses an import that would close a cycle" do
      import
      import(calling)

      expect { import({ **declared, "expression" => "@take_home", "effective_from" => "2027-01-01" }) }
        .to raise_error(ActsAsCalculator::FormulaCallCycleError, /net_pay -> take_home -> net_pay/)
    end

    it "reports a bad reference as a failed outcome rather than aborting the whole file" do
      summary = ActsAsCalculator::ImportDefinitions.(
        data: { "formulas" => [{ **calling, "expression" => "@nowhere" }, declared] }
      )

      expect(summary.outcomes.map(&:status)).to eq(%i[failed created])
      expect(summary.outcomes.first.detail).to match(/@nowhere/)
    end
  end
end
