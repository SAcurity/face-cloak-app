# frozen_string_literal: true

module FaceCloak
  # Deletes an account through the FaceCloak API.
  class DeleteAccount
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(username:, auth_token:)
      @client.delete("/accounts/#{username}", auth_token: auth_token)
    end
  end
end
