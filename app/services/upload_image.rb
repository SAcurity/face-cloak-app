# frozen_string_literal: true

module FaceCloak
  # Uploads a new image to the FaceCloak API.
  class UploadImage
    def initialize(config)
      @config = config
    end

    def call(auth_token:, file_path:, file_name:)
      url = "#{@config.API_URL}/images"

      response = HTTP.auth("Bearer #{auth_token}")
                     .post(url, form: {
                             file: HTTP::FormData::File.new(file_path, filename: file_name)
                           })

      raise "Upload failed: #{response.body}" unless response.code == 201

      JSON.parse(response.body.to_s)['data']['attributes']
    end
  end
end
