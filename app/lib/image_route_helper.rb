# frozen_string_literal: true

module FaceCloak
  # Shared route helpers for image detail pages and proxied image variants.
  module ImageRouteHelper
    def image_asset_request?
      accept = request.env['HTTP_ACCEPT'].to_s
      accept.include?('image/') && !accept.include?('text/html')
    end

    def image_variant_response(routing, image_id, variant, auth_token)
      api_path = image_variant_api_path(routing, image_id, variant)
      api_res = HTTP.auth("Bearer #{auth_token}").get("#{FaceCloak::App.config.API_URL}#{api_path}")

      routing.halt(api_res.code, api_res.body.to_s) unless api_res.code == 200

      response['Content-Type'] = api_res.headers['Content-Type']
      api_res.body.to_s
    end

    def image_variant_api_path(routing, image_id, variant)
      return "/images/#{image_id}/raw" if variant == 'raw'
      return "/images/#{image_id}?self_preview=true" if routing.params['self_preview'] == 'true'

      "/images/#{image_id}"
    end

    def image_detail_redirect(routing, image_id, requested_view, auth_token)
      image_data = find_image_or_not_found(image_id, auth_token)
      return "Image #{image_id} not found in API" unless image_data

      can_manage_faces = manageable_image?(image_data, @current_account)
      canonical_view = requested_view || 'cloak'
      canonical_view = 'cloak' if canonical_view == 'raw' && !can_manage_faces

      routing.redirect "/images/#{image_id}/#{canonical_view}"
    end

    def image_detail_response(routing, image_id, view_type, auth_token)
      image_data = find_image_or_not_found(image_id, auth_token)
      return "Image #{image_id} not found in API" unless image_data

      can_manage_faces = manageable_image?(image_data, @current_account)
      routing.redirect "/images/#{image_id}/cloak" if view_type == 'raw' && !can_manage_faces

      begin
        view 'images/show', locals: image_detail_locals(image_data, image_id, auth_token, can_manage_faces, view_type)
      rescue StandardError => e
        App.logger.error "IMAGE VIEW RENDERING FAILED: #{e.class} - #{e.message}\n#{e.backtrace[0..10].join("\n")}"
        raise e
      end
    end

    def safe_image_return_view(params)
      return_view = params['return_view'].to_s
      %w[raw cloak].include?(return_view) ? return_view : 'cloak'
    end

    def find_image_or_not_found(image_id, auth_token)
      image_data = GetImage.new(FaceCloak::App.config).call(image_id, auth_token: auth_token)
      response.status = 404 unless image_data
      image_data
    end

    def image_logs(image_id, auth_token)
      GetImageLogs.new(FaceCloak::App.config).call(image_id: image_id, auth_token: auth_token)
    rescue StandardError => e
      App.logger.warn "IMAGE LOG FALLBACK FAILED: #{e.inspect}"
      []
    end

    def image_detail_locals(image_data, image_id, auth_token, can_manage_faces, view_type)
      {
        image: image_data,
        image_logs: image_logs(image_id, auth_token),
        accounts_by_id: log_accounts_by_id(auth_token),
        is_owner: can_manage_faces, # 'is_owner' in view now means 'can manage faces'
        view_type: view_type,
        preview_cloak: request.params['preview'].to_s == 'cloak'
      }
    end

    def manageable_image?(image, account = @current_account)
      image_owned_by_current?(image, account) || admin_account?(account)
    end

    def admin_account?(account)
      capabilities = account&.capabilities || {}
      capabilities['is_admin'] || capabilities[:is_admin]
    end
  end
end
