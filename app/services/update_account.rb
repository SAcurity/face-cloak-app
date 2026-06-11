# frozen_string_literal: true

module FaceCloak
  # Updates account profile fields via the FaceCloak API.
  class UpdateAccount
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(username:, updates:, auth_token:)
      response = @client.put("/accounts/#{username}", updates, auth_token: auth_token)
      response.fetch('data')
    end
  end
end
