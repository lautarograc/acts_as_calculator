# frozen_string_literal: true

require "rails/generators"

module ActsAsCalculator
  module Generators
    class ImportGenerator < ::Rails::Generators::Base
      desc "Imports formulas, lookup tables and templates from a JSON file. Idempotent: " \
           "re-importing an unchanged file changes nothing, and changed content becomes a " \
           "new version rather than an edit to an existing one."

      argument :path, type: :string, desc: "Path to the JSON import file"

      def import
        summary = ImportDefinitions.(path: File.expand_path(path, destination_root))
        say summary.to_s

        raise Thor::Error, "acts_as_calculator: #{summary.failures.size} import error(s)" unless summary.success?
      rescue ActsAsCalculator::Error => e
        raise Thor::Error, "acts_as_calculator: #{e.message}"
      end
    end
  end
end
