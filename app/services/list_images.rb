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
        img['attributes']
      end
    end
  end
end
