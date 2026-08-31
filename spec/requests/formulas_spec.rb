# frozen_string_literal: true

RSpec.describe "Formulas API", type: :request do
  before { enable_api! }

  describe "GET /formulas" do
    it "lists identity, not content" do
      build_version(formula: build_formula(key: "net_pay", scope: "payroll"))

      api_get("/formulas")

      expect(last_response.status).to eq(200)
      expect(json_body["formulas"].first).to include("key" => "net_pay", "scope" => "payroll")
      expect(json_body["formulas"].first).not_to have_key("versions")
    end

    it "filters by key and scope" do
      build_formula(key: "net_pay", scope: "payroll")
      build_formula(key: "net_pay", scope: "commerce")

      api_get("/formulas", scope: "commerce")

      expect(json_body["formulas"].map { |formula| formula["scope"] }).to eq(["commerce"])
    end
  end

  describe "GET /formulas/:id" do
    it "includes the version history" do
      formula = build_formula
      build_version(formula:, expression: "1 + 1", effective_from: Date.new(2026, 1, 1),
                    effective_to: Date.new(2026, 5, 31))
      build_version(formula:, expression: "2 + 2", effective_from: Date.new(2026, 6, 1))

      api_get("/formulas/#{formula.id}")

      expect(json_body["formula"]["versions"].map { |version| version["expression"] }).to eq(["1 + 1", "2 + 2"])
    end

    it "404s for an id that isn't there" do
      api_get("/formulas/0")

      expect(last_response.status).to eq(404)
      expect(json_body.dig("error", "type")).to eq("ActiveRecord::RecordNotFound")
    end
  end

  describe "POST /formulas" do
    it "creates a formula and echoes it back" do
      api_post("/formulas", formula: { key: "net_pay", scope: "payroll" })

      expect(last_response.status).to eq(201)
      expect(json_body["formula"]).to include("key" => "net_pay", "scope" => "payroll")
      expect(ActsAsCalculator::Formula.find(json_body["formula"]["id"]).key).to eq("net_pay")
    end

    it "falls back to the default scope rather than inventing one" do
      api_post("/formulas", formula: { key: "net_pay" })

      expect(json_body["formula"]["scope"]).to eq(ActsAsCalculator::DEFAULT_SCOPE)
    end

    it "422s with the model's own messages when validation fails" do
      api_post("/formulas", formula: { scope: "payroll" })

      expect(last_response.status).to eq(422)
      expect(json_body.dig("error", "details", "key")).to include("can't be blank")
    end

    it "422s on a duplicate within a scope but allows the same key in another" do
      build_formula(key: "net_pay", scope: "payroll")

      api_post("/formulas", formula: { key: "net_pay", scope: "payroll" })
      expect(last_response.status).to eq(422)

      api_post("/formulas", formula: { key: "net_pay", scope: "commerce" })
      expect(last_response.status).to eq(201)
    end

    it "scopes to an owner when one is given, using the same reference shape as JSON import" do
      department = SpecDepartment.create!(name: "Engineering")

      api_post("/formulas", formula: { key: "net_pay", scope: "payroll",
                                       owner: { type: "SpecDepartment", id: department.id } })

      expect(last_response.status).to eq(201)
      expect(json_body["formula"]).to include("owner_type" => "SpecDepartment", "owner_id" => department.id)
    end

    it "refuses an owner type that is not an ActiveRecord model" do
      api_post("/formulas", formula: { key: "net_pay", owner: { type: "Kernel", id: 1 } })

      expect(last_response.status).to eq(422)
      expect(error_message).to match(/not an ActiveRecord model/)
    end

    it "400s when the formula key is missing from the body entirely" do
      api_post("/formulas", something_else: {})

      expect(last_response.status).to eq(400)
      expect(json_body.dig("error", "type")).to eq("ActionController::ParameterMissing")
    end
  end

  describe "PATCH /formulas/:id" do
    it "updates only what was sent" do
      formula = build_formula(key: "net_pay", scope: "payroll")

      api_patch("/formulas/#{formula.id}", formula: { key: "take_home" })

      expect(last_response.status).to eq(200)
      expect(formula.reload).to have_attributes(key: "take_home", scope: "payroll")
    end
  end

  describe "DELETE /formulas/:id" do
    it "deletes a formula nothing has calculated against" do
      formula = build_formula

      api_delete("/formulas/#{formula.id}")

      expect(last_response.status).to eq(204)
      expect(ActsAsCalculator::Formula.exists?(formula.id)).to be(false)
    end

    it "409s rather than deleting a formula whose versions have runs" do
      version = build_version
      ActsAsCalculator::Run.create!(calculable: build_employee, formula_version: version,
                                    as_of_date: Date.new(2026, 1, 1), inputs: {}, breakdown: {}, result: 1)

      api_delete("/formulas/#{version.formula_id}")

      expect(last_response.status).to eq(409)
      expect(ActsAsCalculator::Formula.exists?(version.formula_id)).to be(true)
    end
  end
end
