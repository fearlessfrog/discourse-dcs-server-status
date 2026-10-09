import Component from "@glimmer/component";
import { registerDestructor } from "@ember/destroyable";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export function formatMissionTime(seconds) {
  if (!Number.isSafeInteger(seconds) || seconds < 0) {
    return "—";
  }
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const remainder = seconds % 60;
  const time = [hours, minutes, remainder]
    .map((part) => String(part).padStart(2, "0"))
    .join(":");
  return days ? i18n("dcs_server_status.elapsed_days", { days, time }) : time;
}

export default class DcsServerStatusCard extends Component {
  @service dcsServerStatus;

  constructor() {
    super(...arguments);
    this.dcsServerStatus.acquire();
    registerDestructor(this, () => this.dcsServerStatus.release());
  }

  get payload() {
    return this.dcsServerStatus.payload;
  }

  get server() {
    return this.payload?.server;
  }

  get name() {
    return (
      this.server?.name ||
      this.payload?.server_name ||
      i18n("dcs_server_status.title")
    );
  }

  get status() {
    if (!this.payload) {
      return this.dcsServerStatus.failed ? "unknown" : "loading";
    }
    return this.payload.status;
  }

  get statusLabel() {
    return i18n(`dcs_server_status.status.${this.status}`);
  }

  get stale() {
    return (
      this.payload?.status !== "unknown" &&
      (this.payload?.stale ||
        (this.dcsServerStatus.failed && this.payload?.last_success_at))
    );
  }

  get missionTime() {
    return formatMissionTime(this.server?.mission_time_seconds);
  }

  get missionName() {
    return this.server?.mission || i18n("dcs_server_status.no_mission");
  }

  get address() {
    const address = this.server.ip_address;
    return `${address.includes(":") ? `[${address}]` : address}:${this.server.port}`;
  }

  get refreshedAt() {
    return this.payload?.last_success_at
      ? new Date(this.payload.last_success_at).toLocaleString()
      : i18n("dcs_server_status.never_refreshed");
  }

  <template>
    <section
      aria-label={{i18n "dcs_server_status.title"}}
      class="dcs-server-status-card"
    >
      <div class="dcs-server-status-card__heading">
        <strong>{{this.name}}</strong>
        <span
          class="dcs-server-status-card__status"
          data-status={{this.status}}
        >{{this.statusLabel}}</span>
        {{#if this.stale}}
          <span class="dcs-server-status-card__stale">{{i18n
              "dcs_server_status.stale"
            }}</span>
        {{/if}}
      </div>
      {{#if this.server}}
        <dl class="dcs-server-status-card__details">
          <div>
            <dt>{{i18n "dcs_server_status.players"}}</dt>
            <dd>{{this.server.players}} / {{this.server.players_max}}</dd>
          </div>
          <div>
            <dt>{{i18n "dcs_server_status.mission_time"}}</dt>
            <dd>{{this.missionTime}}</dd>
          </div>
          <div class="dcs-server-status-card__mission">
            <dt>{{i18n "dcs_server_status.mission"}}</dt>
            <dd>{{this.missionName}}</dd>
          </div>
          <div class="dcs-server-status-card__address">
            <dt>{{i18n "dcs_server_status.address"}}</dt>
            <dd>{{this.address}}</dd>
          </div>
        </dl>
      {{/if}}
      <p class="dcs-server-status-card__updated">
        {{i18n "dcs_server_status.last_updated" timestamp=this.refreshedAt}}
      </p>
    </section>
  </template>
}
