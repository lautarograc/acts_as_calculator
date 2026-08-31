# frozen_string_literal: true

module ActsAsCalculator
  class ImportTemplate
    def self.call(...)
      new(...).call
    end

    def initialize(attributes:)
      @attributes = attributes.transform_keys(&:to_s)
      @key = @attributes.fetch("key") { raise ImportError, "a templates entry has no key" }.to_s
      @scope = (@attributes["scope"] || DEFAULT_SCOPE).to_s
      @owner = ResolveImportOwner.(@attributes["owner"])
    end

    def call
      return outcome(:skipped, current) if current && current.body == body && current.format == format

      outcome(versions.exists? ? :updated : :created, publish)
    end

    private

    attr_reader :attributes, :key, :scope, :owner

    def versions
      Template.owned_by(owner).where(key:, scope:)
    end

    def current
      return @current if defined?(@current)

      @current = versions.current.first
    end

    def publish
      PublishTemplate.(key:, scope:, owner:, body:, format:)
    end

    def body
      @body ||= attributes.fetch("body") { raise ImportError, "template #{key.inspect} has no body" }.to_s
    end

    def format
      @format ||= (attributes["format"] || Template::HTML).to_s
    end

    def outcome(result, template)
      ImportOutcome.build(kind: :template, status: result, key:, scope:,
                          detail: "version #{template.version_number}")
    end
  end
end
