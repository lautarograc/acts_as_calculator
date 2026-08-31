# frozen_string_literal: true

RSpec.describe "the enable_api gate", type: :request do
  let(:engine_routes) { ActsAsCalculator::Engine.routes }

  describe "with enable_api false (the default)" do
    it "defaults to off, so a host has to opt in before anything is exposed" do
      expect(ActsAsCalculator.configuration.enable_api).to be(false)
    end

    it "does not match the route at all — the router raises, no controller is involved" do
      expect { api_get("/formulas") }.to raise_error(ActionController::RoutingError, %r{/calculator/formulas})
    end

    it "never dispatches to a controller, which is what a before_action gate could not avoid" do
      allow(ActsAsCalculator::FormulasController).to receive(:dispatch).and_call_original

      expect { api_get("/formulas") }.to raise_error(ActionController::RoutingError)
      expect(ActsAsCalculator::FormulasController).not_to have_received(:dispatch)
    end

    it "cannot recognise the path" do
      expect { engine_routes.recognize_path("/formulas", method: :get) }
        .to raise_error(ActionController::RoutingError)
    end

    it "hides every endpoint, not just the one an example happened to pick" do
      paths = [[:get, "/formulas"], [:post, "/formulas"], [:get, "/templates"],
               [:post, "/templates"], [:post, "/import"]]

      paths.each do |method, path|
        expect { engine_routes.recognize_path(path, method:) }
          .to raise_error(ActionController::RoutingError), "#{method.upcase} #{path} was reachable"
      end
    end

    it "still generates path helpers, which is why the gate is not in URL generation" do
      expect(engine_routes.url_helpers.formulas_path).to eq("/calculator/formulas")
      expect { api_get("/formulas") }.to raise_error(ActionController::RoutingError)
    end
  end

  describe "with enable_api true" do
    before { enable_api! }

    it "matches, dispatches, and answers" do
      build_formula(key: "net_pay", scope: "payroll")

      api_get("/formulas")

      expect(last_response.status).to eq(200)
      expect(json_body["formulas"].map { |formula| formula["key"] }).to eq(["net_pay"])
    end

    it "recognises the same path the disabled router could not" do
      expect(engine_routes.recognize_path("/formulas", method: :get))
        .to include(controller: "acts_as_calculator/formulas", action: "index")
    end
  end

  it "is read per request, not captured when the routes were drawn" do
    expect { api_get("/formulas") }.to raise_error(ActionController::RoutingError)

    enable_api!
    api_get("/formulas")
    expect(last_response.status).to eq(200)

    ActsAsCalculator.configure { |config| config.enable_api = false }
    expect { api_get("/formulas") }.to raise_error(ActionController::RoutingError)
  end

  it "keeps the route table itself unchanged either way — only matching is gated" do
    drawn_when_off = ActsAsCalculator::Engine.routes.routes.count
    enable_api!

    expect(ActsAsCalculator::Engine.routes.routes.count).to eq(drawn_when_off)
  end
end
