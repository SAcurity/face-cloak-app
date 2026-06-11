# frozen_string_literal: true

module FaceCloak
  # Gets the current account detail payload, including face assignments.
  class GetAccount
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(username:, auth_token:)
      response = @client.get("/accounts/#{Account.normalize_username(username)}", auth_token: auth_token)
      authorized = response.fetch('data', response)
      attrs = authorized.fetch('attributes', authorized)
      Account.from_api(attrs.fetch('account'), auth_token)
    end
  end
end
