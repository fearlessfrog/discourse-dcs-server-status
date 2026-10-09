import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { HEADER_HIDDEN_KEY } from "discourse/plugins/discourse-dcs-server-status/discourse/services/dcs-header-preference";

module("DCS status | Header preference", function (hooks) {
  setupTest(hooks);
  hooks.beforeEach(function () {
    this.service = this.owner.lookup("service:dcs-header-preference");
    this.service.setDismissed(false);
  });
  hooks.afterEach(function () {
    sinon.restore();
    this.service.store.remove(HEADER_HIDDEN_KEY);
  });
  test("remembers the choice when the service is recreated", function (assert) {
    this.service.setDismissed(true);
    const nextVisit = this.owner
      .factoryFor("service:dcs-header-preference")
      .create();
    assert.true(nextVisit.dismissed);
    nextVisit.destroy();
  });
  test("updates from another tab and ignores unrelated storage events", function (assert) {
    this.service.store.set({ key: HEADER_HIDDEN_KEY, value: "true" });
    window.dispatchEvent(new StorageEvent("storage", { key: "unrelated-key" }));
    assert.false(this.service.dismissed);
    window.dispatchEvent(
      new StorageEvent("storage", {
        key: this.service.store.context + HEADER_HIDDEN_KEY,
      })
    );
    assert.true(this.service.dismissed);
    this.service.store.remove(HEADER_HIDDEN_KEY);
    window.dispatchEvent(new StorageEvent("storage", { key: null }));
    assert.false(this.service.dismissed);
  });
  test("dismisses for the visit even when storage reads and writes fail", function (assert) {
    sinon.stub(this.service.store, "get").throws(new Error("storage blocked"));
    sinon.stub(this.service.store, "set").throws(new Error("storage full"));
    this.service.setDismissed(true);
    this.service.readPreference();
    assert.true(this.service.dismissed);
    this.service.setDismissed(false);
    assert.false(this.service.dismissed);
  });
});
