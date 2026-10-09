import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DMenu from "discourse/float-kit/components/d-menu";
import getURL from "discourse/lib/get-url";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";
import DcsServerStatusCard from "discourse/plugins/discourse-dcs-server-status/discourse/components/dcs-server-status-card";

const BadgeContents = <template>
  <span class="dcs-header-first-line">
    <span class="dcs-header-name">{{@badge.name}}</span>
    <span
      class="dcs-header-state"
      data-status={{if @badge.stale "stale" @badge.status}}
    >
      <span aria-hidden="true" class="dcs-header-dot"></span>
      {{@badge.headerStatus}}
    </span>
  </span>
  <span class="dcs-header-second-line">
    {{#if @badge.clock}}
      <span
        class="dcs-header-clock"
        title={{i18n "dcs_server_status.mission_time"}}
      >{{@badge.clock}}</span>
    {{/if}}
    {{#if @badge.server}}
      {{#if @badge.clock}}<span aria-hidden="true">·</span>{{/if}}
      <span class="dcs-header-players">{{@badge.playersLabel}}</span>
    {{/if}}
  </span>
</template>;

// Reuse the card's cache subscription and freshness rules for both presentations.
export default class DcsServerStatusHeaderSummary extends DcsServerStatusCard {
  get name() {
    return (
      this.server?.name ||
      this.payload?.server_name ||
      i18n("dcs_server_status.header.short_title")
    );
  }

  get headerStatus() {
    return this.stale
      ? i18n("dcs_server_status.header.stale")
      : i18n(`dcs_server_status.header.status.${this.status}`);
  }

  get clock() {
    return this.hasMissionClock ? this.missionTime.slice(0, 5) : null;
  }

  get playersLabel() {
    return i18n("dcs_server_status.header.players", {
      players: this.server?.players,
      capacity: this.server?.players_max,
    });
  }

  get description() {
    return [
      this.name,
      this.headerStatus,
      this.clock &&
        i18n("dcs_server_status.header.mission_time", { time: this.clock }),
      this.server && this.playersLabel,
    ]
      .filter(Boolean)
      .join(", ");
  }

  get destination() {
    const url = this.args.url?.trim();
    return url ? getURL(url) : null;
  }

  @action
  followLink(event) {
    if (
      event.button === 0 &&
      !event.ctrlKey &&
      !event.metaKey &&
      !event.shiftKey &&
      !event.altKey &&
      DiscourseURL.isInternal(this.destination)
    ) {
      event.preventDefault();
      DiscourseURL.routeTo(this.destination);
    }
  }

  @action
  focusReturnTarget() {
    return document.querySelector(".dcs-header-trigger, .dcs-header-restore");
  }

  <template>
    {{#if this.destination}}
      <a
        aria-label={{this.description}}
        class="dcs-header-link"
        href={{this.destination}}
        title={{this.name}}
        {{on "click" this.followLink}}
      >
        <BadgeContents @badge={{this}} />
      </a>
    {{else}}
      <DMenu
        @ariaLabel={{this.description}}
        @focusTarget={{this.focusReturnTarget}}
        @identifier="dcs-header-details"
        @placement="bottom-end"
        @title={{this.name}}
        @triggerClass="btn-transparent dcs-header-trigger"
      >
        <:trigger><BadgeContents @badge={{this}} /></:trigger>
        <:content>
          <div class="dcs-header-details"><DcsServerStatusCard /></div>
        </:content>
      </DMenu>
    {{/if}}
  </template>
}
