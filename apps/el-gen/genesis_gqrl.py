import json
import os
import ruamel.yaml as yaml
import sys

testnet_config_path = "genesis-config.yaml"
# Runtime bytecode of the Qrysm deposit contract, written by the image build
# from the Qrysm revision the image ships. Keeping it out of this file means the
# preloaded contract always matches the DepositEvent Qrysm parses.
deposit_contract_code_path = os.environ.get(
    "DEPOSIT_CONTRACT_RUNTIME_HEX",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "deposit-contract-runtime.hex"),
)
mainnet_config_path = "/apps/el-gen/mainnet/genesis.json"
isNamedTestnet = False
combined_allocs = {}
if len(sys.argv) > 1:
    testnet_config_path = sys.argv[1]

with open(testnet_config_path) as stream:
    data = yaml.safe_load(stream)

# if int(data['chain_id']) == 1 or int(data['chain_id']) == 11155111:
if int(data['chain_id']) == 1:
    isNamedTestnet = True

def deposit_contract_code():
    try:
        with open(deposit_contract_code_path) as f:
            code = f.read().strip()
    except OSError as err:
        sys.exit(f"deposit contract runtime bytecode is unavailable: {err}")
    if not code.startswith("0x"):
        code = "0x" + code
    if len(code) <= 2:
        sys.exit(f"deposit contract runtime bytecode at {deposit_contract_code_path} is empty")
    return code

if int(data['chain_id']) == 1:
    # TODO(now.youtrack.cloud/issue/TQ-37)
    with open(mainnet_config_path) as m:
        mainnet_json = json.loads(m.read())
    out = mainnet_json
else:
    out = {
        "config": {
            "chainId": int(data['chain_id'])
        },
        "alloc": {
            # Allocate 1 planck to all possible pre-compiles.
            # See https://github.com/ethereum/EIPs/issues/716 "SpuriousDragon RIPEMD bug"
            # E.g. Rinkeby allocates it like this.
            # See https://github.com/ethereum/go-ethereum/blob/092856267067dd78b527a773f5b240d5c9f5693a/core/genesis.go#L370
            **{
                "Q" + i.to_bytes(length=64, byteorder='big').hex(): {
                    "balance": "1",
                } for i in range(256)
            },
            # deposit contract
            data['deposit_contract_address']: {
                "balance": "0",
                "code": deposit_contract_code(),
                # Hyperion packs zero_hashes[2n+1] || zero_hashes[2n] into each VM64 word.
                "storage": {
                    "0x0000000000000000000000000000000000000000000000000000000000000011": "0xf5a5fd42d16a20302798ef6ed309979b43003d2320d9f0e8ea9831a92759fb4b0000000000000000000000000000000000000000000000000000000000000000",
                    "0x0000000000000000000000000000000000000000000000000000000000000012": "0xc78009fdf07fc56a11f122370658a353aaa542ed63e44c4bc15ff4cd105ab33cdb56114e00fdd4c1f85c892bf35ac9a89289aaecb1ebd0a96cde606a748b5d71",
                    "0x0000000000000000000000000000000000000000000000000000000000000013": "0x9efde052aa15429fae05bad4d0b1d7c64da64d03d7a1854a588c2cb8430c0d30536d98837f2dd165a55d5eeae91485954472d56f246df256bf3cae19352a123c",
                    "0x0000000000000000000000000000000000000000000000000000000000000014": "0x87eb0ddba57e35f6d286673802a4af5975e22506c7cf4c64bb6be5ee11527f2cd88ddfeed400a8755596b21942c1497e114c302e6118290f91e6772976041fa1",
                    "0x0000000000000000000000000000000000000000000000000000000000000015": "0x506d86582d252405b840018792cad2bf1259f1ef5aa5f887e13cb2f0094f51e126846476fd5fc54a5d43385167c95144f2643f533cc85bb9d16b782f8d7db193",
                    "0x0000000000000000000000000000000000000000000000000000000000000016": "0x6cf04127db05441cd833107a52be852868890e4317e6a02ab47683aa75964220ffff0ad7e659772f9534c195c815efc4014ef1e1daed4404c06385d11192e92b",
                    "0x0000000000000000000000000000000000000000000000000000000000000017": "0xdf6af5f5bbdb6be9ef8aa618e4bf8073960867171e29676f8b284dea6a08a85eb7d05f875f140027ef5118a2247bbb84ce8f2f0f1123623085daf7960c329f5f",
                    "0x0000000000000000000000000000000000000000000000000000000000000018": "0xd49a7502ffcfb0340b1d7885688500ca308161a7f96b62df9d083b71fcc8f2bbb58d900f5e182e3c50ef74969ea16c7726c549757cc23523c369587da7293784",
                    "0x0000000000000000000000000000000000000000000000000000000000000019": "0x8d0d63c39ebade8509e0ae3c9c3876fb5fa112be18f905ecacfecb92057603ab8fe6b1689256c0d385f42f5bbe2027a22c1996e110ba97c171d3e5948de92beb",
                    "0x000000000000000000000000000000000000000000000000000000000000001a": "0xf893e908917775b62bff23294dbbe3a1cd8e6cc1c35b4801887b646a6f81f17f95eec8b2e541cad4e91de38385f2e046619f54496c2382cb6cacd5b98c26f5a4",
                    "0x000000000000000000000000000000000000000000000000000000000000001b": "0x8a8d7fe3af8caa085a7639a832001457dfb9128a8061142ad0335629ff23ff9ccddba7b592e3133393c16194fac7431abf2f5485ed711db282183c819e08ebaa",
                    "0x000000000000000000000000000000000000000000000000000000000000001c": "0xe71f0aa83cc32edfbefa9f4d3e0174ca85182eec9f3a09f6a6c0df6377a510d7feb3c337d7a51a6fbf00b9e34c52e1c9195c969bd4e7a0bfd51d5c5bed9c1167",
                    "0x000000000000000000000000000000000000000000000000000000000000001d": "0x21352bfecbeddde993839f614c3dac0a3ee37543f9b412b16199dc158e23b54431206fa80a50bb6abe29085058f16212212a60eec8f049fecb92d8c8e0a84bc0",
                    "0x000000000000000000000000000000000000000000000000000000000000001e": "0x7cdd2986268250628d0c10e385c58c6191e6fbe05191bcc04f133f2cea72c1c4619e312724bb6d7c3153ed9de791d764a366b389af13c58bf8a8d90481a46765",
                    "0x000000000000000000000000000000000000000000000000000000000000001f": "0x8869ff2c22b28cc10510d9853292803328be4fb0e80495e8bb8d271f5b889636848930bd7ba8cac54661072113fb278869e07bb8587f91392933374d017bcbe1",
                    "0x0000000000000000000000000000000000000000000000000000000000000020": "0x985e929f70af28d0bdd1a90a808f977f597c7c778c489e98d3bd8910d31ac0f7b5fe28e79f1b850f8658246ce9b6a1e7b49fc06db7143e8fe0b4f2b0c5523a5c"
                }
            }
        },
        "coinbase": "Q00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "extraData": "0x0000000000000000000000000000000000000000000000000000000000000000",
        "gasLimit": hex(int(data['genesis_gaslimit'] if 'genesis_gaslimit' in data and data['genesis_gaslimit'] is not None else 25000000)),
        "baseFeePerGas": "0x3b9aca00",
        "mixhash": "0x0000000000000000000000000000000000000000000000000000000000000000",
        "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
        "timestamp": str(data['genesis_timestamp'])
    }
    
    # Some hardcoded addrs
    def add_alloc_entry(addr, account):
        # Convert balance format
        if isinstance(account, dict) and 'balance' in account:
            balance_value = account['balance'].replace('QRL', '0' * 18)
        else:
            # If it's not a dictionary, assume it's a single value for backward compatibility
            balance_value = account.replace('QRL', '0' * 18)

        # Create alloc dictionary entry
        alloc_entry = {"balance": balance_value}

        # Optionally add code
        if 'code' in account:
            alloc_entry['code'] = account['code']

        # Optionally add storage
        if 'storage' in account:
            alloc_entry['storage'] = account['storage']

        # Optionally set nonce
        if 'nonce' in account:
            alloc_entry['nonce'] = account['nonce']

        # Optionally set seed
        if 'seed' in account:
            alloc_entry['seed'] = account['seed']

        # Add alloc entry to output's alloc field
        out["alloc"][addr] = alloc_entry

    for addr, account in data['el_premine_addrs'].items():
        add_alloc_entry(addr, account)

    for addr, account in data['additional_preloaded_contracts'].items():
        add_alloc_entry(addr, account)

print(json.dumps(out, indent='  '))
