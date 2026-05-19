# frozen_string_literal: true

require_relative '../spec_helper'

describe 'SecureMessage' do
  it 'HAPPY: encrypts and decrypts JSON-serializable values' do
    message = { 'id' => 1, 'username' => 'alice' }

    encrypted = FaceCloak::SecureMessage.encrypt(message).to_s
    decrypted = FaceCloak::SecureMessage.new(encrypted).decrypt

    _(encrypted).wont_equal message.to_json
    _(decrypted).must_equal message
  end

  it 'SAD: rejects tampered ciphertext' do
    encrypted = FaceCloak::SecureMessage.encrypt({ 'id' => 1 }).to_s
    tampered = "#{encrypted[0...-2]}xx"

    _(proc {
      FaceCloak::SecureMessage.new(tampered).decrypt
    }).must_raise StandardError
  end
end
