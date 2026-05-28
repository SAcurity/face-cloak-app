# frozen_string_literal: true

module FaceCloak
  # Releases a face assignment after the assignee rejects it.
  class DeclineFaceAssignment
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(face_id:, auth_token:)
      @client.post("/face_records/#{face_id}/decline", {}, auth_token: auth_token)
    end
  end
end
