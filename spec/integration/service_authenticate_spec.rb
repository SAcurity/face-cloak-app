# frozen_string_literal: true

require_relative '../spec_helper'

describe 'AuthenticateAccount service' do
  before do
    @credentials = { username: 'alice', password: 'password123' }
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: authenticates through the API' do
    response = {
      type: 'account',
      attributes: { id: 1, username: 'alice', email: 'alice@example.com' },
      include: { system_roles: ['member'] }
    }
    WebMock.stub_request(:post, "#{API_URL}/auth/authenticate")
           .with(body: @credentials.to_json)
           .to_return(status: 200, body: response.to_json, headers: { 'content-type' => 'application/json' })

    account = FaceCloak::AuthenticateAccount.new(app.config).call(**@credentials)

    _(account['username']).must_equal 'alice'
    _(account['include']['system_roles']).must_equal ['member']
  end

  it 'SAD: raises UnauthorizedError on invalid credentials' do
    WebMock.stub_request(:post, "#{API_URL}/auth/authenticate")
           .with(body: @credentials.to_json)
           .to_return(status: 403, body: { message: 'Invalid credentials' }.to_json)

    _(proc {
      FaceCloak::AuthenticateAccount.new(app.config).call(**@credentials)
    }).must_raise FaceCloak::AuthenticateAccount::UnauthorizedError
  end
end
