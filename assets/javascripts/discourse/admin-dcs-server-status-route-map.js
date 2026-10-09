export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",
  map() {
    this.route("dcs-server-status-connection", { path: "connection" });
  },
};
