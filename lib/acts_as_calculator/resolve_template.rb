# frozen_string_literal: true

module ActsAsCalculator
  class ResolveTemplate
    def self.call(...)
      new(...).call
    end

    def initialize(key:, scope: nil, owner: nil, version_number: nil)
      @key = key.to_s
      @scope = (scope || DEFAULT_SCOPE).to_s
      @owner = owner
      @version_number = version_number
    end

    def call
      FindOwnedRecord.(relation:, key:, scope:, owner:) || raise_template_not_found
    end

    private

    attr_reader :key, :scope, :owner, :version_number

    def relation
      version_number.nil? ? Template.current : Template.where(version_number:)
    end

    def raise_template_not_found
      raise TemplateNotFoundError,
            "no #{version_number.nil? ? "current" : "version #{version_number}"} template " \
            "#{key.inspect} in scope #{scope.inspect} for #{describe_owner}"
    end

    def describe_owner
      owner.nil? ? "no owner" : "#{owner.class}##{owner.id} (or globally)"
    end
  end
end
