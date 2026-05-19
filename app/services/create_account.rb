# frozen_string_literal: true

module FaceCloak
  # Create a new FaceCloak account by posting to the API.
  class CreateAccount
    class InvalidAccount < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(email:, username:, password:)
      @client.post('/accounts', { email:, username:, password: })
    rescue ApiClient::ApiError => e
      raise InvalidAccount, e.message
    end
  end
end
