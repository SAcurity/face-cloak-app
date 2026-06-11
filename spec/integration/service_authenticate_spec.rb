# frozen_string_literal: true

require_relative '../spec_helper'

describe 'AuthenticateAccount service' do
  before do
    @credentials = { username: 'alice', password: 'password123' }
    @api_credentials = { username: 'alice', password: 'password123' }
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: authenticates through the API' do
    response = {
      type: 'authenticated_account',
      attributes: {
        account: {
          type: 'account',
          attributes: { id: 1, username: 'alice', email: 'alice@example.com' },
          include: { system_roles: ['member'] }
        },
        auth_token: 'opaque.api.token'
      }
    }
    WebMock.stub_request(:post, "#{API_URL}/auth/authenticate")
           .with(body: FaceCloak::SignedMessage.sign(@api_credentials).to_json)
           .to_return(status: 200, body: response.to_json, headers: { 'content-type' => 'application/json' })

    result = FaceCloak::AuthenticateAccount.new(app.config).call(**@credentials)

    _(result.username).must_equal 'alice'
    _(result.auth_token).must_equal 'opaque.api.token'
  end

  it 'SAD: raises UnauthorizedError on invalid credentials' do
    WebMock.stub_request(:post, "#{API_URL}/auth/authenticate")
           .with(body: FaceCloak::SignedMessage.sign(@api_credentials).to_json)
           .to_return(status: 403, body: { message: 'Invalid credentials' }.to_json)

    _(proc {
      FaceCloak::AuthenticateAccount.new(app.config).call(**@credentials)
    }).must_raise FaceCloak::AuthenticateAccount::UnauthorizedError
  end
end
