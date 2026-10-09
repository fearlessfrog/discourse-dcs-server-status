# frozen_string_literal: true

module ::Jobs
  class DcsServerStatusRefresh < ::Jobs::Base
    def execute(_args)
      ::DcsServerStatus::Refresh.call(force: true)
    end
  end
end
