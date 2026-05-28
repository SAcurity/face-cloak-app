# frozen_string_literal: true

require 'ostruct'

module FaceCloak
  # Parser model that wraps an Image API envelope.
  class Image
    attr_reader :id, :file_name, :description, :policies, :owner, :faces, :attributes
    attr_accessor :logs

    def self.from_api(envelope)
      new(envelope)
    end

    def initialize(envelope)
      @attributes = envelope['attributes'] || envelope
      @id = @attributes['id']
      @file_name = @attributes['file_name']
      @description = @attributes['description']
      @owner = @attributes['owner']
      @policies = OpenStruct.new(envelope['policies'] || {}) # rubocop:disable Style/OpenStructUse
      @faces = parse_faces(envelope)
      @logs = parse_logs(envelope)
    end

    private_class_method :new

    def parse_faces(envelope)
      (envelope.dig('include', 'faces') || envelope['faces'] || []).map do |face|
        Face.from_api(face)
      end
    end

    def parse_logs(envelope)
      (envelope.dig('include', 'logs') || envelope['logs'] || []).map do |log|
        ImageLog.from_api(log)
      end
    end

    def owner_id
      @owner&.dig('id')
    end

    def owner_username
      @owner&.dig('username')
    end

    def [](key)
      @attributes[key.to_s]
    end
  end
end
