# frozen_string_literal: true

module ActsAsCalculator
  class ImportFormula
    def self.call(...)
      new(...).call
    end

    def initialize(attributes:)
      @attributes = attributes.transform_keys(&:to_s)
      @key = @attributes.fetch("key") { raise ImportError, "a formulas entry has no key" }.to_s
      @scope = (@attributes["scope"] || DEFAULT_SCOPE).to_s
      @owner = ResolveImportOwner.(@attributes["owner"])
    end

    def call
      return outcome(:created, add_version(Formula.create!(key:, scope:, owner:))) if formula.nil?
      return outcome(:skipped, matching_version) if matching_version

      outcome(:updated, add_version(formula))
    end

    private

    attr_reader :attributes, :key, :scope, :owner

    def formula
      return @formula if defined?(@formula)

      @formula = Formula.owned_by(owner).find_by(key:, scope:)
    end

    def matching_version
      @matching_version ||= formula.versions.includes(:variables).find { |version| same_content?(version) }
    end

    def same_content?(version)
      version.expression == expression &&
        version.effective_from == effective_from &&
        version.effective_to == effective_to &&
        specs(version.variables) == declared_specs
    end

    def add_version(target)
      SupersedeFormulaVersions.(formula: target, effective_from:, effective_to:) if status == FormulaVersion::ACTIVE

      version = target.versions.create!(**version_attributes(target))
      declared_variables.each { |variable| version.variables.create!(**variable) }
      version
    end

    def version_attributes(target)
      { version_number: (target.versions.maximum(:version_number) || 0) + 1,
        expression:, effective_from:, effective_to:, status:, change_note: attributes["change_note"] }
    end

    def expression
      @expression ||= required_attribute("expression").to_s
    end

    def effective_from
      @effective_from ||= CastDate.(required_attribute("effective_from"))
    end

    def effective_to
      return @effective_to if defined?(@effective_to)

      @effective_to = attributes["effective_to"] && CastDate.(attributes["effective_to"])
    end

    def status
      @status ||= (attributes["status"] || FormulaVersion::ACTIVE).to_s
    end

    def required_attribute(name)
      attributes.fetch(name) { raise ImportError, "formula #{key.inspect} has no #{name}" }
    end

    def declared_variables
      @declared_variables ||= Array(attributes["variables"]).map { |variable| declared_variable(variable) }
    end

    def declared_variable(variable)
      variable = variable.transform_keys(&:to_s)
      name = variable.fetch("name") { raise ImportError, "formula #{key.inspect} has a variable with no name" }

      { name: name.to_s,
        source_type: (variable["source_type"] || "context").to_s,
        source_config: CastJsonSafe.(variable["source_config"] || {}),
        required: variable.fetch("required", true) != false }
    end

    def declared_specs
      @declared_specs ||= specs(declared_variables)
    end

    def specs(variables)
      variables.map { |variable| VariableSpec.build(variable) }.sort_by(&:name)
    end

    def outcome(result, version)
      ImportOutcome.build(kind: :formula, status: result, key:, scope:, detail: "version #{version.version_number}")
    end
  end
end
