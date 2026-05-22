# frozen_string_literal: true

require_relative '../spec_helper'

describe 'RegistrationToken' do
  it 'HAPPY: encrypts and decrypts email-only verification payload' do
    token = FaceCloak::RegistrationToken.new(email: 'alice@example.com')
    loaded = FaceCloak::RegistrationToken.load(token.to_s)

    _(loaded.email).must_equal 'alice@example.com'
  end

  it 'SECURITY: payload does not contain username or password' do
    token = FaceCloak::RegistrationToken.new(email: 'alice@example.com')
    payload = FaceCloak::SecureMessage.new(token.to_s).decrypt

    _(payload.keys).must_equal ['email']
  end

  it 'SAD: rejects invalid token strings' do
    _(proc {
      FaceCloak::RegistrationToken.load('not-a-real-token')
    }).must_raise FaceCloak::RegistrationToken::InvalidTokenError
  end
end
