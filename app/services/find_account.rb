# frozen_string_literal: true

module FaceCloak
  # Finds an account by exact username through the signed account search endpoint.
  class FindAccount
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(username:)
      username = Account.normalize_username(username)
      return nil if username.empty?

      account_payload(@client.post('/accounts/search', SignedMessage.sign({ username: username })))
    rescue ApiClient::ApiError => e
      return nil if e.status == 404

      raise
    end

    private

    def account_payload(response)
      attrs = response.fetch('attributes', response)
      id = response['id'] || attrs['id']
      username = attrs['username'] || response['username']
      return nil if id.to_s.empty? || username.to_s.strip.empty?

      { 'id' => id, 'username' => username }
    end
  end
end
