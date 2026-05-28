# frozen_string_literal: true

require_relative '../spec_helper'

describe 'ListAccounts service' do
  after do
    WebMock.reset!
  end

  it 'HAPPY: lists account ids and usernames through the authorized accounts endpoint' do
    response = {
      data: [
        { id: 1, username: 'alice' },
        { id: 2, username: 'bob' }
      ]
    }

    WebMock.stub_request(:get, "#{API_URL}/accounts")
           .with(headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(status: 200, body: response.to_json, headers: { 'content-type' => 'application/json' })

    result = FaceCloak::ListAccounts.new(app.config).call(auth_token: 'auth-token')

    _(result).must_equal [
      { 'id' => 1, 'username' => 'alice' },
      { 'id' => 2, 'username' => 'bob' }
    ]
  end
end
