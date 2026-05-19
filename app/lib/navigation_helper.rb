# frozen_string_literal: true

module FaceCloak
  # Helpers for navigation and URL logic
  module NavigationHelper
    def parent_path(path)
      parts = path.to_s.split('/').reject(&:empty?)
      return '/' if parts.length <= 1

      "/#{parts[0...-1].join('/')}"
    end
  end
end
