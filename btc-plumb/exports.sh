# Plumb for Umbrel: addresses, ports and credentials for this app and for apps that depend on it.
# Its own IPs and ports, so it runs beside the Bitcoin Node and Bitcoin Knots apps.
export APP_PLUMB_NODE_NODE_IP="10.21.21.110"
export APP_PLUMB_NODE_TOR_PROXY_IP="10.21.22.110"
export APP_PLUMB_NODE_I2P_DAEMON_IP="10.21.22.111"

EXPORTS_DATA_ROOT="${EXPORTS_APP_DATA_DIR:-${EXPORTS_APP_DIR}/data}"
export APP_PLUMB_NODE_DATA_DIR="${EXPORTS_DATA_ROOT}/bitcoin"
export APP_PLUMB_NODE_RPC_PORT="10332"
export APP_PLUMB_NODE_P2P_PORT="10333"
# Additional inbound P2P listener granting whitelisted permissions (whitebind) to this port; for trusted internal apps only; do not publish externally
export APP_PLUMB_NODE_P2P_WHITEBIND_PORT="10335"
export APP_PLUMB_NODE_TOR_PORT="8334"
export APP_PLUMB_NODE_ZMQ_RAWBLOCK_PORT="48332"
export APP_PLUMB_NODE_ZMQ_RAWTX_PORT="48333"
export APP_PLUMB_NODE_ZMQ_HASHBLOCK_PORT="48334"
export APP_PLUMB_NODE_ZMQ_SEQUENCE_PORT="48335"
export APP_PLUMB_NODE_ZMQ_HASHTX_PORT="48336"

export APP_PLUMB_NODE_NETWORK="mainnet"

# Check for an existing settings.json file to override the network with the user's choice
{
	BITCOIN_APP_CONFIG_FILE="${EXPORTS_DATA_ROOT}/app/settings.json"
	if [[ -f "${BITCOIN_APP_CONFIG_FILE}" ]]
	then
		bitcoin_app_network=$(jq -r '.chain' "${BITCOIN_APP_CONFIG_FILE}")
		case $bitcoin_app_network in
			"main")
				APP_PLUMB_NODE_NETWORK="mainnet";;
			"test")
				APP_PLUMB_NODE_NETWORK="testnet";;
			"testnet4")
				APP_PLUMB_NODE_NETWORK="testnet4";;
			"signet")
				APP_PLUMB_NODE_NETWORK="signet";;
			"regtest")
				APP_PLUMB_NODE_NETWORK="regtest";;
			*)
				if [[ -n "$bitcoin_app_network" ]] && [[ "$bitcoin_app_network" != "null" ]]; then
					echo "Warning (${EXPORTS_APP_ID}): Invalid network '${bitcoin_app_network}' in settings.json. Exporting APP_PLUMB_NODE_NETWORK as default 'mainnet'."
				fi;;
		esac
	fi
} > /dev/null || true

# .env file to persist the rpc username and password
BITCOIN_ENV_FILE="${EXPORTS_APP_DIR}/.env"

# If no .env file exists, create one with generated values
if [[ ! -f "${BITCOIN_ENV_FILE}" ]]; then
	if [[ -z ${BITCOIN_RPC_USER+x} ]] || [[ -z ${BITCOIN_RPC_PASS+x} ]]; then
		BITCOIN_RPC_USER="umbrel"
		BITCOIN_RPC_DETAILS=$("${EXPORTS_APP_DIR}/scripts/rpcauth.py" "${BITCOIN_RPC_USER}")
		BITCOIN_RPC_PASS=$(echo "$BITCOIN_RPC_DETAILS" | tail -1)
	fi

	echo "export APP_PLUMB_NODE_RPC_USER='${BITCOIN_RPC_USER}'"	>> "${BITCOIN_ENV_FILE}"
	echo "export APP_PLUMB_NODE_RPC_PASS='${BITCOIN_RPC_PASS}'"	>> "${BITCOIN_ENV_FILE}"
fi

. "${BITCOIN_ENV_FILE}"

rpc_hidden_service_file="${EXPORTS_TOR_DATA_DIR}/app-${EXPORTS_APP_ID}-rpc/hostname"
p2p_hidden_service_file="${EXPORTS_TOR_DATA_DIR}/app-${EXPORTS_APP_ID}-p2p/hostname"
export APP_PLUMB_NODE_RPC_HIDDEN_SERVICE="$(cat "${rpc_hidden_service_file}" 2>/dev/null || echo "notyetset.onion")"
export APP_PLUMB_NODE_P2P_HIDDEN_SERVICE="$(cat "${p2p_hidden_service_file}" 2>/dev/null || echo "notyetset.onion")"

# electrs compatible network param
export APP_PLUMB_NODE_NETWORK_ELECTRS=$APP_PLUMB_NODE_NETWORK
if [[ "${APP_PLUMB_NODE_NETWORK_ELECTRS}" = "mainnet" ]]; then
	APP_PLUMB_NODE_NETWORK_ELECTRS="bitcoin"
fi

# This app implements `bitcoin`: apps that depend on bitcoin and pick Plumb read APP_BITCOIN_*.
# A value already set wins (:=), as in the Bitcoin Knots app.
for var in \
    NODE_IP \
    TOR_PROXY_IP \
    I2P_DAEMON_IP \
    DATA_DIR \
    RPC_PORT \
    P2P_PORT \
    P2P_WHITEBIND_PORT \
    TOR_PORT \
    ZMQ_RAWBLOCK_PORT \
    ZMQ_RAWTX_PORT \
    ZMQ_HASHBLOCK_PORT \
    ZMQ_SEQUENCE_PORT \
    ZMQ_HASHTX_PORT \
    NETWORK \
    RPC_USER \
    RPC_PASS \
    RPC_HIDDEN_SERVICE \
    P2P_HIDDEN_SERVICE \
    NETWORK_ELECTRS
do
    bitcoin_var="APP_BITCOIN_${var}"
    plumb_var="APP_PLUMB_NODE_${var}"
    if [ -n "${!plumb_var-}" ]; then
        export "$bitcoin_var"="${!bitcoin_var:=${!plumb_var}}"
    else
        echo "Warning: $plumb_var is unset or empty"
    fi
done
