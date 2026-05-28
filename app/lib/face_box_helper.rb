# frozen_string_literal: true

module FaceCloak
  # Converts API face box metadata into CSS percentage positioning.
  module FaceBoxHelper
    BOX_KEYS = %w[bounding_box bbox box bounds].freeze
    X_KEYS = %w[x left x_min xmin].freeze
    Y_KEYS = %w[y top y_min ymin].freeze
    WIDTH_KEYS = %w[width w].freeze
    HEIGHT_KEYS = %w[height h].freeze
    X_MAX_KEYS = %w[x_max xmax right].freeze
    Y_MAX_KEYS = %w[y_max ymax bottom].freeze
    IMAGE_WIDTH_KEYS = %w[width image_width original_width].freeze
    IMAGE_HEIGHT_KEYS = %w[height image_height original_height].freeze

    def face_box_style(face, image)
      box = face_box(face)
      return nil unless box

      normalized = normalize_box(box, image)
      return nil unless normalized

      box_style(normalized)
    end

    private

    def face_box(face)
      raw_box = first_present(face, BOX_KEYS)
      return box_from_hash(raw_box) if raw_box.is_a?(Hash)
      return box_from_array(raw_box) if raw_box.is_a?(Array)

      box_from_hash(face)
    end

    def box_from_hash(source)
      x = numeric_field(source, X_KEYS)
      y = numeric_field(source, Y_KEYS)
      width, height = box_size(source, x, y)
      box = [x, y, width, height]

      box.all? ? box : nil
    end

    def box_size(source, x_position, y_position)
      [
        numeric_field(source, WIDTH_KEYS) || distance_field(source, X_MAX_KEYS, x_position),
        numeric_field(source, HEIGHT_KEYS) || distance_field(source, Y_MAX_KEYS, y_position)
      ]
    end

    def distance_field(source, keys, start)
      finish = numeric_field(source, keys)
      finish - start if start && finish
    end

    def box_from_array(source)
      return nil unless source.length >= 4

      source.first(4).map { |value| numeric_value(value) }
    end

    def normalize_box(box, image)
      return clamp_box(box.map { |value| value * 100 }) if normalized_box?(box)

      dimensions = image_dimensions(image)
      return clamp_box(percent_from_dimensions(box, dimensions)) if dimensions
      return clamp_box(box) if percentage_box?(box)

      nil
    end

    def image_dimensions(image)
      width = numeric_field(image, IMAGE_WIDTH_KEYS)
      height = numeric_field(image, IMAGE_HEIGHT_KEYS)

      [width, height] if width&.positive? && height&.positive?
    end

    def percent_from_dimensions(box, dimensions)
      x, y, width, height = box
      image_width, image_height = dimensions

      [
        (x / image_width) * 100,
        (y / image_height) * 100,
        (width / image_width) * 100,
        (height / image_height) * 100
      ]
    end

    def normalized_box?(box)
      box.all? { |value| value <= 1.0 }
    end

    def percentage_box?(box)
      x, y, width, height = box

      x + width <= 100 && y + height <= 100
    end

    def numeric_field(source, keys)
      numeric_value(first_present(source, keys))
    end

    def numeric_value(value)
      return nil if value.nil? || value.to_s.strip.empty?

      Float(value)
    rescue ArgumentError, TypeError
      nil
    end

    def clamp_box(box)
      x, y, width, height = box
      x = x.clamp(0, 100)
      y = y.clamp(0, 100)
      width = width.clamp(1, 100 - x)
      height = height.clamp(1, 100 - y)
      [x, y, width, height]
    end

    def box_style(box)
      x, y, width, height = box

      [
        "left: #{format('%.4f', x)}%",
        "top: #{format('%.4f', y)}%",
        "width: #{format('%.4f', width)}%",
        "height: #{format('%.4f', height)}%"
      ].join('; ')
    end
  end
end
