# frozen_string_literal: true

module ActsAsCalculator
  class ApplicationController < ActionController::API
    rescue_from Error, with: :render_unprocessable
    rescue_from FormulaNotFoundError, TemplateNotFoundError, NoEffectiveVersionError, with: :render_not_found
    rescue_from PartialSupersedeError, with: :render_conflict
    rescue_from ::ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ::ActiveRecord::RecordInvalid, with: :render_record_invalid
    rescue_from ::ActiveRecord::RecordNotDestroyed, with: :render_record_not_destroyed
    rescue_from ::ActionController::ParameterMissing, with: :render_bad_request

    private

    def render_error(error, status, details: nil)
      payload = { type: error.class.name, message: error.message }
      payload[:details] = details if details

      render json: { error: payload }, status:
    end

    def render_unprocessable(error)
      render_error(error, :unprocessable_entity)
    end

    def render_not_found(error)
      render_error(error, :not_found)
    end

    def render_bad_request(error)
      render_error(error, :bad_request)
    end

    def render_conflict(error)
      render_error(error, :conflict)
    end

    def render_record_invalid(error)
      render_error(error, :unprocessable_entity, details: error.record.errors.messages)
    end

    def render_record_not_destroyed(error)
      render_error(error, :conflict, details: error.record.errors.messages)
    end

    def plain_hash(value)
      value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h.to_h : (value || {}).to_h
    end

    def filter_by_key_and_scope(relation)
      relation = relation.where(key: params[:key]) if params[:key].present?
      relation = relation.where(scope: params[:scope]) if params[:scope].present?
      relation
    end

    def resolve_owner(reference)
      ResolveImportOwner.(plain_hash(reference).presence)
    end
  end
end
