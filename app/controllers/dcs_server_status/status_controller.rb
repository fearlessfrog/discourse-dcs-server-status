# frozen_string_literal: true

module ::DcsServerStatus
  class StatusController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    def show
      response.headers["Cache-Control"] = "no-store"
      render json: Store.public_status
    end
  end
end
