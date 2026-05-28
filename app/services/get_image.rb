# frozen_string_literal: true

module FaceCloak
  # Gets detailed metadata for a single image via the FaceCloak API.
  class GetImage
    def initialize(config)
      @client = ApiClient.new(config)
      @list_images = ListImages.new(config)
    end

    def call(image_id, auth_token: nil)
      image = find_image(image_id, auth_token)
      return nil unless image

      image.merge('faces' => fetch_faces(image_id, auth_token: auth_token))
    rescue StandardError
      nil
    end

    private

    def find_image(image_id, auth_token)
      public_image = find_in_list(image_id, auth_token: nil)
      return public_image if public_image

      find_in_list(image_id, auth_token: auth_token)
    end

    def find_in_list(image_id, auth_token:)
      @list_images.call(auth_token: auth_token).find { |img| img['id'].to_s == image_id.to_s }
    rescue StandardError
      nil
    end

    def fetch_faces(image_id, auth_token:)
      response = @client.get("/images/#{image_id}/face_records", auth_token: auth_token)

      response.fetch('data', []).map { |face| face['attributes'] }
    rescue StandardError
      []
    end
  end
end
