import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class DcsServerStatusConnectionRoute extends DiscourseRoute {
  model() {
    return ajax("/admin/plugins/discourse-dcs-server-status/connection.json");
  }
}
