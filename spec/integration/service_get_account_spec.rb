# frozen_string_literal: true

require_relative '../spec_helper'

describe 'GetAccount service' do
  before do
    @api_response = {
      data: {
        type: 'authorized_account',
        attributes: {
          account: {
            type: 'account',
            attributes: { id: 7, username: 'alice', email: 'alice@example.com' },
            policies: {},
            capabilities: {}
          },
          auth_token: 'read.only.scoped.key'
        }
      }
    }
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: parses account detail with the limited API key' do
    WebMock.stub_request(:get, "#{API_URL}/accounts/alice")
           .to_return(status: 200, body: @api_response.to_json, headers: { 'content-type' => 'application/json' })

    account = FaceCloak::GetAccount.new(app.config).call(username: 'alice', auth_token: 'full.session.token')

    _(account.username).must_equal 'alice'
    _(account.email).must_equal 'alice@example.com'
    _(account.auth_token).must_equal 'read.only.scoped.key'
  end

  it 'HAPPY: forwards the full session token as the Bearer credential' do
    stub = WebMock.stub_request(:get, "#{API_URL}/accounts/alice")
                  .with(headers: { 'Authorization' => 'Bearer full.session.token' })
                  .to_return(status: 200, body: @api_response.to_json,
                             headers: { 'content-type' => 'application/json' })

    FaceCloak::GetAccount.new(app.config).call(username: 'alice', auth_token: 'full.session.token')

    assert_requested(stub)
  end
end
