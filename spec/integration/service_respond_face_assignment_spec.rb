# frozen_string_literal: true

require_relative '../spec_helper'

describe 'RespondFaceAssignment service' do
  it 'posts the cloak choice with bearer auth' do
    stub_request(:post, "#{FaceCloak::App.config.API_URL}/face_records/face-1/respond")
      .with(
        body: { cloak_type: 'mask' }.to_json,
        headers: {
          'Authorization' => 'Bearer assignee-token'
        }
      )
      .to_return(status: 200, body: {}.to_json, headers: { 'content-type' => 'application/json' })

    result = FaceCloak::RespondFaceAssignment.new(app.config).call(
      face_id: 'face-1',
      cloak_type: 'mask',
      auth_token: 'assignee-token'
    )

    _(result).must_equal({})
  end
end
