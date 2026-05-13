# frozen_string_literal: true

module FaceCloak
  # Gets detailed metadata for a single image via the FaceCloak API.
  class GetImage
    def initialize(config)
      @client = ApiClient.new(config)
      @list_images = ListImages.new(config)
    end

    def call(image_id, current_account_id: nil)
      image = @list_images.call(current_account_id: current_account_id)
                          .find { |img| img['id'] == image_id }
      return nil unless image

      image.merge('faces' => fetch_faces(image_id, current_account_id: current_account_id))
    rescue StandardError
      nil
    end

    private

    def fetch_faces(image_id, current_account_id:)
      response = if current_account_id
                   @client.authenticated_get("/images/#{image_id}/face_records",
                                             current_account_id: current_account_id)
                 else
                   @client.get("/images/#{image_id}/face_records")
                 end

      response.fetch('data', []).map { |face| face['attributes'] }
    rescue StandardError
      []
    end
  end
end
