# frozen_string_literal: true

require 'roda'
require_relative 'app'

module FaceCloak
  # Web controller for the FaceCloak Web App
  class App < Roda
    route('images') do |routing|
      require_login!(routing)
      current_account_id = @current_account['id']

      # GET /images/new
      routing.is 'new' do
        view 'images/new'
      end

      routing.on String do |image_id|
        # GET /images/[image_id]/raw_image
        routing.on 'raw_image' do
          routing.get do
            api_res = HTTP.headers('X-Actor-Id' => current_account_id.to_s)
                          .get("#{FaceCloak::App.config.API_URL}/images/#{image_id}/raw")
            
            routing.halt(api_res.code, api_res.body.to_s) unless api_res.code == 200
            
            response['Content-Type'] = api_res.headers['Content-Type']
            api_res.body.to_s
          end
        end

        # GET /images/[image_id]/logs
        routing.on 'logs' do
          routing.get do
            logs = GetImageLogs.new(FaceCloak::App.config).call(
              image_id: image_id,
              current_account_id: current_account_id
            )
            view 'images/logs', locals: { image_id: image_id, logs: logs }
          rescue StandardError => e
            flash[:error] = "Could not load logs: #{e.message}"
            routing.redirect '/'
          end
        end

        # POST /images/[image_id]/faces/[face_id]
        routing.on 'faces', String do |face_id|
          routing.post do
            AssignFace.new(FaceCloak::App.config).call(
              face_id: face_id,
              assigned_user_id: routing.params['assigned_user_id'],
              current_account_id: current_account_id
            )
            flash[:notice] = 'Face assigned successfully'
            routing.redirect "/images/#{image_id}?view=raw"
          rescue StandardError => e
            flash[:error] = "Could not assign face: #{e.message}"
            routing.redirect "/images/#{image_id}?view=raw"
          end
        end

        # GET /images/[image_id]
        routing.is do
          routing.get do
            image_data = GetImage.new(FaceCloak::App.config).call(
              image_id, 
              current_account_id: current_account_id
            )
            unless image_data
              response.status = 404
              next "Image #{image_id} not found in API"
            end

            is_owner = image_data['owner_id'].to_i == current_account_id.to_i
            view_type = routing.params['view'] || 'protected'

            view 'images/show', locals: { 
              image: image_data, 
              is_owner: is_owner, 
              view_type: view_type 
            }
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
          current_account_id: current_account_id,
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
