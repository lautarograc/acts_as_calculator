# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module ActsAsCalculator
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      include ::Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Copies the acts_as_calculator migration for the six calculator_* tables."

      def self.next_migration_number(dirname)
        ::ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def create_migration_file
        migration_template "create_acts_as_calculator_tables.rb.tt",
                           "db/migrate/create_acts_as_calculator_tables.rb"
      end

      private

      def migration_version
        "[#{::ActiveRecord::Migration.current_version}]"
      end
    end
  end
end
