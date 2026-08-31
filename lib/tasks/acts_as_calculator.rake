# frozen_string_literal: true

namespace :acts_as_calculator do
  desc "Imports formulas, lookup tables and templates from a JSON file " \
       "(rake acts_as_calculator:import[config/calculator/payroll.json])"
  task :import, [:path] => :environment do |_task, args|
    path = args[:path]
    abort("usage: rake acts_as_calculator:import[path/to/file.json]") if path.nil? || path.empty?

    begin
      summary = ActsAsCalculator::ImportDefinitions.(path:)
    rescue ActsAsCalculator::Error => e
      abort("acts_as_calculator: #{e.message}")
    end

    puts summary
    abort("acts_as_calculator: #{summary.failures.size} import error(s)") unless summary.success?
  end
end
