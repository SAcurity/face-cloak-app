# frozen_string_literal: true

require_relative '../spec_helper'

describe 'ListAccountStatuses service' do
  after do
    WebMock.reset!
  end

  it 'enriches account roles from account detail payloads' do
    WebMock.stub_request(:get, "#{API_URL}/accounts")
           .with(headers: { 'Authorization' => 'Bearer token' })
           .to_return(status: 200, body: accounts_response.to_json, headers: json_headers)
    stub_account_detail('alice', %w[admin member])
    stub_account_detail('bob', %w[member])

    result = FaceCloak::ListAccountStatuses.new(app.config).call(auth_token: 'token')
    roles_by_username = result[:accounts].to_h { |account| [account['username'], account['system_roles']] }
    alice = result[:accounts].find { |account| account['username'] == 'alice' }

    _(roles_by_username['alice']).must_include 'admin'
    _(roles_by_username['bob']).must_equal ['member']
    _(alice['has_password']).must_equal true
    _(alice['sso_provider']).must_equal 'google'
  end

  private

  def accounts_response
    {
      data: [
        { id: 1, username: 'alice', email: 'alice@example.com', policies: {} },
        { id: 2, username: 'bob', email: 'bob@example.com', has_password: false, policies: {} }
      ],
      capabilities: { is_admin: true }
    }
  end

  def stub_account_detail(username, roles)
    WebMock.stub_request(:get, "#{API_URL}/accounts/#{username}")
           .with(headers: { 'Authorization' => 'Bearer token' })
           .to_return(
             status: 200,
             body: account_detail_response(username, roles).to_json,
             headers: json_headers
           )
  end

  def account_detail_response(username, roles)
    { data: account_detail_data(username, roles) }
  end

  def account_detail_data(username, roles)
    {
      type: 'authorized_account',
      attributes: {
        account: {
          type: 'account',
          attributes: { username: username, has_password: true, sso_provider: 'google' },
          include: { system_roles: roles }
        }
      }
    }
  end

  def json_headers
    { 'content-type' => 'application/json' }
  end
end
