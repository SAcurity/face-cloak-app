# frozen_string_literal: true

module FaceCloak
  # Lists all images via the FaceCloak API.
  class ListImages
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(owner_id: nil, current_account_id: nil)
      response = if current_account_id
                   @client.authenticated_get('/images', current_account_id: current_account_id)
                 else
                   @client.get('/images')
                 end

      images = response.fetch('data', []).map do |img|
        img['attributes']
      end

      return images unless owner_id

      # Filter by owner_id if provided (simple client-side filter for now)
      images.select { |img| img['owner_id'].to_i == owner_id.to_i }
    end
  end
end
