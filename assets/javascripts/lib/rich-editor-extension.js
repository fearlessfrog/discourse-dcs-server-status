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
    dcs_server_status(state, node) {
      state.write("[dcs-status]");
      state.closeBlock(node);
    },
  },
  plugins({
    pmState: { Plugin, TextSelection },
    schema,
    utils: { changedDescendants },
  }) {
    return new Plugin({
      appendTransaction(transactions, previousState, state) {
        if (
          !transactions.some(
            (transaction) =>
              transaction.docChanged &&
              transaction.getMeta("addToHistory") !== false
          )
        ) {
          return null;
        }

        const paragraphs = [];
        changedDescendants(previousState.doc, state.doc, (node, position) => {
          if (
            node.type !== schema.nodes.paragraph ||
            node.childCount !== 1 ||
            !node.firstChild.isText ||
            node.firstChild.marks.length > 0 ||
            node.textContent.trim() !== "[dcs-status]"
          ) {
            return;
          }

          const resolved = state.doc.resolve(position);
          const index = resolved.index();
          if (
            resolved.parent.canReplaceWith(
              index,
              index + 1,
              schema.nodes.dcs_server_status
            )
          ) {
            paragraphs.push({ node, position });
          }
        });

        if (paragraphs.length === 0) {
          return null;
        }

        const transaction = state.tr;
        let cursorParagraph = null;
        for (const { node, position } of paragraphs.reverse()) {
          transaction.replaceWith(position, position + node.nodeSize, [
            schema.nodes.dcs_server_status.create(),
            schema.nodes.paragraph.create(),
          ]);
          if (state.selection.empty && state.selection.$from.parent === node) {
            cursorParagraph = position;
          }
        }
        if (cursorParagraph !== null) {
          transaction.setSelection(
            TextSelection.create(
              transaction.doc,
              transaction.mapping.map(cursorParagraph, -1) + 2
            )
          );
        }
        return transaction;
      },
    });
  },
};
