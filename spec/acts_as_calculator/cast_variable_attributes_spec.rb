# frozen_string_literal: true

RSpec.describe ActsAsCalculator::CastVariableAttributes do
  it "applies the declared defaults to a bare name" do
    expect(described_class.({ "name" => "salary" }))
      .to eq(name: "salary", source_type: "context", source_config: {}, required: true)
  end

  it "reads symbol keys the same as string ones, so JSON and Ruby callers agree" do
    expect(described_class.({ name: "salary", source_type: :attribute }))
      .to include(name: "salary", source_type: "attribute")
  end

  it "only treats an explicit false as not required" do
    expect(described_class.({ "name" => "salary", "required" => false })).to include(required: false)
    expect(described_class.({ "name" => "salary", "required" => nil })).to include(required: true)
  end

  it "casts source_config into something the json column can hold" do
    expect(described_class.({ "name" => "tax", "source_config" => { table: :federal, using: :salary } }))
      .to include(source_config: { "table" => "federal", "using" => "salary" })
  end

  it "is idempotent, so a caller may hand back its own output" do
    once = described_class.({ "name" => "salary", "source_type" => "attribute" })

    expect(described_class.(once)).to eq(once)
  end
end
