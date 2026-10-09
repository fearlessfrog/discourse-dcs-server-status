import { i18n } from "discourse-i18n";

export default {
  nodeSpec: {
    dcs_server_status: {
      group: "block",
      atom: true,
      selectable: true,
      parseDOM: [{ tag: "div.dcs-server-status-placeholder" }],
      toDOM: () => [
        "div",
        { class: "dcs-server-status-placeholder" },
        i18n("dcs_server_status.editor_label"),
      ],
    },
  },
  parse: {
    dcs_server_status: { node: "dcs_server_status" },
  },
  serializeNode: {
    dcs_server_status(state) {
      state.write("[dcs-status]");
      state.closeBlock();
    },
  },
};
