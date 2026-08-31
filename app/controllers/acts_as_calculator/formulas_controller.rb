# frozen_string_literal: true

module ActsAsCalculator
  class FormulasController < ApplicationController
    def index
      render json: { formulas: scoped_formulas.map { |formula| SerializeFormula.(formula:) } }
    end

    def show
      render json: { formula: SerializeFormula.(formula:, versions: true) }
    end

    def create
      created = Formula.create!(**formula_attributes)

      render json: { formula: SerializeFormula.(formula: created) }, status: :created
    end

    def update
      formula.update!(**formula_attributes)

      render json: { formula: SerializeFormula.(formula:) }
    end

    def destroy
      formula.destroy!

      head :no_content
    end

    private

    def formula
      @formula ||= Formula.find(params[:id])
    end

    def scoped_formulas
      filter_by_key_and_scope(Formula.order(:scope, :key, :id))
    end

    def formula_params
      params.require(:formula).permit(:key, :scope, owner: %i[type id])
    end

    def formula_attributes
      permitted = formula_params
      attributes = {}
      attributes[:key] = permitted[:key].to_s if permitted.key?(:key)
      attributes[:scope] = permitted[:scope].to_s if permitted.key?(:scope)
      attributes[:owner] = resolve_owner(permitted[:owner]) if permitted.key?(:owner)
      attributes
    end
  end
end
