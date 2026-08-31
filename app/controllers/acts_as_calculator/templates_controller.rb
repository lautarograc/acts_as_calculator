# frozen_string_literal: true

module ActsAsCalculator
  class TemplatesController < ApplicationController
    def index
      render json: { templates: scoped_templates.map { |template| SerializeTemplate.(template:) } }
    end

    def show
      render json: { template: SerializeTemplate.(template:) }
    end

    def create
      published = PublishTemplate.(**template_attributes)

      render json: { template: SerializeTemplate.(template: published) }, status: :created
    end

    def destroy
      template.destroy!

      head :no_content
    end

    def preview
      body = RenderTemplate.(template:, context: plain_hash(params[:context]))

      render json: { preview: { body:, format: template.format } }
    end

    def promote
      render json: { template: SerializeTemplate.(template: PromoteTemplate.(template:)) }
    end

    private

    def template
      @template ||= Template.find(params[:id])
    end

    def scoped_templates
      templates = filter_by_key_and_scope(Template.order(:scope, :key, :version_number, :id))
      current_only? ? templates.current : templates
    end

    def current_only?
      %w[true 1].include?(params[:current].to_s)
    end

    def template_attributes
      permitted = params.require(:template).permit(:key, :body, :scope, :format, owner: %i[type id])

      { key: permitted[:key].to_s,
        body: permitted[:body].to_s,
        scope: permitted[:scope].presence,
        format: permitted[:format].presence || Template::HTML,
        owner: resolve_owner(permitted[:owner]) }
    end
  end
end
