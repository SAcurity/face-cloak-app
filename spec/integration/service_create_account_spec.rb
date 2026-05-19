# frozen_string_literal: true

require_relative '../spec_helper'

describe 'CreateAccount service' do
  before do
    @account = { email: 'new.user@example.com', username: 'new_user', password: 'password123' }
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: posts registration data to the API' do
    response = { message: 'Account created', data: { attributes: { username: 'new_user' } } }
    WebMock.stub_request(:post, "#{API_URL}/accounts")
           .with(body: @account.to_json)
           .to_return(status: 201, body: response.to_json, headers: { 'content-type' => 'application/json' })

    result = FaceCloak::CreateAccount.new(app.config).call(**@account)

    _(result['message']).must_equal 'Account created'
  end

  it 'SAD: raises InvalidAccount on API validation error' do
    WebMock.stub_request(:post, "#{API_URL}/accounts")
           .with(body: @account.to_json)
           .to_return(status: 400, body: { message: 'Username or email already exists' }.to_json)

    _(proc {
      FaceCloak::CreateAccount.new(app.config).call(**@account)
    }).must_raise FaceCloak::CreateAccount::InvalidAccount
  end
end
