# frozen_string_literal: true

module FaceCloak
  # Helper to generate avatar placeholders
  module AvatarHelper
    def avatar_for(username, size: 40)
      initial = username.to_s[0]&.upcase || '?'
      color = color_for(username)

      "<div class='avatar-circle' style='width: #{size}px; height: #{size}px; background-color: #{color} !important; font-size: #{size / 2}px; border: 1px solid rgba(255,255,255,0.12);'>
        #{initial}
      </div>"
    end

    private

    def color_for(username)
      # Deterministic, muted palette that avoids using the primary action color
      sum = username.to_s.each_byte.sum
      colors = %w[
        #6b6f77
        #7f8a92
        #9aa3ab
        #a08d79
        #8aa28a
        #b29aa6
      ]
      colors[sum % colors.length]
    end
  end
end
