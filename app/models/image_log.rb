# frozen_string_literal: true

module FaceCloak
  # Parser model for image access logs.
  class ImageLog
    attr_reader :id, :action, :created_at, :actor

    def self.from_api(envelope)
      new(envelope)
    end

    def initialize(envelope)
      attrs = envelope['attributes'] || envelope
      @id = attrs['id']
      @action = attrs['action']
      @created_at = attrs['created_at']
      @actor = attrs['actor']
    end

    private_class_method :new

    def actor_username
      @actor&.dig('username')
    end

    def [](key)
      @attributes[key.to_s]
    end
  end
end
