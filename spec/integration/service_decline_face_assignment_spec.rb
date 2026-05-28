# frozen_string_literal: true

require_relative '../spec_helper'

describe 'DeclineFaceAssignment service' do
  it 'posts the decline request with bearer auth' do
    stub_request(:post, "#{FaceCloak::App.config.API_URL}/face_records/face-1/decline")
      .with(
        body: '{}',
        headers: {
          'Authorization' => 'Bearer auth-token'
        }
      )
      .to_return(status: 200, body: {}.to_json, headers: { 'content-type' => 'application/json' })

    result = FaceCloak::DeclineFaceAssignment.new(app.config).call(
      face_id: 'face-1',
      auth_token: 'auth-token'
    )

    _(result).must_equal({})
  end
end
