# frozen_string_literal: true

module FaceCloak
  # Authenticates an SSO identity through the FaceCloak API.
  class AuthenticateSsoAccount
    class UnauthorizedError < StandardError; end
    class ApiServerError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(provider:, id_token:, jwks:)
      validate_payload!(provider, id_token, jwks)

      authenticated_account(sso_response(provider, id_token, jwks))
    rescue ApiClient::ApiError => e
      App.logger.warn("SSO API ERROR: status=#{e.status} body=#{e.body.inspect}") if defined?(App)
      raise UnauthorizedError, "SSO authentication failed: #{e.message}" if [400, 401, 403, 422].include?(e.status)

      raise ApiServerError, e.message
    end

    private

    def sso_response(provider, id_token, jwks)
      payload = {
        provider: provider,
        id_token: id_token,
        jwks: jwks
      }
      @client.post('/auth/sso', SignedMessage.sign(payload))
    end

    def validate_payload!(provider, id_token, jwks)
      return unless provider.to_s.empty? || id_token.to_s.empty? || jwks.nil?

      raise UnauthorizedError, 'SSO payload is incomplete'
    end

    def authenticated_account(response)
      envelope = response.fetch('data', response)
      attributes = envelope.fetch('attributes')
      Account.from_api(
        attributes.fetch('account'),
        attributes.fetch('auth_token')
      )
    end
  end
end
