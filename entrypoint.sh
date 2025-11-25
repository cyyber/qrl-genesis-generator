#!/bin/bash -e
export DEFAULT_ENV_FILE="/defaults/defaults.env"
# Load the default env vars into the environment
source $DEFAULT_ENV_FILE

if [ -f /config/values.env ];
then
    # Use user provided env vars if it exists
    export FULL_ENV_FILE="/config/values.env"
    # Pull these values out of the env file since they can be very large and cause
    # "arguments list too long" errors in the shell.
    grep -v "ADDITIONAL_PRELOADED_CONTRACTS" $FULL_ENV_FILE | grep -v "EL_PREMINE_ADDRS" > /tmp/values-short.env
    # print the value of ADDITIONAL_PRELOADED_CONTRACTS
else
    grep -v "ADDITIONAL_PRELOADED_CONTRACTS" $DEFAULT_ENV_FILE | grep -v "EL_PREMINE_ADDRS" > /tmp/values-short.env
fi
# Load the env vars entered by the user without the larger values into the environment
source /tmp/values-short.env


SERVER_ENABLED="${SERVER_ENABLED:-false}"
SERVER_PORT="${SERVER_PORT:-8000}"


gen_shared_files(){
    . /apps/el-gen/.venv/bin/activate
    set -x
    # Shared files
    mkdir -p /data/metadata
    if ! [ -f "/data/jwt/jwtsecret" ]; then
        mkdir -p /data/jwt
        echo -n 0x$(openssl rand -hex 32 | tr -d "\n") > /data/jwt/jwtsecret
    fi
}

gen_el_config(){
    . /apps/el-gen/.venv/bin/activate
    set -x
    if ! [ -f "/data/metadata/genesis.json" ]; then
        tmp_dir=$(mktemp -d -t ci-XXXXXXXXXX)
        mkdir -p /data/metadata
        python3 /apps/envsubst.py < /config/el/genesis-config.yaml > $tmp_dir/genesis-config.yaml
        cat $tmp_dir/genesis-config.yaml
        python3 /apps/el-gen/genesis_gzond.py $tmp_dir/genesis-config.yaml      > /data/metadata/genesis.json
    else
        echo "el genesis already exists. skipping generation..."
    fi
}

gen_minimal_config() {
  declare -A replacements=(
    [MIN_PER_EPOCH_CHURN_LIMIT]=2
    [MIN_EPOCHS_FOR_BLOCK_REQUESTS]=272
    [WHISK_EPOCHS_PER_SHUFFLING_PHASE]=4
    [WHISK_PROPOSER_SELECTION_GAP]=1
    [MAX_PER_EPOCH_ACTIVATION_EXIT_CHURN_LIMIT]=128000000000
  )

  for key in "${!replacements[@]}"; do
    sed -i "s/$key:.*/$key: ${replacements[$key]}/" /data/metadata/config.yaml
  done
}

gen_cl_config(){
    . /apps/el-gen/.venv/bin/activate
    set -x
    # Consensus layer: Check if genesis already exists
    if ! [ -f "/data/metadata/genesis.ssz" ]; then
        tmp_dir=$(mktemp -d -t ci-XXXXXXXXXX)
        mkdir -p /data/metadata
        HUMAN_READABLE_TIMESTAMP=$(date -u -d @"$GENESIS_TIMESTAMP" +"%Y-%b-%d %I:%M:%S %p %Z")
        COMMENT="# $HUMAN_READABLE_TIMESTAMP"
        python3 /apps/envsubst.py < /config/cl/config.yaml > /data/metadata/config.yaml
        sed -i "s/#HUMAN_TIME_PLACEHOLDER/$COMMENT/" /data/metadata/config.yaml
        # Conditionally override values if preset is "minimal"
        if [[ "$PRESET_BASE" == "minimal" ]]; then
          gen_minimal_config
        fi
        # Create bootstrap_nodes.txt
        echo $BEACON_STATIC_QNR > /data/metadata/bootstrap_nodes.txt

        # Generate preregistered validator keys
        echo $KEYSTORE_PASSWORD > /data/metadata/keystore_password.txt
        validator_keys_args+=(
          new-seed
          --num-validators $NUMBER_OF_VALIDATORS
          --folder /data/metadata/validator_keys
          --mnemonic "$EL_AND_CL_MNEMONIC"
          --keystore-password-file /data/metadata/keystore_password.txt
          --chain-name "dev"
          --execution-address "$WITHDRAWAL_ADDRESS"
        )
        if [ "$LIGHT_KDF_ENABLED" = true ] ; then
          validator_keys_args+=(
            --lightkdf
          )
        fi

        /usr/local/bin/deposit "${validator_keys_args[@]}"

        # Generate genesis 
        DEPOSIT_DATA_FILE=$(find /data/metadata/validator_keys -name "*deposit_data*")
        genesis_args+=(
          testnet
          generate-genesis
          --num-validators $NUMBER_OF_VALIDATORS
          --deposit-json-file $DEPOSIT_DATA_FILE
          --gzond-genesis-json-in /data/metadata/genesis.json
          --output-ssz /data/metadata/genesis.ssz
          --chain-config-file /data/metadata/config.yaml
          --genesis-time $GENESIS_TIMESTAMP
        )
        /usr/local/bin/qrysmctl "${genesis_args[@]}"
    else
        echo "cl genesis already exists. skipping generation..."
    fi
}

gen_all_config(){
    gen_el_config
    gen_cl_config
    gen_shared_files
}

case $1 in
  el)
    gen_el_config
    ;;
  cl)
    gen_cl_config
    ;;
  all)
    gen_all_config
    ;;
  *)
    set +x
    echo "Usage: [all|cl|el]"
    exit 1
    ;;
esac

# Start webserver
if [ "$SERVER_ENABLED" = true ] ; then
  cd /data && exec python3 -m http.server "$SERVER_PORT"
fi

