import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import DcsServerStatusHeaderSummary from "discourse/plugins/discourse-dcs-server-status/discourse/components/dcs-server-status-header-summary";

export const HEADER_MEDIA_QUERY = "(min-width: 64rem)";

export default class DcsServerStatusHeader extends Component {
  @service site;
  @service siteSettings;
  @service currentUser;
  @service dcsHeaderPreference;

  @tracked wide = false;

  constructor() {
    super(...arguments);
    const query = window.matchMedia(HEADER_MEDIA_QUERY);
    this.wide = query.matches;
    const update = () => {
      this.wide = query.matches;
    };
    query.addEventListener("change", update);
    registerDestructor(this, () => query.removeEventListener("change", update));
  }

  get available() {
    return (
      this.siteSettings.dcs_server_status_enabled &&
      this.siteSettings.dcs_server_status_header_enabled &&
      !this.site.mobileView &&
      this.wide &&
      (!this.siteSettings.login_required || this.currentUser)
    );
  }

  focus(selector) {
    schedule("afterRender", this, () => {
      if (!this.isDestroying) {
        document.querySelector(selector)?.focus();
      }
    });
  }

  @action
  dismiss() {
    this.dcsHeaderPreference.setDismissed(true);
    this.focus(".dcs-header-restore");
  }

  @action
  restore() {
    this.dcsHeaderPreference.setDismissed(false);
    this.focus(".dcs-header-link, .dcs-header-trigger");
  }

  <template>
    {{#if this.available}}
      <div class="dcs-header-status">
        {{#if this.dcsHeaderPreference.dismissed}}
          <DButton
            class="btn-transparent dcs-header-restore"
            @action={{this.restore}}
            @ariaLabel="dcs_server_status.header.restore"
            @label="dcs_server_status.header.short_title"
            @title="dcs_server_status.header.restore"
          />
        {{else}}
          <DcsServerStatusHeaderSummary
            @url={{this.siteSettings.dcs_server_status_header_url}}
          />
          <DButton
            class="btn-transparent dcs-header-dismiss"
            @action={{this.dismiss}}
            @ariaLabel="dcs_server_status.header.hide"
            @icon="xmark"
            @title="dcs_server_status.header.hide"
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
