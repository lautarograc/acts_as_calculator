# frozen_string_literal: true

module ActsAsCalculator
  class FormulaVersionsController < ApplicationController
    def index
      versions = formula.versions.order(:version_number)

      render json: { versions: versions.map { |version| SerializeFormulaVersion.(version:) } }
    end

    def show
      render json: { version: SerializeFormulaVersion.(version:, variables: true) }
    end

    def create
      published = PublishFormulaVersion.(formula:, **version_attributes)

      render json: { version: SerializeFormulaVersion.(version: published, variables: true) },
             status: :created
    end

    private

    def formula
      @formula ||= Formula.find(params[:formula_id])
    end

    def version
      @version ||= formula.versions.find(params[:id])
    end

    def version_attributes
      permitted = params.require(:version).permit(
        :expression, :effective_from, :effective_to, :status, :change_note,
        variables: [:name, :source_type, :required, { source_config: {} }]
      )

      { expression: permitted[:expression],
        effective_from: permitted[:effective_from],
        effective_to: permitted[:effective_to].presence,
        status: permitted[:status].presence || FormulaVersion::ACTIVE,
        change_note: permitted[:change_note],
        variables: Array(permitted[:variables]).map { |variable| plain_hash(variable) } }
    end
  end
end
