# frozen_string_literal: true

require_relative '../spec_helper'

describe 'AuthenticateSsoAccount service' do
  before do
    @payload = {
      provider: 'google',
      id_token: 'google.id.token',
      jwks: { 'keys' => [{ 'kid' => 'kid-1' }] }
    }
    @api_response = {
      type: 'authenticated_account',
      attributes: {
        account: {
          type: 'account',
          attributes: { id: 9, username: 'sso_user', email: 'sso@example.com' },
          include: { system_roles: ['member'] }
        },
        auth_token: 'full.scoped.session.token'
      }
    }
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: posts Google SSO payload to the API' do
    WebMock.stub_request(:post, "#{API_URL}/auth/sso")
           .with(body: FaceCloak::SignedMessage.sign(@payload).to_json)
           .to_return(status: 200, body: @api_response.to_json, headers: { 'content-type' => 'application/json' })

    account = FaceCloak::AuthenticateSsoAccount.new(app.config).call(**@payload)

    _(account.username).must_equal 'sso_user'
    _(account.auth_token).must_equal 'full.scoped.session.token'
  end

  it 'SAD: raises UnauthorizedError on rejected SSO payload' do
    WebMock.stub_request(:post, "#{API_URL}/auth/sso")
           .with(body: FaceCloak::SignedMessage.sign(@payload).to_json)
           .to_return(status: 403, body: { message: 'Invalid SSO token' }.to_json)

    _(proc {
      FaceCloak::AuthenticateSsoAccount.new(app.config).call(**@payload)
    }).must_raise FaceCloak::AuthenticateSsoAccount::UnauthorizedError
  end

  it 'SAD: handles API validation errors without leaking ApiError' do
    WebMock.stub_request(:post, "#{API_URL}/auth/sso")
           .with(body: FaceCloak::SignedMessage.sign(@payload).to_json)
           .to_return(status: 400, body: { message: 'Bad SSO request' }.to_json)

    _(proc {
      FaceCloak::AuthenticateSsoAccount.new(app.config).call(**@payload)
    }).must_raise FaceCloak::AuthenticateSsoAccount::UnauthorizedError
  end
end
