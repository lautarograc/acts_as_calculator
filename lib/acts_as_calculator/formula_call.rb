# frozen_string_literal: true

module ActsAsCalculator
  FormulaCall = Data.define(:key, :version_id) do
    def self.build(source)
      attributes = source.is_a?(Hash) ? source.transform_keys(&:to_sym) : { key: source }
      key = attributes.fetch(:key) { raise FormulaCallError, "a formula call has no key" }.to_s
      raise FormulaCallError, "a formula call has a blank key" if key.empty?

      new(key:, version_id: cast_version_id(attributes[:version_id]))
    end

    def self.list(source)
      entries = source.is_a?(Hash) ? (source["calls"] || source[:calls]) : source

      Array(entries).map { |entry| build(entry) }
    end

    # Collapses a stored document into the `key => version_id` pins a parse needs.
    def self.pins(source)
      list(source).to_h { |call| [call.key, call.version_id] }
    end

    def self.document(calls)
      { "calls" => Array(calls).map(&:to_h) }
    end

    def self.cast_version_id(value)
      return nil if value.nil? || value.to_s.strip.empty?

      Integer(value)
    rescue ::ArgumentError, ::TypeError
      raise FormulaCallError, "formula call version_id #{value.inspect} is not an id"
    end
    private_class_method :cast_version_id

    def pinned?
      !version_id.nil?
    end

    def to_h
      { "key" => key, "version_id" => version_id }
    end

    def describe
      pinned? ? "@#{key} (version #{version_id})" : "@#{key}"
    end
  end
end
