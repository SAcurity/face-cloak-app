# frozen_string_literal: true

require './require_app'
require 'rake/testtask'

task :print_env do
  puts "Environment: #{ENV['RACK_ENV'] || 'development'}"
end

task default: :spec

desc 'Run application console (pry)'
task console: [:print_env] do
  sh 'pry -r ./spec/test_load_all'
end

desc 'Run rubocop to check style'
task :style do
  sh 'rubocop .'
end

desc 'Test all the specs'
Rake::TestTask.new(:spec) do |t|
  t.pattern = 'spec/**/*_spec.rb'
  t.warning = false
end

desc 'Rerun tests on live code changes'
task :respec do
  sh 'rerun -c rake spec'
end

desc 'Update vulnerabilities list and audit gems'
task :audit do
  sh 'bundle audit check --update'
end

desc 'Checks for release'
task release_check: %i[spec style audit] do
  puts "\nReady for release!"
end

namespace :run do
  desc 'Run Web App in development mode'
  task dev: [:print_env] do
    sh 'puma -p 9292'
  end
end

task :load_lib do
  require_app('lib')
end

namespace :generate do
  desc 'Create cookie secret'
  task session_secret: [:load_lib] do
    require './app/lib/secure_session'
    puts "New SESSION_SECRET (base64): #{FaceCloak::SecureSession.generate_secret}"
  end
end

namespace :newkey do
  desc 'Create rbnacl SecretBox key for SecureMessage (sessions, tokens)'
  task :msg do
    require './app/lib/secure_message'
    puts "New MSG_KEY (base64): #{FaceCloak::SecureMessage.generate_key}"
  end

  desc 'Create Ed25519 signing keypair for signed client requests'
  task :signing do
    require 'base64'
    require 'rbnacl'

    signing_key = RbNaCl::SigningKey.generate
    puts "SIGNING_KEY (app only): #{Base64.strict_encode64(signing_key.to_bytes)}"
    puts "VERIFY_KEY (API only): #{Base64.strict_encode64(signing_key.verify_key.to_bytes)}"
  end
end

namespace :session do
  desc 'Wipe all sessions stored in Redis'
  task wipe: [:load_lib] do
    require 'redis'
    puts 'Deleting all sessions from Redis session store'
    wiped = FaceCloak::SecureSession.wipe_redis_sessions
    puts "#{wiped.count} sessions deleted"
  end
end

namespace :url do
  # usage: $ rake url:integrity URL=http://example.org/script.js
  desc 'Generate SRI integrity hash for a URL (argument: URL=...)'
  task :integrity do
    sha384 = `curl -L -s #{ENV.fetch('URL', nil)} | openssl dgst -sha384 -binary | openssl enc -base64 -A`
    puts "sha384-#{sha384}"
  end
end
