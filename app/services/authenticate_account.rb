# frozen_string_literal: true

module FaceCloak
  # Authenticate user credentials against the FaceCloak API.
  class AuthenticateAccount
    class UnauthorizedError < StandardError; end
    class ApiServerError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(username:, password:)
      username = Account.normalize_username(username)
      validate_credentials!(username, password)

      response = @client.post('/auth/authenticate', { username: username, password: password })
      authenticated_account(response)
    rescue ApiClient::ApiError => e
      raise UnauthorizedError, "Authentication failed: #{e.message}" if e.status == 403
      raise ApiServerError, e.message if e.status >= 500

      raise
    end

    private

    def validate_credentials!(username, password)
      return unless username.empty? || password.to_s.empty?

      raise UnauthorizedError, 'Username and password required'
    end

    def authenticated_account(response)
      attributes = response.fetch('attributes')
      Account.from_api(
        attributes.fetch('account'),
        attributes.fetch('auth_token')
      )
    end
  end
end
