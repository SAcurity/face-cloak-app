# frozen_string_literal: true

module FaceCloak
  # Lists account profile/status data visible to the current account.
  class ListAccountStatuses
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(auth_token:)
      response = @client.get('/accounts', auth_token: auth_token)
      {
        accounts: account_payloads(response.fetch('data', []), auth_token),
        capabilities: response.fetch('capabilities', {})
      }
    end

    private

    def account_payloads(accounts, auth_token)
      accounts.map { |account| enrich_account_payload(account_payload(account), auth_token) }
    end

    def enrich_account_payload(account, auth_token)
      username = account['username'].to_s
      return account if username.empty? || account['system_roles'].any?

      detail = @client.get("/accounts/#{username}", auth_token: auth_token)
      account.merge('system_roles' => extract_system_roles(account_envelope(detail.fetch('data', detail))))
    rescue ApiClient::ApiError
      account
    end

    def account_payload(account)
      account = account_envelope(account)
      attrs = account.fetch('attributes', account)
      account.merge(
        'id' => account['id'] || attrs['id'],
        'username' => attrs['username'] || account['username'],
        'email' => attrs['email'] || account['email'],
        'system_roles' => extract_system_roles(account),
        'created_at' => attrs['created_at'] || account['created_at'],
        'updated_at' => attrs['updated_at'] || account['updated_at'],
        'policies' => account['policies'] || {}
      )
    end

    def extract_system_roles(account)
      attrs = account.fetch('attributes', account)
      include_data = account['include'] || attrs['include'] || {}
      roles = include_data['system_roles'] || attrs['system_roles'] || account['system_roles'] || []
      Array(roles)
    end

    def account_envelope(payload)
      attrs = payload.fetch('attributes', payload)
      attrs.fetch('account', payload)
    end
  end
end
