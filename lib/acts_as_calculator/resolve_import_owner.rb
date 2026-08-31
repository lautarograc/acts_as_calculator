# frozen_string_literal: true

module ActsAsCalculator
  class ResolveImportOwner
    def self.call(reference)
      return nil if reference.nil?

      attributes = symbolize(reference)
      model = model_for(attributes[:type])
      id = attributes[:id]
      raise ImportError, "owner reference #{reference.inspect} needs both a type and an id" if id.nil?

      model.find_by(model.primary_key => id) ||
        raise(ImportError, "no #{model.name} with id #{id.inspect} to own the imported record")
    end

    def self.symbolize(reference)
      raise ImportError, "owner must be an object like {\"type\": \"Company\", \"id\": 1}" unless reference.is_a?(Hash)

      reference.transform_keys(&:to_sym)
    end
    private_class_method :symbolize

    def self.model_for(type)
      model = type.to_s.safe_constantize
      unless model.is_a?(Class) && model < ::ActiveRecord::Base
        raise ImportError, "owner type #{type.inspect} is not an ActiveRecord model"
      end

      model
    end
    private_class_method :model_for
  end
end
