import Component from "@glimmer/component";
import { registerDestructor } from "@ember/destroyable";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ALL_PAGES_EXCLUDED_ROUTES } from "discourse/components/welcome-banner";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import DcsServerStatusCard from "discourse/plugins/discourse-dcs-server-status/discourse/components/dcs-server-status-card";
import {
  followHeaderDestination,
  headerDestination,
} from "discourse/plugins/discourse-dcs-server-status/discourse/lib/dcs-header-destination";

export default class DcsServerStatusMobileHeader extends Component {
  @service site;
  @service siteSettings;
  @service currentUser;
  @service header;
  @service router;
  @service dcsHeaderPresentation;

  menu = null;

  constructor() {
    super(...arguments);
    this.router.on("routeWillChange", this.closeForNavigation);
    registerDestructor(this, () =>
      this.router.off("routeWillChange", this.closeForNavigation)
    );
  }

  get available() {
    return (
      this.dcsHeaderPresentation.compact &&
      // Desktop guest authentication buttons precede the normal icon group.
      Boolean(this.args.beforePanel) ===
        (!this.currentUser && !this.site.mobileView) &&
      this.siteSettings.dcs_server_status_enabled &&
      this.siteSettings.dcs_server_status_header_enabled &&
      (!this.siteSettings.login_required || this.currentUser) &&
      this.site.can_search &&
      !this.header.headerButtonsHidden.includes("search") &&
      (!this.site.mobileView || !this.header.topicInfoVisible) &&
      !ALL_PAGES_EXCLUDED_ROUTES.includes(this.router.currentRouteName)
    );
  }

  get destination() {
    return headerDestination(this.siteSettings.dcs_server_status_header_url);
  }

  @action
  registerMenu(menu) {
    this.menu = menu;
  }

  @action
  closeForNavigation() {
    if (this.menu?.expanded) {
      this.menu.close({ focusTrigger: false });
    }
  }

  @action
  followLink(event) {
    followHeaderDestination(event, this.destination);
  }

  <template>
    {{#if this.available}}
      <li class="header-dropdown-toggle dcs-mobile-header">
        <DMenu
          @ariaLabel={{i18n "dcs_server_status.header.mobile_show"}}
          @icon={{this.dcsHeaderPresentation.icon}}
          @identifier="dcs-mobile-details"
          @modalForMobile={{false}}
          @offset={{20}}
          @onRegisterApi={{this.registerMenu}}
          @placement="bottom-end"
          @title={{i18n "dcs_server_status.header.mobile_show"}}
          @triggerClass="icon btn-flat dcs-mobile-header-trigger"
        >
          <:content as |menu|>
            <div class="dcs-header-details dcs-mobile-header-details">
              <DButton
                class="btn-transparent dcs-mobile-header-close"
                @action={{menu.close}}
                @ariaLabel="dcs_server_status.header.mobile_close"
                @icon="xmark"
                @title="dcs_server_status.header.mobile_close"
              />
              <DcsServerStatusCard />
              {{#if this.destination}}
                <a
                  class="dcs-mobile-header-link"
                  href={{this.destination}}
                  {{on "click" this.followLink}}
                >{{i18n "dcs_server_status.header.more_information"}}</a>
              {{/if}}
            </div>
          </:content>
        </DMenu>
      </li>
    {{/if}}
  </template>
}
