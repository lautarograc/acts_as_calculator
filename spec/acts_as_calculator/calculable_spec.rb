# frozen_string_literal: true

RSpec.describe ActsAsCalculator::Calculable do
  let(:employee) { build_employee(salary: 1000) }

  def declare_net_pay(expression: "salary * 2", **overrides)
    version = build_version(formula: build_formula(key: "net_pay", scope: "payroll"), expression:, **overrides)
    build_variable(version:, name: "salary", source_type: "attribute")
    version
  end

  describe "the calculator_scope macro" do
    it "namespaces every lookup the host model makes" do
      expect(SpecEmployee.calculator_scope_name).to eq("payroll")
    end

    it "defaults to the global scope when the host doesn't set one" do
      expect(SpecOrder.calculator_scope_name).to eq(ActsAsCalculator::DEFAULT_SCOPE)
    end

    it "does not leak between host models" do
      expect(SpecOrder.calculator_scope_name).not_to eq(SpecEmployee.calculator_scope_name)
    end
  end

  describe "#calculate" do
    it "takes the formula key positionally, as Aggregation requires" do
      declare_net_pay

      expect(employee.calculate("net_pay").value).to eq(BigDecimal("2000"))
    end

    it "returns a core Result carrying the version and date it used" do
      version = declare_net_pay

      result = employee.calculate("net_pay", as_of: Date.new(2026, 6, 1))

      expect(result).to be_a(ActsAsCalculator::Result)
      expect(result.formula_version).to eq(version)
      expect(result.as_of).to eq(Date.new(2026, 6, 1))
    end

    it "passes unrecognised keywords through as calculation context" do
      version = build_version(formula: build_formula(key: "net_pay", scope: "payroll"), expression: "bonus * 2")
      build_variable(version:, name: "bonus", source_type: "context")

      expect(employee.calculate("net_pay", bonus: 50).value).to eq(BigDecimal("100"))
    end

    it "writes exactly one audit row" do
      declare_net_pay

      expect { employee.calculate("net_pay") }.to change(ActsAsCalculator::Run, :count).by(1)
    end

    it "writes nothing under dry_run" do
      declare_net_pay

      expect { employee.calculate("net_pay", dry_run: true) }.not_to change(ActsAsCalculator::Run, :count)
    end

    it "lets a caller override the model's scope for one call" do
      version = build_version(formula: build_formula(key: "net_pay", scope: "commerce"), expression: "salary * 3")
      build_variable(version:, name: "salary", source_type: "attribute")

      expect(employee.calculate("net_pay", scope: "commerce", dry_run: true).value).to eq(BigDecimal("3000"))
    end

    it "uses the host's calculator_owner to reach an owner-specific formula" do
      department = SpecDepartment.create!(name: "Engineering")
      declare_net_pay
      owned = build_version(formula: build_formula(key: "net_pay", scope: "payroll", owner: department),
                            expression: "salary * 10")
      build_variable(version: owned, name: "salary", source_type: "attribute")
      tenant = build_employee(salary: 1000, department:, model: SpecTenantEmployee)

      expect(tenant.calculate("net_pay", dry_run: true).value).to eq(BigDecimal("10000"))
    end

    it "defaults calculator_owner to nil so an unmodified host stays global" do
      expect(employee.calculator_owner).to be_nil
    end
  end

  describe "#calculate_as_of" do
    it "replays the version in force on that date" do
      formula = build_formula(key: "net_pay", scope: "payroll")
      old = build_version(formula:, expression: "salary * 1", effective_from: Date.new(2026, 1, 1),
                          effective_to: Date.new(2026, 6, 30))
      build_variable(version: old, name: "salary", source_type: "attribute")
      current = build_version(formula:, expression: "salary * 2", effective_from: Date.new(2026, 7, 1))
      build_variable(version: current, name: "salary", source_type: "attribute")

      expect(employee.calculate_as_of("net_pay", Date.new(2026, 3, 1)).value).to eq(BigDecimal("1000"))
    end

    it "raises when nothing was in force then" do
      declare_net_pay(effective_from: Date.new(2026, 1, 1))

      expect { employee.calculate_as_of("net_pay", Date.new(2020, 1, 1)) }
        .to raise_error(ActsAsCalculator::NoEffectiveVersionError)
    end
  end

  describe "#calculation_history" do
    before { declare_net_pay }

    it "reads back this record's runs, newest first" do
      employee.calculate("net_pay", as_of: Date.new(2026, 1, 1))
      employee.calculate("net_pay", as_of: Date.new(2026, 12, 1))

      expect(employee.calculation_history.map(&:as_of_date)).to eq([Date.new(2026, 12, 1), Date.new(2026, 1, 1)])
    end

    it "does not include another record's runs" do
      build_employee(name: "Grace").calculate("net_pay")

      expect(employee.calculation_history).to be_empty
    end

    it "filters by formula key" do
      other = build_version(formula: build_formula(key: "gross_pay", scope: "payroll"), expression: "1")
      employee.calculate("net_pay")
      employee.calculate("gross_pay")

      expect(employee.calculation_history("gross_pay").map(&:formula_version)).to eq([other])
    end

    it "honours a limit" do
      3.times { |n| employee.calculate("net_pay", as_of: Date.new(2026, n + 1, 1)) }

      expect(employee.calculation_history(limit: 2).size).to eq(2)
    end
  end

  describe "#render" do
    it "is a documented Phase 3 placeholder rather than a silent no-op" do
      expect { employee.render("payslip") }.to raise_error(NotImplementedError, /Phase 3/)
    end
  end

  it "satisfies the core Aggregation contract" do
    declare_net_pay
    employees = [employee, build_employee(name: "Grace", salary: 500)]

    total = ActsAsCalculator::Aggregation.sum(employees, formula: "net_pay", as_of: Date.new(2026, 6, 1))

    expect(total).to eq(BigDecimal("3000"))
  end

  it "aggregates grouped by a host attribute" do
    declare_net_pay
    engineering = SpecDepartment.create!(name: "Engineering")
    sales = SpecDepartment.create!(name: "Sales")
    employees = [
      build_employee(salary: 100, department: engineering),
      build_employee(salary: 200, department: engineering),
      build_employee(salary: 500, department: sales)
    ]

    totals = ActsAsCalculator::Aggregation.sum(employees, formula: "net_pay", group_by: :spec_department_id)

    expect(totals).to eq(engineering.id => BigDecimal("600"), sales.id => BigDecimal("1000"))
  end
end
