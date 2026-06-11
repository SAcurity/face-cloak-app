# frozen_string_literal: true

module FaceCloak
  # Gets the current account detail payload, including face assignments.
  class GetAccount
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(username:, auth_token:)
      response = @client.get("/accounts/#{Account.normalize_username(username)}", auth_token: auth_token)
      authorized_account(response)
    end

    private

    def authorized_account(response)
      envelope = response.fetch('data', response)
      attributes = envelope.fetch('attributes', envelope)
      return Account.from_api(attributes.fetch('account'), attributes['auth_token']) if attributes.key?('account')

      Account.from_api(envelope, nil)
    end
  end
end
