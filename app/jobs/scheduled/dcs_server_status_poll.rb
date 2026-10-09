# frozen_string_literal: true

module ::Jobs
  class DcsServerStatusPoll < ::Jobs::Scheduled
    every 1.minute

    def execute(_args)
      ::DcsServerStatus::Refresh.call
    end
  end
end
