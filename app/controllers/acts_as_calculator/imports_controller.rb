# frozen_string_literal: true

module ActsAsCalculator
  class ImportsController < ApplicationController
    def create
      summary = ImportDefinitions.(data: definitions)

      render json: SerializeImportSummary.(summary:),
             status: summary.success? ? :ok : :unprocessable_entity
    end

    private

    def definitions
      body = request.request_parameters
      if body.empty?
        raise ImportError, "no import document in the request body — POST JSON with at least one of " \
                           "#{ImportDefinitions::SECTIONS.keys.join(", ")}"
      end

      body
    end
  end
end
