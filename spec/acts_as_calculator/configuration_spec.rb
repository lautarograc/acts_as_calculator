# frozen_string_literal: true

RSpec.describe ActsAsCalculator::Configuration do
  it "ships the API off, so a host has to opt in" do
    expect(described_class.new.enable_api).to be(false)
  end

  describe "ActsAsCalculator.configure" do
    it "yields the one configuration object" do
      ActsAsCalculator.configure { |config| config.enable_api = true }

      expect(ActsAsCalculator.configuration.enable_api).to be(true)
    end

    it "memoizes, so an initializer and a later read see the same object" do
      expect(ActsAsCalculator.configuration).to be(ActsAsCalculator.configuration)
    end
  end

  describe ".reset_configuration!" do
    it "puts the defaults back" do
      ActsAsCalculator.configure { |config| config.enable_api = true }

      ActsAsCalculator.reset_configuration!

      expect(ActsAsCalculator.configuration.enable_api).to be(false)
    end
  end

  it "needs no Rails to load — the routing constraint reads it, but it is plain Ruby" do
    script = %(require "acts_as_calculator"; print ActsAsCalculator.configuration.enable_api.inspect)
    lib = File.expand_path("../../lib", __dir__)

    expect(IO.popen([Gem.ruby, "-I#{lib}", "-e", script], err: %i[child out], &:read)).to eq("false")
  end
end
