# frozen_string_literal: true

require_relative '../spec_helper'

describe 'ListAccounts service' do
  after do
    WebMock.reset!
  end

  it 'HAPPY: lists account ids and usernames through the usernames endpoint' do
    response = {
      data: [
        { id: 1, username: 'alice' },
        { id: 2, username: 'bob' }
      ]
    }

    WebMock.stub_request(:get, "#{API_URL}/accounts/usernames")
           .with(headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(status: 200, body: response.to_json, headers: { 'content-type' => 'application/json' })

    result = FaceCloak::ListAccounts.new(app.config).call(auth_token: 'auth-token')

    _(result).must_equal [
      { 'id' => 1, 'username' => 'alice' },
      { 'id' => 2, 'username' => 'bob' }
    ]
  end

  it 'HAPPY: falls back to the legacy accounts endpoint while the API is rolling out' do
    WebMock.stub_request(:get, "#{API_URL}/accounts/usernames")
           .with(headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(status: 404, body: { message: 'Not found' }.to_json)
    WebMock.stub_request(:get, "#{API_URL}/accounts")
           .with(headers: { 'Authorization' => 'Bearer auth-token' })
           .to_return(status: 200, body: { data: [{ id: 1, username: 'alice' }] }.to_json)

    result = FaceCloak::ListAccounts.new(app.config).call(auth_token: 'auth-token')

    _(result).must_equal [{ 'id' => 1, 'username' => 'alice' }]
  end
end
