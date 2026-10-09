# frozen_string_literal: true

require "uri"

module ::DcsServerStatus
  class HeaderUrlValidator
    def initialize(opts = {})
      @max = opts.fetch(:max, 2048).to_i
    end

    def valid_value?(value)
      return true if value.blank?
      return false if value.length > @max
      return false if value.match?(/[\s\x00-\x1f\x7f\\]/)

      uri = URI.parse(value)
      if value.start_with?("/")
        !value.start_with?("//") && uri.host.nil? && uri.scheme.nil?
      else
        uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil? &&
          uri.port.between?(1, 65_535)
      end
    rescue URI::Error, ArgumentError
      false
    end

    def error_message
      I18n.t("dcs_server_status.invalid_header_url")
    end
  end
end
