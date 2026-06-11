# frozen_string_literal: true

module FaceCloak
  # Gets detailed metadata for a single image via the FaceCloak API.
  class GetImage
    def initialize(config)
      @client = ApiClient.new(config)
      @list_images = ListImages.new(config)
    end

    def call(image_id, auth_token: nil)
      image_envelope = find_image_envelope(image_id, auth_token)
      return nil unless image_envelope

      image_envelope['faces'] = fetch_faces(image_id, auth_token: auth_token)
      Image.from_api(image_envelope)
    rescue StandardError
      nil
    end

    private

    def find_image_envelope(image_id, auth_token)
      auth_env = find_in_raw_list(image_id, auth_token: auth_token) if auth_token
      return auth_env if auth_env

      find_in_raw_list(image_id, auth_token: nil)
    end

    def find_in_raw_list(image_id, auth_token:)
      response = @client.get('/images', auth_token: auth_token)
      response.fetch('data', []).find { |img| (img['attributes']&.dig('id') || img['id']).to_s == image_id.to_s }
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
