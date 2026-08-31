# frozen_string_literal: true

RSpec.describe ActsAsCalculator::Template do
  it "defaults to html at version 1" do
    template = described_class.create!(key: "payslip", scope: "payroll", body: "<p>{{ result }}</p>")

    expect(template.format).to eq("html")
    expect(template.version_number).to eq(1)
  end

  it "rejects a format other than html or text" do
    expect(described_class.new(key: "k", scope: "s", body: "b", format: "pdf")).not_to be_valid
  end

  it "keeps a version history under one key" do
    build_template(version_number: 1, body: "v1")
    build_template(version_number: 2, body: "v2")

    expect(described_class.latest_first.first.body).to eq("v2")
  end

  it "rejects a duplicate version number under the same key, scope and owner" do
    build_template(version_number: 1)

    expect(described_class.new(key: "payslip", scope: "payroll", body: "x", version_number: 1)).not_to be_valid
  end

  it "allows the same key and version under a different owner" do
    build_template(version_number: 1)
    department = SpecDepartment.create!(name: "Engineering")

    expect(described_class.new(key: "payslip", scope: "payroll", body: "x", owner: department)).to be_valid
  end

  it "is presentation only — no effective dating" do
    expect(described_class.column_names).not_to include("effective_from", "effective_to")
  end

  describe "the current version flag" do
    it "publishes a newly authored version" do
      expect(build_template.current).to be(true)
    end

    it "demotes the version it replaces instead of deleting it" do
      first = build_template(body: "v1")
      second = build_template(body: "v2")

      expect([first.reload.current, second.current]).to eq([false, true])
      expect(described_class.count).to eq(2)
    end

    it "leaves exactly one current version per key, scope and owner" do
      3.times { |n| build_template(body: "v#{n}") }

      expect(described_class.current.count).to eq(1)
    end

    it "lets a caller stage a version without publishing it" do
      live = build_template(body: "v1")
      staged = build_template(body: "v2", current: false)

      expect([live.reload.current, staged.current]).to eq([true, false])
    end

    it "does not demote another owner's current version" do
      global = build_template
      department = SpecDepartment.create!(name: "Engineering")
      build_template(owner: department)

      expect(global.reload.current).to be(true)
    end

    it "is enforced by the database, not only by the validation" do
      first = build_template(body: "v1")
      build_template(body: "v2")

      expect { described_class.where(id: first.id).update_all(current: true) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "refuses a second current version flipped on directly rather than promoted" do
      build_template(body: "v1")
      staged = build_template(body: "v2", current: false)

      staged.current = true

      expect(staged).not_to be_valid
      expect(staged.errors[:current].first).to match(/PromoteTemplate/)
    end
  end

  describe "#next_version_number" do
    it "starts at one and follows the highest version under the same key" do
      expect(build_template.version_number).to eq(1)
      expect(build_template.version_number).to eq(2)
    end
  end
end
