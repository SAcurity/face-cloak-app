# frozen_string_literal: true

module FaceCloak
  # Gets metadata for a single image by searching the list.
  class GetImage
    def initialize(config)
      @service = ListImages.new(config)
    end

    def call(image_id)
      images = @service.call
      images.find { |img| img['id'] == image_id }
    end
  end
end
