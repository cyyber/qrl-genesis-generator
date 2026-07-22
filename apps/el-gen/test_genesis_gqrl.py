import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("genesis_gqrl.py")
DEPOSIT_ADDRESS = "Q" + "42" * 64
DEPOSIT_RUNTIME_SHA256 = "f2db8aa6b661b536a673f8c064bf69478aecee0d863cdfe2ab08b1a7b12af43e"


class GenesisTest(unittest.TestCase):
    def test_vm64_genesis(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            config = Path(temp_dir) / "genesis-config.yaml"
            config.write_text(
                "\n".join(
                    [
                        "chain_id: 1337",
                        f'deposit_contract_address: "{DEPOSIT_ADDRESS}"',
                        "el_premine_addrs: {}",
                        "additional_preloaded_contracts: {}",
                        "genesis_timestamp: 0",
                        "genesis_gaslimit: 25000000",
                    ]
                )
            )
            result = subprocess.run(
                [sys.executable, str(SCRIPT), str(config)],
                check=True,
                capture_output=True,
                text=True,
            )

        genesis = json.loads(result.stdout)
        self.assertEqual(genesis["coinbase"], "Q" + "00" * 64)
        for index in range(256):
            address = "Q" + index.to_bytes(64, byteorder="big").hex()
            self.assertIn(address, genesis["alloc"])

        deposit = genesis["alloc"][DEPOSIT_ADDRESS]
        runtime = bytes.fromhex(deposit["code"][2:])
        self.assertEqual(len(runtime), 7970)
        self.assertEqual(hashlib.sha256(runtime).hexdigest(), DEPOSIT_RUNTIME_SHA256)

        zero_hashes = [bytes(32)]
        for _ in range(31):
            zero_hashes.append(hashlib.sha256(zero_hashes[-1] * 2).digest())
        expected_storage = {}
        for index, slot in enumerate(range(0x11, 0x21)):
            packed = zero_hashes[2 * index + 1] + zero_hashes[2 * index]
            expected_storage[f"0x{slot:064x}"] = "0x" + packed.hex()
        self.assertEqual(deposit["storage"], expected_storage)


if __name__ == "__main__":
    unittest.main()
