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
    stub_account_detail('alice', ['admin', 'member'])
    stub_account_detail('bob', ['member'])

    result = FaceCloak::ListAccountStatuses.new(app.config).call(auth_token: 'token')
    roles_by_username = result[:accounts].to_h { |account| [account['username'], account['system_roles']] }

    _(roles_by_username['alice']).must_include 'admin'
    _(roles_by_username['bob']).must_equal ['member']
  end

  private

  def accounts_response
    {
      data: [
        { id: 1, username: 'alice', email: 'alice@example.com', policies: {} },
        { id: 2, username: 'bob', email: 'bob@example.com', policies: {} }
      ],
      capabilities: { is_admin: true }
    }
  end

  def stub_account_detail(username, roles)
    WebMock.stub_request(:get, "#{API_URL}/accounts/#{username}")
           .with(headers: { 'Authorization' => 'Bearer token' })
           .to_return(
             status: 200,
             body: {
               data: {
                 type: 'authorized_account',
                 attributes: {
                   account: {
                     type: 'account',
                     attributes: { username: username },
                     include: { system_roles: roles }
                   }
                 }
               }
             }.to_json,
             headers: json_headers
           )
  end

  def json_headers
    { 'content-type' => 'application/json' }
  end
end
