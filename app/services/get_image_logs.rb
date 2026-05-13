# frozen_string_literal: true

module FaceCloak
  # Gets all action logs for an image via the FaceCloak API.
  class GetImageLogs
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(image_id:, current_account_id:)
      @client.authenticated_get("/images/#{image_id}/logs", current_account_id: current_account_id)
             .fetch('data', []).map { |log| log['attributes'] }
    end
  end
end
