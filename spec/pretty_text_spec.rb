# frozen_string_literal: true

require "rails_helper"

RSpec.describe PrettyText, :dcs_server_status do
  before { configure_dcs }

  it "cooks a standalone shortcode with a static fallback between paragraphs" do
    cooked = PrettyText.cook("Before\n\n[dcs-status]\n\nAfter")

    expect(cooked).to include('class="dcs-server-status-placeholder"')
    expect(cooked).to include("open this post on the forum")
    expect(cooked).to include("<p>Before</p>", "<p>After</p>")
  end

  it "leaves inline text, escaped commands, and code examples literal" do
    [
      "Use [dcs-status] here",
      "\\[dcs-status]",
      "`[dcs-status]`",
      "```\n[dcs-status]\n```",
      "    [dcs-status]"
    ].each do |raw|
      expect(PrettyText.cook(raw)).not_to include(
        'class="dcs-server-status-placeholder"'
      )
    end
  end

  it "leaves the shortcode as text when the plugin is disabled" do
    SiteSetting.dcs_server_status_enabled = false

    expect(PrettyText.cook("[dcs-status]")).to eq("<p>[dcs-status]</p>")
  end
end
