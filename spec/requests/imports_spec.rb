# frozen_string_literal: true

RSpec.describe "Import API", type: :request do
  before { enable_api! }

  let(:definitions) do
    { lookup_tables: [{ key: "federal", scope: "payroll",
                        entries: [{ from: 0, to: 20_000, value: 0.1 },
                                  { from: 20_000, to: nil, value: 0.25 }] }],
      formulas: [{ key: "net_pay", scope: "payroll", expression: "salary - salary * federal",
                   effective_from: "2026-01-01",
                   variables: [{ name: "salary", source_type: "attribute" },
                               { name: "federal", source_type: "lookup",
                                 source_config: { table: "federal", using: "salary" } }] }],
      templates: [{ key: "payslip", scope: "payroll", format: "text",
                    body: "Net: {{ result.value }}" }] }
  end

  it "imports a whole document and reports what each entry did" do
    api_post("/import", definitions)

    expect(last_response.status).to eq(200)
    expect(json_body).to include("success" => true, "source" => "inline data")
    expect(json_body["counts"]).to eq("created" => 3, "updated" => 0, "skipped" => 0, "failed" => 0)
    expect(json_body["outcomes"].map { |outcome| outcome["kind"] }).to eq(%w[lookup_table formula template])
    expect(ActsAsCalculator::Formula.find_by(key: "net_pay", scope: "payroll")).to be_present
  end

  it "is a no-op the second time" do
    api_post("/import", definitions)
    api_post("/import", definitions)

    expect(json_body["counts"]).to eq("created" => 0, "updated" => 0, "skipped" => 3, "failed" => 0)
  end

  it "adds a version rather than editing one when an expression changes" do
    api_post("/import", definitions)
    changed = definitions.merge(formulas: [definitions[:formulas].first.merge(expression: "salary")])

    api_post("/import", changed)

    expect(json_body["counts"]).to include("updated" => 1)
    expect(ActsAsCalculator::Formula.find_by(key: "net_pay").versions.pluck(:version_number, :expression))
      .to eq([[1, "salary - salary * federal"], [2, "salary"]])
  end

  it "422s and names the failing entry when one entry fails, keeping the others" do
    api_post("/import", definitions.merge(formulas: [definitions[:formulas].first.merge(expression: nil)]))

    expect(last_response.status).to eq(422)
    expect(json_body["success"]).to be(false)
    expect(json_body["outcomes"]).to include(hash_including("kind" => "formula", "status" => "failed",
                                                            "key" => "net_pay"))
    expect(json_body["outcomes"]).to include(hash_including("kind" => "template", "status" => "created"))
    expect(ActsAsCalculator::Template.find_by(key: "payslip")).to be_present
  end

  it "422s on a section it does not recognise rather than importing nothing quietly" do
    api_post("/import", formulae: [])

    expect(last_response.status).to eq(422)
    expect(error_message).to match(/unknown import section/)
  end

  it "422s on an empty body rather than reporting an empty success" do
    api_post("/import")

    expect(last_response.status).to eq(422)
    expect(error_message).to match(/no import document in the request body/)
  end
end
