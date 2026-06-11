# frozen_string_literal: true

module FaceCloak
  # Removes the current assignee from a face record through the FaceCloak API.
  class UnassignFace
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(face_id:, auth_token:)
      @client.delete("/face_records/#{face_id}/assignment", auth_token: auth_token)
    end
  end
end
