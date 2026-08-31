# frozen_string_literal: true

RSpec.describe "Templates API", type: :request do
  before { enable_api! }

  describe "GET /templates" do
    it "lists every version, saying which one is current" do
      build_template(key: "payslip", body: "v1")
      build_template(key: "payslip", body: "v2")

      api_get("/templates", key: "payslip")

      expect(json_body["templates"].map { |template| template.values_at("version_number", "current") })
        .to eq([[1, false], [2, true]])
    end

    it "narrows to the published version on request" do
      build_template(key: "payslip", body: "v1")
      build_template(key: "payslip", body: "v2")

      api_get("/templates", key: "payslip", current: "true")

      expect(json_body["templates"].map { |template| template["body"] }).to eq(["v2"])
    end
  end

  describe "GET /templates/:id" do
    it "returns the Liquid source" do
      template = build_template(body: "Net: {{ result.value }}")

      api_get("/templates/#{template.id}")

      expect(json_body["template"]).to include("body" => "Net: {{ result.value }}", "format" => "html")
    end

    it "404s for an id that isn't there" do
      api_get("/templates/0")

      expect(last_response.status).to eq(404)
    end
  end

  describe "POST /templates" do
    it "publishes a first version" do
      api_post("/templates", template: { key: "payslip", scope: "payroll", format: "text", body: "Net: {{ net }}" })

      expect(last_response.status).to eq(201)
      expect(json_body["template"]).to include("version_number" => 1, "current" => true, "format" => "text")
    end

    it "publishes a new version instead of rewriting the live one" do
      first = build_template(key: "payslip", body: "old")

      api_post("/templates", template: { key: "payslip", scope: "payroll", body: "new" })

      expect(json_body["template"]).to include("version_number" => 2, "current" => true)
      expect(first.reload).to have_attributes(body: "old", current: false)
    end

    it "422s on a missing body" do
      api_post("/templates", template: { key: "payslip" })

      expect(last_response.status).to eq(422)
      expect(json_body.dig("error", "details", "body")).to include("can't be blank")
    end

    it "422s on a format the renderer doesn't know" do
      api_post("/templates", template: { key: "payslip", body: "hi", format: "pdf" })

      expect(last_response.status).to eq(422)
      expect(json_body.dig("error", "details", "format")).to include("is not included in the list")
    end
  end

  describe "POST /templates/:id/preview" do
    it "renders the body against a supplied context and reports the format" do
      template = build_template(format: "text", body: "Net: {{ net | currency }}")

      api_post("/templates/#{template.id}/preview", context: { net: "1234.5" })

      expect(last_response.status).to eq(200)
      expect(json_body["preview"]).to eq("body" => "Net: 1,234.50", "format" => "text")
    end

    it "renders unknown variables blank rather than failing" do
      template = build_template(format: "text", body: "Net: {{ missing }}.")

      api_post("/templates/#{template.id}/preview")

      expect(json_body.dig("preview", "body")).to eq("Net: .")
    end

    it "422s on a template whose Liquid does not parse" do
      template = build_template(format: "text", body: "{% for %}")

      api_post("/templates/#{template.id}/preview")

      expect(last_response.status).to eq(422)
      expect(json_body.dig("error", "type")).to eq("ActsAsCalculator::TemplateRenderError")
    end

    it "refuses a template that tries to reach the file system" do
      template = build_template(format: "text", body: "{% include 'secrets' %}")

      api_post("/templates/#{template.id}/preview")

      expect(last_response.status).to eq(422)
    end
  end

  describe "POST /templates/:id/promote" do
    it "rolls back to an older version without deleting the newer one" do
      first = build_template(key: "payslip", body: "old")
      second = build_template(key: "payslip", body: "new")

      api_post("/templates/#{first.id}/promote")

      expect(last_response.status).to eq(200)
      expect(json_body["template"]).to include("id" => first.id, "current" => true)
      expect(second.reload.current).to be(false)
    end
  end

  describe "DELETE /templates/:id" do
    it "removes the row" do
      template = build_template

      api_delete("/templates/#{template.id}")

      expect(last_response.status).to eq(204)
      expect(ActsAsCalculator::Template.exists?(template.id)).to be(false)
    end
  end
end
