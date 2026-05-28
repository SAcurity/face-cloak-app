# frozen_string_literal: true

require 'ostruct'

module FaceCloak
  # Parser model that wraps a FaceRecord API envelope.
  class Face
    attr_reader :id, :attributes, :policies

    def self.from_api(envelope)
      new(envelope)
    end

    def initialize(envelope)
      @attributes = envelope['attributes'] || envelope
      @id = @attributes['id']
      @policies = OpenStruct.new(envelope['policies'] || {}) # rubocop:disable Style/OpenStructUse
    end

    private_class_method :new

    def [](key)
      @attributes[key.to_s]
    end

    def respond_to_missing?(method_name, include_private = false)
      @attributes.key?(method_name.to_s) || super
    end

    def method_missing(method_name, *args, &)
      if @attributes.key?(method_name.to_s)
        @attributes[method_name.to_s]
      else
        super
      end
    end
  end
end
