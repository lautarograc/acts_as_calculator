# frozen_string_literal: true

RSpec.describe ActsAsCalculator::FormulaCall do
  describe ".build" do
    it "reads a key and an optional pin from a string-keyed hash" do
      expect(described_class.build("key" => "tax", "version_id" => 7))
        .to have_attributes(key: "tax", version_id: 7, pinned?: true)
    end

    it "reads symbol keys the same way" do
      expect(described_class.build(key: "tax")).to have_attributes(key: "tax", version_id: nil, pinned?: false)
    end

    it "treats a bare string as an unpinned key" do
      expect(described_class.build("tax")).to have_attributes(key: "tax", version_id: nil)
    end

    it "casts a version_id that arrived from JSON as a string" do
      expect(described_class.build("key" => "tax", "version_id" => "12").version_id).to eq(12)
    end

    it "treats a blank version_id as no pin rather than as zero" do
      expect(described_class.build("key" => "tax", "version_id" => "").version_id).to be_nil
    end

    it "refuses a version_id that is not an id" do
      expect { described_class.build("key" => "tax", "version_id" => "latest") }
        .to raise_error(ActsAsCalculator::FormulaCallError, /not an id/)
    end

    it "refuses an entry with no key" do
      expect { described_class.build("version_id" => 3) }
        .to raise_error(ActsAsCalculator::FormulaCallError, /no key/)
    end

    it "refuses a blank key" do
      expect { described_class.build("key" => "") }
        .to raise_error(ActsAsCalculator::FormulaCallError, /blank key/)
    end
  end

  describe ".list" do
    it "reads the stored calls document" do
      calls = described_class.list("calls" => [{ "key" => "a" }, { "key" => "b", "version_id" => 2 }])

      expect(calls.map(&:to_h))
        .to eq([{ "key" => "a", "version_id" => nil }, { "key" => "b", "version_id" => 2 }])
    end

    it "reads a bare list too, so a hand-written import stays readable" do
      expect(described_class.list([{ "key" => "a" }]).map(&:key)).to eq(["a"])
    end

    it "reads nil and the column default as no calls" do
      expect([described_class.list(nil), described_class.list({})]).to eq([[], []])
    end
  end

  describe ".pins" do
    it "collapses a document into key => version_id" do
      document = { "calls" => [{ "key" => "a", "version_id" => 5 }, { "key" => "b" }] }

      expect(described_class.pins(document)).to eq("a" => 5, "b" => nil)
    end
  end

  describe ".document" do
    it "round-trips through list" do
      calls = described_class.list("calls" => [{ "key" => "a", "version_id" => 5 }])

      expect(described_class.list(described_class.document(calls))).to eq(calls)
    end

    it "writes an empty calls list rather than a bare hash" do
      expect(described_class.document([])).to eq("calls" => [])
    end
  end

  it "describes itself with the pin, so an error message can name the exact version" do
    expect([described_class.build("key" => "a").describe,
            described_class.build("key" => "a", "version_id" => 9).describe])
      .to eq(["@a", "@a (version 9)"])
  end
end
