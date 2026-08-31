# frozen_string_literal: true

module ActsAsCalculator
  class ImportLookupTable
    def self.call(...)
      new(...).call
    end

    def initialize(attributes:)
      @attributes = attributes.transform_keys(&:to_s)
      @key = @attributes.fetch("key") { raise ImportError, "a lookup_tables entry has no key" }.to_s
      @scope = (@attributes["scope"] || DEFAULT_SCOPE).to_s
      @owner = ResolveImportOwner.(@attributes["owner"])
    end

    def call
      return create if existing.nil?
      return outcome(:skipped) if entries_unchanged?

      guard_against_rewriting_audited_brackets
      replace_entries
      outcome(:updated)
    end

    private

    attr_reader :attributes, :key, :scope, :owner

    def existing
      return @existing if defined?(@existing)

      @existing = LookupTable.owned_by(owner).find_by(key:, scope:)
    end

    def create
      table = LookupTable.create!(key:, scope:, owner:)
      write_entries(table)
      outcome(:created)
    end

    def replace_entries
      existing.entries.destroy_all
      write_entries(existing)
    end

    def write_entries(table)
      declared_entries.each_with_index do |entry, position|
        table.entries.create!(position:, from: entry[:from], to: entry[:to], value: entry[:value])
      end
    end

    def declared_entries
      @declared_entries ||= Array(attributes["entries"]).map { |entry| declared_entry(entry.transform_keys(&:to_s)) }
    end

    def declared_entry(entry)
      value = entry.fetch("value") { raise ImportError, "lookup table #{key.inspect} has an entry with no value" }

      { from: cast_bound(entry["from"]), to: cast_bound(entry["to"]), value: CastDecimal.(value) }
    end

    def cast_bound(value)
      value.nil? ? nil : CastDecimal.(value)
    end

    def entries_unchanged?
      existing.entries.ordered.map { |entry| { from: entry.from, to: entry.to, value: entry.value } } ==
        declared_entries
    end

    def guard_against_rewriting_audited_brackets
      statuses = [FormulaVersion::ACTIVE, FormulaVersion::RETIRED]
      references = FindLookupTableReferences.(lookup_table: existing, statuses:)
      return if references.empty?

      raise LookupTableInUseError, in_use_message(references)
    end

    def in_use_message(references)
      used_by = references.map { |version| "#{version.formula.key}##{version.version_number} (#{version.status})" }

      "lookup table #{key.inspect} in scope #{scope.inspect} already backs #{used_by.join(", ")}; " \
        "changing its entries would retroactively change what those calculations were audited " \
        "against. Import a new table key instead (e.g. #{key.inspect} → \"#{key}_v2\") and a new " \
        "formula version pointing at it."
    end

    def outcome(status)
      ImportOutcome.build(kind: :lookup_table, status:, key:, scope:)
    end
  end
end
