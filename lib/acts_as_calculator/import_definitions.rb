# frozen_string_literal: true

module ActsAsCalculator
  class ImportDefinitions
    SECTIONS = {
      "lookup_tables" => ImportLookupTable,
      "formulas" => ImportFormula,
      "templates" => ImportTemplate
    }.freeze

    def self.call(...)
      new(...).call
    end

    def initialize(path: nil, data: nil)
      raise ImportError, "give ImportDefinitions either a path or data, not both" if path && data
      raise ImportError, "ImportDefinitions needs a path or data" if path.nil? && data.nil?

      @path = path
      @document = (data || ReadImportFile.(path)).transform_keys(&:to_s)
    end

    def call
      reject_unknown_sections

      ImportSummary.new(source: path&.to_s || "inline data", outcomes:)
    end

    private

    attr_reader :path, :document

    def outcomes
      SECTIONS.flat_map do |section, decree|
        Array(document[section]).map { |attributes| import(decree, attributes, section) }
      end
    end

    def reject_unknown_sections
      unknown = document.keys - SECTIONS.keys
      return if unknown.empty?

      raise ImportError, "unknown import section(s) #{unknown.join(", ")} (known: #{SECTIONS.keys.join(", ")})"
    end

    def import(decree, attributes, section)
      raise ImportError, "#{section} must be a list of objects, got #{attributes.inspect}" unless attributes.is_a?(Hash)

      Record.transaction(requires_new: true) { decree.(attributes:) }
    rescue Error, ::ActiveRecord::ActiveRecordError => e
      failure(attributes, section, e)
    end

    def failure(attributes, section, error)
      attributes = attributes.is_a?(Hash) ? attributes.transform_keys(&:to_s) : {}

      ImportOutcome.build(kind: section.delete_suffix("s"), status: :failed,
                          key: attributes["key"] || "(no key)", scope: attributes["scope"] || DEFAULT_SCOPE,
                          detail: error.message)
    end
  end
end
