# frozen_string_literal: true

module FaceCloak
  # Lists accounts available for assignment via the FaceCloak API.
  class ListAccounts
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(auth_token:)
      response = @client.get('/accounts', auth_token: auth_token)

      response.fetch('data', []).filter_map { |account| account_payload(account) }
    end

    private

    def account_payload(account)
      attrs = account.fetch('attributes', account)
      id = account['id'] || attrs['id']
      username = attrs['username'] || account['username']
      return nil if id.to_s.empty? || username.to_s.strip.empty?

      { 'id' => id, 'username' => username }
    end
  end
end
