# frozen_string_literal: true

RSpec.describe "Formula versions API", type: :request do
  before { enable_api! }

  let(:formula) { build_formula(key: "net_pay", scope: "payroll") }

  def post_version(attributes)
    api_post("/formulas/#{formula.id}/versions", version: attributes)
  end

  describe "GET /formulas/:formula_id/versions" do
    it "lists them in version order" do
      build_version(formula:, expression: "1 + 1", effective_from: Date.new(2026, 1, 1),
                    effective_to: Date.new(2026, 5, 31))
      build_version(formula:, expression: "2 + 2", effective_from: Date.new(2026, 6, 1))

      api_get("/formulas/#{formula.id}/versions")

      expect(json_body["versions"].map { |version| version["version_number"] }).to eq([1, 2])
    end
  end

  describe "GET /formulas/:formula_id/versions/:id" do
    it "includes the declared variables" do
      version = build_version(formula:)
      build_variable(version:, name: "salary", source_type: "attribute")

      api_get("/formulas/#{formula.id}/versions/#{version.id}")

      expect(json_body["version"]["variables"])
        .to contain_exactly(hash_including("name" => "salary", "source_type" => "attribute", "required" => true))
    end

    it "404s for a version belonging to a different formula" do
      other = build_version(formula: build_formula(key: "bonus"))

      api_get("/formulas/#{formula.id}/versions/#{other.id}")

      expect(last_response.status).to eq(404)
    end
  end

  describe "POST /formulas/:formula_id/versions" do
    it "publishes the first version with its variables" do
      post_version(expression: "salary - tax", effective_from: "2026-01-01", change_note: "2026 rates",
                   variables: [{ name: "salary", source_type: "attribute" },
                               { name: "tax", source_type: "lookup",
                                 source_config: { table: "federal", using: "salary" } }])

      expect(last_response.status).to eq(201)
      expect(json_body["version"]).to include("version_number" => 1, "status" => "active",
                                              "expression" => "salary - tax")
      expect(json_body["version"]["variables"].map { |variable| variable["name"] }).to eq(%w[salary tax])
    end

    it "applies the declared defaults to a variable, same as the JSON import does" do
      post_version(expression: "1 + 1", effective_from: "2026-01-01", variables: [{ name: "bonus" }])

      expect(json_body["version"]["variables"].first)
        .to include("source_type" => "context", "source_config" => {}, "required" => true)
    end

    it "numbers versions past whatever already exists" do
      build_version(formula:, effective_from: Date.new(2026, 1, 1), status: "draft")

      post_version(expression: "1 + 1", effective_from: "2026-01-01", status: "draft")

      expect(json_body["version"]["version_number"]).to eq(2)
    end

    it "supersedes the version in force rather than overlapping it" do
      incumbent = build_version(formula:, expression: "old", effective_from: Date.new(2026, 1, 1))

      post_version(expression: "new", effective_from: "2026-06-01")

      expect(last_response.status).to eq(201)
      expect(incumbent.reload).to have_attributes(status: "active", expression: "old",
                                                  effective_to: Date.new(2026, 5, 31))
    end

    it "409s instead of creating a gap when the newcomer does not cover the incumbent's tail" do
      incumbent = build_version(formula:, expression: "old", effective_from: Date.new(2026, 1, 1))

      post_version(expression: "new", effective_from: "2026-06-01", effective_to: "2026-08-01")

      expect(last_response.status).to eq(409)
      expect(json_body.dig("error", "type")).to eq("ActsAsCalculator::PartialSupersedeError")
      expect(error_message).to match(/would leave 2026-08-02\.\.open with no active version/)
      expect(incumbent.reload.effective_to).to be_nil
      expect(formula.versions.count).to eq(1)
    end

    it "leaves an existing active version alone when the new one is only a draft" do
      incumbent = build_version(formula:, effective_from: Date.new(2026, 1, 1))

      post_version(expression: "draft", effective_from: "2026-06-01", status: "draft")

      expect(last_response.status).to eq(201)
      expect(incumbent.reload.effective_to).to be_nil
    end

    it "422s on a missing expression" do
      post_version(effective_from: "2026-01-01")

      expect(last_response.status).to eq(422)
      expect(json_body.dig("error", "details", "expression")).to include("can't be blank")
    end

    it "422s on an unparseable effective_from" do
      post_version(expression: "1 + 1", effective_from: "the first of never")

      expect(last_response.status).to eq(422)
      expect(error_message).to match(/cannot cast/)
    end

    it "422s on a variable whose source_type is not one the resolver knows" do
      post_version(expression: "1 + 1", effective_from: "2026-01-01",
                   variables: [{ name: "salary", source_type: "telepathy" }])

      expect(last_response.status).to eq(422)
      expect(json_body.dig("error", "details", "source_type")).to include("is not included in the list")
    end

    it "rolls the version back when one of its variables is rejected" do
      expect do
        post_version(expression: "1 + 1", effective_from: "2026-01-01",
                     variables: [{ name: "salary" }, { name: "salary" }])
      end.not_to change(ActsAsCalculator::FormulaVersion, :count)

      expect(last_response.status).to eq(422)
    end

    it "404s when the formula does not exist" do
      api_post("/formulas/0/versions", version: { expression: "1 + 1", effective_from: "2026-01-01" })

      expect(last_response.status).to eq(404)
    end
  end
end
