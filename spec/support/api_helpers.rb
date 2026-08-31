# frozen_string_literal: true

require "json"

module ApiHelpers
  include Rack::Test::Methods

  MOUNT_POINT = "/calculator"

  def app
    Rails.application
  end

  def enable_api!
    ActsAsCalculator.configure { |config| config.enable_api = true }
  end

  def api_get(path, params = {})
    get("#{MOUNT_POINT}#{path}", params, "HTTP_ACCEPT" => "application/json")
  end

  def api_post(path, payload = {})
    request_with_body(:post, path, payload)
  end

  def api_patch(path, payload = {})
    request_with_body(:patch, path, payload)
  end

  def api_delete(path)
    delete("#{MOUNT_POINT}#{path}", {}, "HTTP_ACCEPT" => "application/json")
  end

  def json_body
    JSON.parse(last_response.body)
  end

  def error_message
    json_body.dig("error", "message")
  end

  private

  def request_with_body(method, path, payload)
    public_send(method, "#{MOUNT_POINT}#{path}", JSON.generate(payload),
                "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json")
  end
end
