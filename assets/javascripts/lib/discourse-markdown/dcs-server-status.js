const SHORTCODE = "[dcs-status]";

export function setup(helper) {
  helper.registerOptions((options, siteSettings) => {
    options.features["dcs-server-status"] =
      siteSettings.dcs_server_status_enabled;
  });
  helper.allowList(["div.dcs-server-status-placeholder"]);

  helper.registerPlugin((markdown) => {
    markdown.block.ruler.before(
      "paragraph",
      "dcs_server_status",
      (state, startLine, _endLine, silent) => {
        if (state.sCount[startLine] - state.blkIndent >= 4) {
          return false;
        }

        const line = state.src
          .slice(
            state.bMarks[startLine] + state.tShift[startLine],
            state.eMarks[startLine]
          )
          .trim();
        if (line !== SHORTCODE) {
          return false;
        }
        if (!silent) {
          const token = state.push("dcs_server_status", "div", 0);
          token.block = true;
          token.map = [startLine, startLine + 1];
          state.line = startLine + 1;
        }
        return true;
      },
      { alt: ["paragraph", "reference", "blockquote", "list"] }
    );

    markdown.renderer.rules.dcs_server_status = () =>
      '<div class="dcs-server-status-placeholder">DCS server status — open this post on the forum to see live data.</div>\n';
  });
}
