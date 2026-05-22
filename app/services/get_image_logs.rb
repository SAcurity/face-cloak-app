# frozen_string_literal: true

module FaceCloak
  # Gets all action logs for an image via the FaceCloak API.
  class GetImageLogs
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(image_id:, auth_token:)
      @client.get("/images/#{image_id}/logs", auth_token: auth_token)
             .fetch('data', []).map { |log| log['attributes'] }
    end
  end
end
