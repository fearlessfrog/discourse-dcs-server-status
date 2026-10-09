import DcsServerStatusConnection from "discourse/plugins/discourse-dcs-server-status/discourse/components/dcs-server-status-connection";

export default <template>
  <DcsServerStatusConnection @diagnostics={{@model}} />
</template>
