# frozen_string_literal: true

module FaceCloak
  # Service to assign a user to a detected face in an image
  class AssignFace
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(face_id:, assigned_user_id:, auth_token:)
      @client.post(
        "/face_records/#{face_id}/assignment",
        { assigned_user_id: normalize_id(assigned_user_id) },
        auth_token: auth_token
      )
    end

    private

    def normalize_id(value)
      value.to_s.match?(/\A\d+\z/) ? value.to_i : value
    end
  end
end
