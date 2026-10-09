# frozen_string_literal: true

require "cgi"
require "net/http"
require "openssl"
require "time"
require "timeout"
require "uri"

module ::DcsServerStatus
  class EdClient
    HOST = "www.digitalcombatsimulator.com"
    LOGIN_URL = "https://#{HOST}/en/auth/"
    LIST_URL = "https://#{HOST}/en/personal/server/?ajax=y"
    MAX_BYTES = 10 * 1024 * 1024
    MAX_REDIRECTS = 3

    class Error < StandardError
      attr_reader :code

      def initialize(code)
        @code = code
        super(code)
      end
    end

    attr_reader :cookies

    def initialize(config, cookies: [])
      @config = config
      @cookies = cookies || []
    end

    def servers
      Timeout.timeout(45) do
        if cookies.any?
          begin
            return fetch_servers
          rescue Error => error
            raise unless error.code == "authentication_failed"
            @cookies = []
          end
        end

        authenticate
        fetch_servers
      end
    rescue Timeout::Error, Net::OpenTimeout, Net::ReadTimeout
      raise Error.new("timeout")
    rescue SocketError, IOError, SystemCallError, OpenSSL::SSL::SSLError
      raise Error.new("network_error")
    end

    private

    def authenticate
      response = request(URI(LOGIN_URL))
      document = Nokogiri.HTML(response[:body])
      form =
        document
          .css("form")
          .find { |candidate| candidate.at_css('input[name="USER_LOGIN"]') }
      raise Error.new("login_form_changed") if !form
      if form
           .css("input[name]")
           .any? { |input| input["name"].downcase.include?("captcha") }
        raise Error.new("interactive_login_required")
      end

      fields =
        form
          .css('input[type="hidden"][name]')
          .to_h { |input| [input["name"], input["value"].to_s] }
      fields.merge!(
        "AUTH_FORM" => "Y",
        "TYPE" => "AUTH",
        "backurl" => "/en/personal/server/?ajax=y",
        "USER_LOGIN" => @config.username,
        "USER_PASSWORD" => @config.password,
        "USER_REMEMBER" => "Y",
        "Login" => "Authorize"
      )

      uri = URI.join(response[:uri].to_s, form["action"].presence || LOGIN_URL)
      request(uri, method: :post, fields: fields)
    end

    def fetch_servers
      response = request(URI(LIST_URL))
      body = response[:body]
      if body.match?(/<form\b/i) && body.include?("USER_LOGIN")
        raise Error.new("authentication_failed")
      end

      data = JSON.parse(body)
      if !data.is_a?(Hash) || !data["SERVERS"].is_a?(Array) ||
           !data["SERVERS"].all? { |server|
             server.is_a?(Hash) && server["NAME"].is_a?(String)
           }
        raise Error.new("invalid_response")
      end
      data["SERVERS"]
    rescue JSON::ParserError
      raise Error.new("invalid_response")
    end

    def request(uri, method: :get, fields: nil, redirects: 0)
      if uri.scheme != "https" || uri.host != HOST || uri.port != 443 ||
           uri.userinfo
        raise Error.new("unsafe_redirect")
      end
      raise Error.new("too_many_redirects") if redirects > MAX_REDIRECTS

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.open_timeout = 5
      http.read_timeout = 10
      http.write_timeout = 10
      http.max_retries = 0

      message =
        method == :post ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
      message["User-Agent"] = "Discourse-DCS-Server-Status/0.1.0"
      message["Accept"] = "application/json, text/html;q=0.9"
      cookie_header = cookies_for(uri)
      message["Cookie"] = cookie_header if cookie_header.present?
      message.set_form_data(fields) if method == :post

      body = +""
      response = nil
      http.request(message) do |incoming|
        response = incoming
        incoming.read_body do |chunk|
          if body.bytesize + chunk.bytesize > MAX_BYTES
            raise Error.new("response_too_large")
          end
          body << chunk
        end
      end
      remember_cookies(response, uri)

      case response.code.to_i
      when 301, 302, 303, 307, 308
        location = response["location"]
        raise Error.new("invalid_response") if location.blank?
        preserve_method = [307, 308].include?(response.code.to_i)
        request(
          URI.join(uri.to_s, location),
          method: preserve_method ? method : :get,
          fields: preserve_method ? fields : nil,
          redirects: redirects + 1
        )
      when 200
        { body: body, uri: uri }
      when 401, 403
        raise Error.new("authentication_failed")
      when 429
        raise Error.new("rate_limited")
      else
        raise Error.new("http_error")
      end
    rescue URI::InvalidURIError
      raise Error.new("unsafe_redirect")
    end

    def cookies_for(uri)
      @cookies.reject! do |cookie|
        cookie["expires_at"] && cookie["expires_at"] <= Time.now.to_i
      end
      cookies
        .select do |cookie|
          path = cookie["path"]
          uri.path == path ||
            uri.path.start_with?(path.end_with?("/") ? path : "#{path}/")
        end
        .sort_by { |cookie| -cookie["path"].length }
        .map { |cookie| "#{cookie["name"]}=#{cookie["value"]}" }
        .join("; ")
    end

    def remember_cookies(response, uri)
      response
        .get_fields("set-cookie")
        .to_a
        .each do |header|
          pair, *attributes = header.split(";").map(&:strip)
          name, value = pair.split("=", 2)
          next if name.blank? || value.nil? || name.match?(/[\s,;\r\n]/)

          attributes =
            attributes.to_h do |attribute|
              key, val = attribute.split("=", 2)
              [key.downcase, val]
            end
          domain = attributes["domain"]&.downcase&.delete_prefix(".")
          if domain && domain != HOST && domain != "digitalcombatsimulator.com"
            next
          end

          path = attributes["path"]
          path = uri.path.sub(%r{/[^/]*\z}, "/") unless path&.start_with?("/")
          path = "/" if path.blank?
          expires_at = nil
          if attributes["max-age"]&.match?(/\A-?\d+\z/)
            expires_at = Time.now.to_i + attributes["max-age"].to_i
          elsif attributes["expires"]
            expires_at =
              begin
                Time.httpdate(attributes["expires"]).to_i
              rescue StandardError
                nil
              end
          end

          @cookies.reject! do |cookie|
            cookie["name"] == name && cookie["path"] == path
          end
          next if expires_at && expires_at <= Time.now.to_i
          @cookies << {
            "name" => name,
            "value" => value,
            "path" => path,
            "expires_at" => expires_at
          }
        end
    end
  end
end
