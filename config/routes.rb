# frozen_string_literal: true

DcsServerStatus::Engine.routes.draw do
  get "/dcs-status" => "status#show", :defaults => { format: :json }
  get "/admin/plugins/discourse-dcs-server-status/connection" => "admin#show",
      :defaults => {
        format: :json
      }
  post "/admin/plugins/discourse-dcs-server-status/refresh" => "admin#refresh",
       :defaults => {
         format: :json
       }
end

Discourse::Application.routes.draw { mount ::DcsServerStatus::Engine, at: "/" }
