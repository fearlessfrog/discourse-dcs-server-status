import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import Service, { service } from "@ember/service";
import { hasSpriteSymbol } from "discourse/lib/svg-sprite-loader";

export const HEADER_MEDIA_QUERY = "(min-width: 64rem)";

export default class DcsHeaderPresentation extends Service {
  @service site;

  @tracked wide = false;
  @tracked icon = "jet-fighter";

  constructor() {
    super(...arguments);
    const query = window.matchMedia(HEADER_MEDIA_QUERY);
    const updateWidth = () => {
      this.wide = query.matches;
    };
    updateWidth();
    query.addEventListener("change", updateWidth);

    const updateIcon = () => {
      this.icon = hasSpriteSymbol("mudspike-fighter-jet")
        ? "mudspike-fighter-jet"
        : "jet-fighter";
    };
    updateIcon();
    // Theme symbols also load asynchronously in production builds.
    const observer = new MutationObserver(updateIcon);
    observer.observe(document.getElementById("svg-sprites"), {
      childList: true,
      subtree: true,
    });
    registerDestructor(this, () => {
      query.removeEventListener("change", updateWidth);
      observer.disconnect();
    });
  }

  get wideDesktop() {
    return !this.site.mobileView && this.wide;
  }

  get compact() {
    return !this.wideDesktop;
  }
}
