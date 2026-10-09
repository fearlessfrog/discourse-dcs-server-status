import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class DcsServerStatusConnection extends Component {
  @tracked diagnostics;
  @tracked busy = false;
  @tracked queued = false;

  constructor() {
    super(...arguments);
    this.diagnostics = this.args.diagnostics;
  }

  get errorLabel() {
    return this.diagnostics.error
      ? i18n(`dcs_server_status.admin.errors.${this.diagnostics.error}`)
      : i18n("dcs_server_status.admin.no_error");
  }

  get statusLabel() {
    return i18n(`dcs_server_status.status.${this.diagnostics.status}`);
  }

  get successAt() {
    return (
      this.diagnostics.last_success_at ||
      i18n("dcs_server_status.never_refreshed")
    );
  }

  get attemptAt() {
    return (
      this.diagnostics.last_attempt_at ||
      i18n("dcs_server_status.never_refreshed")
    );
  }

  @action
  async refresh() {
    this.busy = true;
    try {
      await ajax("/admin/plugins/discourse-dcs-server-status/refresh.json", {
        type: "POST",
      });
      this.queued = true;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.busy = false;
    }
  }

  @action
  async reload() {
    this.busy = true;
    try {
      this.diagnostics = await ajax(
        "/admin/plugins/discourse-dcs-server-status/connection.json"
      );
      this.queued = false;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.busy = false;
    }
  }

  <template>
    <div class="dcs-server-status-connection">
      <h2>{{i18n "dcs_server_status.admin.connection"}}</h2>
      <p>{{i18n "dcs_server_status.admin.instructions"}}</p>
      {{#unless this.diagnostics.configured}}
        <p>{{i18n "dcs_server_status.admin.not_configured"}}</p>
      {{/unless}}
      <dl>
        <dt>{{i18n "dcs_server_status.admin.current_status"}}</dt>
        <dd>{{this.statusLabel}}</dd>
        <dt>{{i18n "dcs_server_status.admin.last_success"}}</dt>
        <dd>{{this.successAt}}</dd>
        <dt>{{i18n "dcs_server_status.admin.last_attempt"}}</dt>
        <dd>{{this.attemptAt}}</dd>
        <dt>{{i18n "dcs_server_status.admin.last_error"}}</dt>
        <dd>{{this.errorLabel}}</dd>
      </dl>
      <DButton
        @action={{this.refresh}}
        @disabled={{this.busy}}
        @label="dcs_server_status.admin.refresh"
      />
      <DButton
        @action={{this.reload}}
        @disabled={{this.busy}}
        @label="dcs_server_status.admin.reload"
      />
      {{#if this.queued}}
        <p role="status">{{i18n "dcs_server_status.admin.queued"}}</p>
      {{/if}}
    </div>
  </template>
}
