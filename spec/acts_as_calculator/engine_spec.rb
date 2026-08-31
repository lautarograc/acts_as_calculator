# frozen_string_literal: true

RSpec.describe ActsAsCalculator::Engine do
  it "is an isolated Rails engine" do
    expect(described_class).to be < ::Rails::Engine
    expect(described_class).to be_isolated
  end

  it "roots at the gem, so app/models is on the autoload path" do
    expect(described_class.root).to eq(Pathname.new(File.expand_path("../..", __dir__)))
    expect(described_class.paths["app/models"].existent).to include(described_class.root.join("app/models").to_s)
  end

  it "names tables for what they hold, not for the gem" do
    expect(ActsAsCalculator.table_name_prefix).to eq("calculator_")
  end

  it "keeps that prefix after isolate_namespace's active_record load hook runs" do
    ActiveSupport.run_load_hooks(:active_record, ActiveRecord::Base)

    expect(ActsAsCalculator.table_name_prefix).to eq("calculator_")
  end

  it "ships no migrations of its own — the install generator copies them into the host" do
    expect(described_class.paths["db/migrate"].existent).to be_empty
  end

  it "puts the import task where the engine loads a host's rake tasks from" do
    expect(described_class.paths["lib/tasks"].existent)
      .to include(described_class.root.join("lib/tasks/acts_as_calculator.rake").to_s)
  end

  it "draws its API routes from the engine's own config/routes.rb" do
    expect(described_class.routes.routes.map(&:name).compact)
      .to include("formulas", "formula_versions", "templates", "preview_template", "import")
  end

  it "leaves no route outside the enable_api constraint" do
    ungated = described_class.routes.routes.reject do |route|
      route.app.is_a?(::ActionDispatch::Routing::Mapper::Constraints) &&
        route.app.constraints.any? { |constraint| constraint.is_a?(Proc) }
    end

    expect(described_class.routes.routes).not_to be_empty
    expect(ungated).to be_empty
  end

  it "loads only what the engine layer needs, never the full rails gem" do
    expect(defined?(ActionMailer)).to be_nil
    expect(defined?(ActiveJob)).to be_nil
  end
end
