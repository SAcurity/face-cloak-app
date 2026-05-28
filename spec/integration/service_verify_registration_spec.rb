# frozen_string_literal: true

require_relative '../spec_helper'

describe 'VerifyRegistration service' do
  before do
    @email = 'new.user@example.com'
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: sends email-only verification request to API' do
    WebMock.stub_request(:post, "#{API_URL}/auth/register")
           .with do |req|
             body = JSON.parse(req.body)
             token = body.fetch('verification_url').split('/').last
             payload = FaceCloak::SecureMessage.new(token).decrypt

             body['email'] == @email &&
               !body.key?('username') &&
               payload == { 'email' => @email }
           end
           .to_return(status: 202, body: { message: 'Verification email sent' }.to_json)

    result = FaceCloak::VerifyRegistration.new(app.config).call(email: @email)

    _(result[:email]).must_equal @email
    _(result[:verification_url]).must_match %r{/auth/register/}
  end

  it 'SAD: raises VerificationError on validation failure' do
    WebMock.stub_request(:post, "#{API_URL}/auth/register")
           .to_return(status: 400, body: { message: 'Email already registered' }.to_json)

    _(proc {
      FaceCloak::VerifyRegistration.new(app.config).call(email: @email)
    }).must_raise FaceCloak::VerifyRegistration::VerificationError
  end

  it 'BAD: raises ApiServerError on API failure' do
    WebMock.stub_request(:post, "#{API_URL}/auth/register")
           .to_return(status: 500, body: { message: 'Could not send verification email' }.to_json)

    _(proc {
      FaceCloak::VerifyRegistration.new(app.config).call(email: @email)
    }).must_raise FaceCloak::VerifyRegistration::ApiServerError
  end
end
