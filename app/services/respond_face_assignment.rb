# frozen_string_literal: true

module FaceCloak
  # Records the assignee's cloak choice for a face.
  class RespondFaceAssignment
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(face_id:, cloak_type:, auth_token:)
      @client.post(
        "/face_records/#{face_id}/respond",
        { cloak_type: cloak_type.to_s },
        auth_token: auth_token
      )
    end
  end
end
