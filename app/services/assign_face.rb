# frozen_string_literal: true

module FaceCloak
  # Service to assign a user to a detected face in an image
  class AssignFace
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(face_id:, assigned_username:, auth_token:)
      @client.post(
        "/face_records/#{face_id}/assignment",
        { assigned_username: Account.normalize_username(assigned_username) },
        auth_token: auth_token
      )
    end
  end
end
