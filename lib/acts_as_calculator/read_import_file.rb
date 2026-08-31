# frozen_string_literal: true

require "json"

module ActsAsCalculator
  class ReadImportFile
    def self.call(path)
      raise ImportError, "no import file at #{path}" unless File.file?(path.to_s)

      parse(File.read(path.to_s), path)
    end

    def self.parse(source, path)
      document = JSON.parse(source)
      return document if document.is_a?(Hash)

      raise ImportError, "#{path} must contain a JSON object, got #{document.class}"
    rescue JSON::ParserError => e
      raise ImportError, "#{path} is not valid JSON: #{e.message}"
    end
    private_class_method :parse
  end
end
