# frozen_string_literal: true

module FaceCloak
  # Helper to generate avatar placeholders
  module AvatarHelper
    def avatar_for(username, size: 40)
      initial = username.to_s[0]&.upcase || '?'
      color = color_for(username)
      
      "<div class='avatar-circle' style='width: #{size}px; height: #{size}px; background-color: #{color}; font-size: #{size / 2}px;'>
        #{initial}
      </div>"
    end

    private

    def color_for(username)
      # Deterministic color based on username
      hash = username.hash.abs
      colors = %w[#0066cc #555555 #1d1d1f #7a7a7a #333333]
      colors[hash % colors.length]
    end
  end
end
