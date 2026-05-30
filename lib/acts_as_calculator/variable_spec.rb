# frozen_string_literal: true

module ActsAsCalculator
  VariableSpec = Data.define(:name, :source_type, :source_config, :required) do
    def self.build(source)
      attributes = source.is_a?(Hash) ? source : read_from(source)
      attributes = attributes.transform_keys(&:to_sym)
      required = attributes[:required]
      required = true if required.nil?

      new(
        name: attributes.fetch(:name).to_s,
        source_type: (attributes[:source_type] || :context).to_sym,
        source_config: (attributes[:source_config] || {}).transform_keys(&:to_sym),
        required:
      )
    end

    def self.read_from(source)
      {
        name: source.name,
        source_type: source.source_type,
        source_config: source.source_config,
        required: source.respond_to?(:required) ? source.required : true
      }
    end
    private_class_method :read_from

    def default
      source_config[:default]
    end
  end
end
