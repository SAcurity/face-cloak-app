# frozen_string_literal: true

require 'roda'
require_relative 'app'

module FaceCloak
  # Web controller for the FaceCloak Web App
  class App < Roda
    route('images') do |routing|
      require_login!(routing)
      auth_token = @current_account.auth_token

      # GET /images/new
      routing.is 'new' do
        view 'images/new'
      end

      routing.on String do |image_id|
        %w[protected raw].each do |variant|
          routing.on variant do
            routing.get do
              if image_asset_request?
                image_variant_response(routing, image_id, variant, auth_token)
              else
                image_detail_response(routing, image_id, variant, auth_token)
              end
            end
          end
        end

        # GET /images/[image_id]/logs
        routing.on 'logs' do
          routing.get do
            logs = GetImageLogs.new(FaceCloak::App.config).call(
              image_id: image_id,
              auth_token: auth_token
            )
            view 'images/logs', locals: { image_id: image_id, logs: logs }
          rescue StandardError => e
            flash[:error] = "Could not load logs: #{e.message}"
            routing.redirect '/'
          end
        end

        # POST /images/[image_id]/faces/[face_id]
        routing.on 'faces', String do |face_id|
          routing.on 'respond' do
            routing.post do
              return_view = safe_image_return_view(routing.params)
              RespondFaceAssignment.new(FaceCloak::App.config).call(
                face_id: face_id, cloak_type: routing.params['cloak_type'], auth_token: auth_token
              )
              flash[:notice] = 'Masking preference saved'
              routing.redirect "/images/#{image_id}/#{return_view}"
            rescue StandardError => e
              flash[:error] = "Could not save masking preference: #{e.message}"
              return_view = safe_image_return_view(routing.params)
              routing.redirect "/images/#{image_id}/#{return_view}"
            end
          end

          routing.on 'decline' do
            routing.post do
              return_view = safe_image_return_view(routing.params)
              DeclineFaceAssignment.new(FaceCloak::App.config).call(face_id: face_id, auth_token: auth_token)
              flash[:notice] = 'Assignment declined'
              routing.redirect "/images/#{image_id}/#{return_view}"
            rescue StandardError => e
              flash[:error] = "Could not decline assignment: #{e.message}"
              return_view = safe_image_return_view(routing.params)
              routing.redirect "/images/#{image_id}/#{return_view}"
            end
          end

          routing.post do
            assigned_user_id = routing.params['assigned_user_id'].to_s.strip
            assigning_self = routing.params['assign_self'].to_s == 'true'
            if assigned_user_id == @current_account.id.to_s && !assigning_self
              flash[:error] = 'Use [Myself] button to assign your own face'
              routing.redirect "/images/#{image_id}/raw"
            end

            AssignFace.new(FaceCloak::App.config).call(
              face_id: face_id, assigned_user_id: assigned_user_id, auth_token: auth_token
            )
            flash[:notice] = 'Face assigned successfully'
            routing.redirect "/images/#{image_id}/raw"
          rescue StandardError => e
            flash[:error] = "Could not assign face: #{e.message}"
            routing.redirect "/images/#{image_id}/raw"
          end
        end

        # GET /images/[image_id]
        routing.is do
          routing.get do
            requested_view = routing.params['view'].to_s
            requested_view = nil unless %w[protected raw].include?(requested_view)
            image_detail_redirect(routing, image_id, requested_view, auth_token)
          end
        end
      end

      # GET /images
      routing.get do
        routing.redirect '/'
      end

      # POST /images
      routing.post do
        image_file = routing.params['file']
        UploadImage.new(FaceCloak::App.config).call(
          auth_token: auth_token,
          file_path: image_file[:tempfile].path,
          file_name: image_file[:filename]
        )
        flash[:notice] = 'Image posted successfully'
        routing.redirect '/'
      rescue StandardError => e
        flash[:error] = "Could not post image: #{e.message}"
        routing.redirect '/images/new'
      end
    end
  end
end
