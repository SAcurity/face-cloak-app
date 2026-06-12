# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Security headers middleware' do
  it 'HAPPY: responses carry browser security headers' do
    get '/auth/login'

    _(last_response.headers['X-Frame-Options']).must_equal 'DENY'
    _(last_response.headers['X-Content-Type-Options']).must_equal 'nosniff'
    _(last_response.headers['X-XSS-Protection']).must_equal '1'
    _(last_response.headers['X-Permitted-Cross-Domain-Policies']).must_equal 'none'
    _(last_response.headers['Referrer-Policy']).must_equal 'origin-when-cross-origin'
  end

  it 'HAPPY: responses carry a strict Content-Security-Policy' do
    get '/auth/login'

    csp = last_response.headers['Content-Security-Policy']
    _(csp).wont_be_nil
    _(csp).must_include "default-src 'self'"
    _(csp).must_include "frame-ancestors 'none'"
    _(csp).must_include "object-src 'none'"
    _(csp).must_include 'report-uri /security/report_csp_violation'
    _(csp).wont_include 'unsafe-inline'
  end

  it 'HAPPY: CSP allows only the external sources used by the layout' do
    get '/auth/login'

    csp = last_response.headers['Content-Security-Policy']
    _(csp).must_match(%r{script-src [^;]*https://cdn\.jsdelivr\.net})
    _(csp).must_match(%r{style-src [^;]*https://cdn\.jsdelivr\.net})
    _(csp).must_match(%r{style-src [^;]*https://cdnjs\.cloudflare\.com})
    _(csp).must_match(%r{style-src [^;]*https://fonts\.googleapis\.com})
    _(csp).must_match(%r{font-src [^;]*https://cdnjs\.cloudflare\.com})
    _(csp).must_match(%r{font-src [^;]*https://fonts\.gstatic\.com})
    _(csp).must_match(/img-src [^;]*data:/)
    _(csp).must_match(%r{img-src [^;]*http://localhost:3000})
  end

  it 'HAPPY: accepts a CSP violation report' do
    post '/security/report_csp_violation', { 'csp-report' => {} }.to_json

    _(last_response.status).must_equal 204
    _(last_response.body).must_be_empty
  end
end
