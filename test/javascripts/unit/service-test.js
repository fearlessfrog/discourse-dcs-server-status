import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("DCS status | Polling service", function (hooks) {
  setupTest(hooks);
  hooks.beforeEach(function () {
    this.service = this.owner.lookup("service:dcs-server-status");
    this.requests = 0;
    pretender.get("/dcs-status.json", () => {
      this.requests++;
      return response({ status: "not_listed", stale: false, server: null });
    });
  });
  hooks.afterEach(function () {
    this.service.release();
    sinon.restore();
  });

  test("refreshes after one minute and pauses in hidden tabs", async function (assert) {
    let now = Date.now();
    let hidden = false;
    sinon.stub(Date, "now").callsFake(() => now);
    sinon.stub(document, "hidden").get(() => hidden);

    this.service.acquire();
    await this.service.inFlight;
    await Promise.resolve();
    assert.strictEqual(this.requests, 1);

    now += 60000;
    await this.service.refresh();
    assert.strictEqual(this.requests, 2);

    hidden = true;
    document.dispatchEvent(new Event("visibilitychange"));
    assert.strictEqual(this.service.timer, null);
    now += 60000;
    hidden = false;
    document.dispatchEvent(new Event("visibilitychange"));
    await this.service.inFlight;
    await Promise.resolve();
    assert.strictEqual(this.requests, 3);
  });

  test("preserves the last response when a later request fails", async function (assert) {
    await this.service.refresh();
    const previous = this.service.payload;
    this.service.lastRequestAt = 0;
    pretender.get("/dcs-status.json", () => response(503, {}));
    await this.service.refresh();

    assert.strictEqual(this.service.payload, previous);
    assert.true(this.service.failed);
  });

  test("discards server details after 24 hours of endpoint failures", async function (assert) {
    const successAt = Date.now() - 24 * 60 * 60 * 1000;
    this.service.payload = {
      status: "online",
      server_name: "Example DCS Server",
      last_success_at: new Date(successAt).toISOString(),
      server: { name: "Example DCS Server" },
    };
    pretender.get("/dcs-status.json", () => response(503, {}));
    await this.service.refresh();

    assert.strictEqual(this.service.payload.status, "unknown");
    assert.strictEqual(this.service.payload.server, null);
    assert.true(this.service.failed);
  });
});
