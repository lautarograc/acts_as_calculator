# frozen_string_literal: true

require_relative "lib/acts_as_calculator/version"

Gem::Specification.new do |spec|
  spec.name = "acts_as_calculator"
  spec.version = ActsAsCalculator::VERSION
  spec.authors = ["lautarograc"]
  spec.email = ["lautarograciani2106@gmail.com"]

  spec.summary = "A pricing and calculation engine on top of Dentaku."
  spec.description = "Mix Calculable into any model to get effective-dated, versioned formulas, " \
                      "apportionment and aggregation helpers, and Liquid-rendered output " \
                      "— reusable across payroll, e-commerce, and insurance domains."
  spec.homepage = "https://github.com/lautarograc/acts_as_calculator"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "bigdecimal", "~> 3.1"
  spec.add_dependency "dentaku", "~> 4.0"

  spec.add_dependency "liquid", "~> 5.4"

  spec.add_dependency "actionpack", ">= 7.1", "< 9"
  spec.add_dependency "activerecord", ">= 7.1", "< 9"
  spec.add_dependency "activesupport", ">= 7.1", "< 9"
  spec.add_dependency "railties", ">= 7.1", "< 9"
end
