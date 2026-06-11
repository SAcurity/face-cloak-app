# frozen_string_literal: true

module FaceCloak
  # Deletes an image through the FaceCloak API.
  class DeleteImage
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(image_id:, auth_token:)
      @client.delete("/images/#{image_id}", auth_token: auth_token)
    end
  end
end
