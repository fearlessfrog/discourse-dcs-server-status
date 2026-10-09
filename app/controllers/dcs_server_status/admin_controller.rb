# frozen_string_literal: true

module ::DcsServerStatus
  # Administrators need diagnostics while configuring a disabled plugin.
  # rubocop:disable Discourse/Plugins/CallRequiresPlugin
  class AdminController < ::Admin::AdminController
    def show
      response.headers["Cache-Control"] = "no-store"
      render json: Store.diagnostics
    end

    def refresh
      unless Configuration.new.ready?
        raise Discourse::InvalidParameters.new(:configuration)
      end
      RateLimiter.new(
        current_user,
        "dcs-server-status-refresh",
        1,
        30.seconds
      ).performed!
      Jobs.enqueue(:dcs_server_status_refresh)
      render json: { queued: true }, status: :accepted
    end
  end
  # rubocop:enable Discourse/Plugins/CallRequiresPlugin
end
