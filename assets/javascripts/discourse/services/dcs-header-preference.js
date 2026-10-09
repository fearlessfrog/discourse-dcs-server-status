import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import Service from "@ember/service";
import KeyValueStore from "discourse/lib/key-value-store";

export const HEADER_STORE_NAMESPACE = "dcs-server-status-header_";
export const HEADER_HIDDEN_KEY = "hidden";

export default class DcsHeaderPreference extends Service {
  @tracked dismissed = false;
  store = new KeyValueStore(HEADER_STORE_NAMESPACE);

  storageHandler = (event) => {
    if (
      event.key === null ||
      event.key === this.store.context + HEADER_HIDDEN_KEY
    ) {
      this.readPreference();
    }
  };

  constructor() {
    super(...arguments);
    this.readPreference();
    window.addEventListener("storage", this.storageHandler);
    registerDestructor(this, () =>
      window.removeEventListener("storage", this.storageHandler)
    );
  }

  readPreference() {
    try {
      this.dismissed = this.store.get(HEADER_HIDDEN_KEY) === "true";
    } catch {
      // Keep the current visit's choice when browser storage is unavailable.
    }
  }

  setDismissed(dismissed) {
    this.dismissed = dismissed;
    try {
      this.store.set({ key: HEADER_HIDDEN_KEY, value: String(dismissed) });
    } catch {
      // Dismissal must still work if writing to browser storage fails.
    }
  }
}
