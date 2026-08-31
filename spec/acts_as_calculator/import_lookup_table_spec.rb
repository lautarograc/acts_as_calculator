# frozen_string_literal: true

RSpec.describe ActsAsCalculator::ImportLookupTable do
  let(:declared) do
    { "key" => "federal", "scope" => "payroll",
      "entries" => [{ "from" => 0, "to" => 20_000, "value" => 0.1 },
                    { "from" => 20_000, "to" => nil, "value" => 0.25 }] }
  end

  def import(attributes = declared)
    described_class.(attributes:)
  end

  def entries_of(table)
    table.entries.ordered.map { |entry| [entry.from&.to_i, entry.to&.to_i, entry.value.to_f] }
  end

  describe "when the table does not exist" do
    it "creates it with its entries, in declared order" do
      outcome = import

      table = ActsAsCalculator::LookupTable.find_by!(key: "federal", scope: "payroll")
      expect(outcome.status).to eq(:created)
      expect(entries_of(table)).to eq([[0, 20_000, 0.1], [20_000, nil, 0.25]])
    end

    it "defaults the scope" do
      import({ "key" => "federal", "entries" => [] })

      expect(ActsAsCalculator::LookupTable.find_by(key: "federal").scope).to eq(ActsAsCalculator::DEFAULT_SCOPE)
    end

    it "raises when an entry has no value" do
      expect { import({ "key" => "federal", "entries" => [{ "from" => 0 }] }) }
        .to raise_error(ActsAsCalculator::ImportError, /entry with no value/)
    end

    it "raises when there is no key" do
      expect { import({ "entries" => [] }) }.to raise_error(ActsAsCalculator::ImportError, /no key/)
    end
  end

  describe "when the table exists with identical entries" do
    it "is a no-op" do
      import
      table = ActsAsCalculator::LookupTable.find_by!(key: "federal", scope: "payroll")
      entry_ids = table.entries.ordered.pluck(:id)

      expect(import.status).to eq(:skipped)
      expect(table.entries.reload.ordered.pluck(:id)).to eq(entry_ids)
    end

    it "compares numerically, not textually — 0.10 and 0.1 are the same bracket" do
      import

      expect(import({ **declared,
                      "entries" => [{ "from" => "0", "to" => "20000.000000", "value" => "0.100000" },
                                    { "from" => 20_000, "to" => nil, "value" => 0.25 }] }).status).to eq(:skipped)
    end

    it "treats reordered entries as a change, since position is what the bands are read in" do
      import

      expect(import({ **declared, "entries" => declared["entries"].reverse }).status).to eq(:updated)
    end
  end

  describe "when the table exists with different entries" do
    let(:changed) { { **declared, "entries" => [{ "from" => 0, "to" => nil, "value" => 0.15 }] } }

    it "replaces the entries in place when nothing references it" do
      import

      expect(import(changed).status).to eq(:updated)
      table = ActsAsCalculator::LookupTable.find_by!(key: "federal", scope: "payroll")
      expect(entries_of(table)).to eq([[0, nil, 0.15]])
    end

    it "still replaces in place when only a draft version references it" do
      import
      reference_from(status: ActsAsCalculator::FormulaVersion::DRAFT)

      expect(import(changed).status).to eq(:updated)
    end

    context "when an active formula version resolves to it" do
      before do
        import
        reference_from(status: ActsAsCalculator::FormulaVersion::ACTIVE)
      end

      it "refuses to overwrite it" do
        expect { import(changed) }.to raise_error(ActsAsCalculator::LookupTableInUseError)
      end

      it "names the formula version holding it and suggests a new key" do
        expect { import(changed) }
          .to raise_error(ActsAsCalculator::LookupTableInUseError, /tax#1 \(active\).*federal_v2/m)
      end

      it "leaves every entry exactly as it was" do
        table = ActsAsCalculator::LookupTable.find_by!(key: "federal", scope: "payroll")

        expect { import(changed) }.to raise_error(ActsAsCalculator::LookupTableInUseError)
        expect(entries_of(table.reload)).to eq([[0, 20_000, 0.1], [20_000, nil, 0.25]])
      end
    end

    it "refuses when a retired version resolves to it — its runs are audited too" do
      import
      reference_from(status: ActsAsCalculator::FormulaVersion::RETIRED)

      expect { import(changed) }.to raise_error(ActsAsCalculator::LookupTableInUseError, /tax#1 \(retired\)/)
    end

    it "allows the change when the referencing formula is in another scope" do
      import
      reference_from(scope: "commerce")

      expect(import(changed).status).to eq(:updated)
    end
  end

  describe "owner scoping" do
    let(:department) { SpecDepartment.create!(name: "Engineering") }
    let(:owned) { { **declared, "owner" => { "type" => "SpecDepartment", "id" => department.id } } }

    it "creates the owned table alongside the global one rather than updating it" do
      import
      expect(import(owned).status).to eq(:created)

      expect(ActsAsCalculator::LookupTable.where(key: "federal", scope: "payroll").count).to eq(2)
    end

    it "does not let an owned import overwrite the global table" do
      import
      import({ **owned, "entries" => [{ "from" => 0, "to" => nil, "value" => 0.99 }] })

      global = ActsAsCalculator::LookupTable.global.find_by!(key: "federal", scope: "payroll")
      expect(entries_of(global)).to eq([[0, 20_000, 0.1], [20_000, nil, 0.25]])
    end

    it "refuses to overwrite an owned table shadowing the global one a global formula uses" do
      import
      import(owned)
      reference_from(status: ActsAsCalculator::FormulaVersion::ACTIVE)

      expect { import({ **owned, "entries" => [{ "from" => 0, "to" => nil, "value" => 0.99 }] }) }
        .to raise_error(ActsAsCalculator::LookupTableInUseError, /tax#1 \(active\)/)
    end
  end

  def reference_from(status: ActsAsCalculator::FormulaVersion::ACTIVE, scope: "payroll")
    formula = build_formula(key: "tax", scope:)
    version = build_version(formula:, expression: "1", status:)
    build_variable(version:, name: "rate", source_type: "lookup", source_config: { "table" => "federal" })
    version
  end
end
