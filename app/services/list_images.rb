# frozen_string_literal: true

module FaceCloak
  # Lists all images via the FaceCloak API.
  class ListImages
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(auth_token: nil)
      response = @client.get('/images', auth_token: auth_token)

      response.fetch('data', []).map do |img|
        attributes = img['attributes'] || img
        attributes.merge('id' => attributes['id'] || img['id'])
      end
    end
  end
end
