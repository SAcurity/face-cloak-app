# frozen_string_literal: true

require_relative '../spec_helper'

describe 'SignedMessage' do
  before do
    @saved_key = FaceCloak::SignedMessage.instance_variable_get(:@signing_key)
    @signing_key = RbNaCl::SigningKey.generate
    FaceCloak::SignedMessage.setup(Base64.strict_encode64(@signing_key.to_bytes))
  end

  after do
    FaceCloak::SignedMessage.instance_variable_set(:@signing_key, @saved_key)
  end

  it 'BAD: raises KeypairError when setup with a bad signing key' do
    _(proc { FaceCloak::SignedMessage.setup(nil) })
      .must_raise FaceCloak::SignedMessage::KeypairError
    _(proc { FaceCloak::SignedMessage.setup('not-base64') })
      .must_raise FaceCloak::SignedMessage::KeypairError
  end

  it 'HAPPY: signs a message that the verify key can verify' do
    message = { username: 'alice', password: 'password123' }

    signed = FaceCloak::SignedMessage.sign(message)

    _(signed[:data]).must_equal message
    signature = Base64.strict_decode64(signed[:signature])
    _(@signing_key.verify_key.verify(signature, signed[:data].to_json)).must_equal true
  end

  it 'SECURITY: signature rejects tampered message data' do
    signed = FaceCloak::SignedMessage.sign({ username: 'alice' })
    signature = Base64.strict_decode64(signed[:signature])

    _(proc {
      @signing_key.verify_key.verify(signature, { username: 'mallory' }.to_json)
    }).must_raise RbNaCl::BadSignatureError
  end

  it 'HAPPY: signing is deterministic for the same message' do
    message = { username: 'alice', password: 'password123' }

    _(FaceCloak::SignedMessage.sign(message)).must_equal FaceCloak::SignedMessage.sign(message)
  end
end
