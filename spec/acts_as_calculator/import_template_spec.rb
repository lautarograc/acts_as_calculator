# frozen_string_literal: true

RSpec.describe ActsAsCalculator::ImportTemplate do
  let(:declared) do
    { "key" => "payslip", "scope" => "payroll", "format" => "text", "body" => "Net: {{ result }}" }
  end

  def import(attributes = declared)
    described_class.(attributes:)
  end

  def versions
    ActsAsCalculator::Template.where(key: "payslip", scope: "payroll").order(:version_number)
  end

  it "creates version 1, published" do
    outcome = import

    expect(outcome).to have_attributes(status: :created, kind: :template, detail: "version 1")
    expect(versions.sole).to have_attributes(version_number: 1, current: true, format: "text")
  end

  it "defaults the format to html" do
    import(declared.except("format"))

    expect(versions.sole.format).to eq("html")
  end

  it "raises when the body is missing" do
    expect { import(declared.except("body")) }.to raise_error(ActsAsCalculator::ImportError, /has no body/)
  end

  it "is a no-op when the current version already has that body and format" do
    import

    expect(import.status).to eq(:skipped)
    expect(versions.count).to eq(1)
  end

  it "adds a new published version when the body changes" do
    import
    outcome = import({ **declared, "body" => "Gross: {{ result }}" })

    expect(outcome).to have_attributes(status: :updated, detail: "version 2")
    expect(versions.map(&:current)).to eq([false, true])
    expect(versions.map(&:body)).to eq(["Net: {{ result }}", "Gross: {{ result }}"])
  end

  it "adds a new version when only the format changes" do
    import

    expect(import({ **declared, "format" => "html" }).status).to eq(:updated)
  end

  it "keeps every superseded version, so PromoteTemplate can roll back to one" do
    import
    import({ **declared, "body" => "Gross: {{ result }}" })
    ActsAsCalculator::PromoteTemplate.(template: versions.first)

    expect(versions.map(&:current)).to eq([true, false])
  end

  it "republishes the file's content after a rollback, as a new version" do
    import
    import({ **declared, "body" => "Gross: {{ result }}" })
    ActsAsCalculator::PromoteTemplate.(template: versions.first)

    expect(import({ **declared, "body" => "Gross: {{ result }}" }).status).to eq(:updated)
    expect(versions.count).to eq(3)
    expect(ActsAsCalculator::ResolveTemplate.(key: "payslip", scope: "payroll").body).to eq("Gross: {{ result }}")
  end

  describe "owner scoping" do
    let(:department) { SpecDepartment.create!(name: "Engineering") }
    let(:owned) { { **declared, "owner" => { "type" => "SpecDepartment", "id" => department.id } } }

    it "publishes the owned template without demoting the global one" do
      import
      expect(import(owned).status).to eq(:created)

      expect(ActsAsCalculator::Template.global.find_by!(key: "payslip", scope: "payroll").current).to be(true)
      expect(ActsAsCalculator::Template.owned_by(department).find_by!(key: "payslip", scope: "payroll").current)
        .to be(true)
    end

    it "is idempotent per owner" do
      import(owned)

      expect(import(owned).status).to eq(:skipped)
    end
  end
end
