# frozen_string_literal: true

module FaceCloak
  # Uploads a new image to the FaceCloak API.
  class UploadImage
    def initialize(config)
      @config = config
    end

    def call(current_account_id:, file_path:, file_name:)
      url = "#{@config.API_URL}/images"
      
      # Prepare multipart request
      response = HTTP.headers('X-Actor-Id' => current_account_id.to_s)
                    .post(url, form: {
                      owner_id: current_account_id,
                      file: HTTP::FormData::File.new(file_path, filename: file_name)
                    })

      raise "Upload failed: #{response.body}" unless response.code == 201
      
      JSON.parse(response.body.to_s)['data']['attributes']
    end
  end
end
