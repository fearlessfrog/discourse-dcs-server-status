import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export const REFRESH_INTERVAL = 60_000;

export default class DcsServerStatusService extends Service {
  @tracked payload = null;
  @tracked failed = false;

  consumers = 0;
  timer = null;
  inFlight = null;
  lastRequestAt = 0;
  visibilityHandler = () => {
    this.stopTimer();
    if (!document.hidden && this.consumers > 0) {
      this.refresh();
    }
  };

  constructor() {
    super(...arguments);
    registerDestructor(this, () => {
      this.stopTimer();
      document.removeEventListener("visibilitychange", this.visibilityHandler);
    });
  }

  acquire() {
    this.consumers++;
    if (this.consumers === 1) {
      document.addEventListener("visibilitychange", this.visibilityHandler);
      if (!document.hidden) {
        this.refresh();
      }
    }
  }

  release() {
    this.consumers = Math.max(0, this.consumers - 1);
    if (this.consumers === 0) {
      this.stopTimer();
      document.removeEventListener("visibilitychange", this.visibilityHandler);
    }
  }

  async refresh() {
    if (this.inFlight) {
      return this.inFlight.catch(() => null);
    }
    if (
      this.lastRequestAt &&
      Date.now() - this.lastRequestAt < REFRESH_INTERVAL
    ) {
      this.schedule();
      return;
    }

    this.lastRequestAt = Date.now();
    this.inFlight = ajax("/dcs-status.json");
    try {
      const payload = await this.inFlight;
      if (!this.isDestroying) {
        this.payload = payload;
        this.failed = false;
      }
    } catch {
      if (!this.isDestroying) {
        this.failed = true;
        const successAt = Date.parse(this.payload?.last_success_at);
        if (successAt && Date.now() - successAt >= 24 * 60 * 60 * 1000) {
          this.payload = {
            ...this.payload,
            status: "unknown",
            stale: false,
            server: null,
          };
        }
      }
    } finally {
      this.inFlight = null;
      this.schedule();
    }
  }

  schedule() {
    this.stopTimer();
    if (this.consumers > 0 && !document.hidden && !this.isDestroying) {
      const delay = Math.max(
        1,
        REFRESH_INTERVAL - (Date.now() - this.lastRequestAt)
      );
      this.timer = setTimeout(() => this.refresh(), delay);
    }
  }

  stopTimer() {
    clearTimeout(this.timer);
    this.timer = null;
  }
}
