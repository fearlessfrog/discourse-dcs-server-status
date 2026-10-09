import { apiInitializer } from "discourse/lib/api";
import DcsServerStatusCard from "discourse/plugins/discourse-dcs-server-status/discourse/components/dcs-server-status-card";
import richEditorExtension from "discourse/plugins/discourse-dcs-server-status/lib/rich-editor-extension";

export default apiInitializer((api) => {
  api.addAdminPluginConfigurationNav("discourse-dcs-server-status", [
    {
      label: "dcs_server_status.admin.connection",
      route: "adminPlugins.show.dcs-server-status-connection",
    },
  ]);

  const siteSettings = api.container.lookup("service:site-settings");
  if (!siteSettings.dcs_server_status_enabled) {
    return;
  }

  api.registerRichEditorExtension(richEditorExtension);
  api.decorateCookedElement((element, helper) => {
    if (!helper.renderGlimmer) {
      return;
    }
    element
      .querySelectorAll(".dcs-server-status-placeholder")
      .forEach((placeholder) => {
        helper.renderGlimmer(
          placeholder,
          DcsServerStatusCard,
          {},
          { append: false }
        );
      });
  });
});
