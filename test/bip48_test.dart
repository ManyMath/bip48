import 'package:bip48/bip48.dart';
import 'package:coinlib/coinlib.dart';
import 'package:test/test.dart';

void main() {
  group("BIP48 P2SH Multisig Tests", () {
    setUpAll(() async {
      await loadCoinlib();
    });

    test("Trezor test vector - P2SH 2-of-3 multisig", () {
      // From Trezor test vectors.
      //
      // See https://github.com/trezor/trezor-firmware/blob/f10dc86da21734fd7be36bbd269da112747df1f3/tests/device_tests/bitcoin/test_getaddress_show.py#L177.
      final pubkeys = [
        "xpub6EgGHjcvovyMw8xyoJw9ZRUfjGLS1KUmbjVqMKSNfM6E8hq4EbQ3CpBxfGCPsdxzXtCFuKCxYarzY1TYCG1cmPwq9ep548cM9Ws9rB8V8E8",
        "xpub6EexEtC6c2rN5QCpzrL2nUNGDfxizCi3kM1C2Mk5a6PfQs4H3F72C642M3XbnzycvvtD4U6vzn1nYPpH8VUmiREc2YuXP3EFgN1uLTrVEj4",
        "xpub6F6Tq7sVLDrhuV3SpvsVKrKofF6Hx7oKxWLFkN6dbepuMhuYueKUnQo7E972GJyeRHqPKu44V1C9zBL6KW47GXjuprhbNrPQahWAFKoL2rN",
      ];

      final wallet = Bip48Wallet(
        accountXpub: pubkeys[0], // Start with first key.
        coinType: 0, // Bitcoin mainnet.
        account: 0, // First account.
        scriptType: Bip48ScriptType.p2shMultisig,
        threshold: 2, // 2-of-3.
        totalKeys: 3,
      );

      // Add other two cosigner xpubs.
      wallet.addCosignerXpub(pubkeys[1]);
      wallet.addCosignerXpub(pubkeys[2]);

      // Test external (non-change) address at index 0.
      expect(
        wallet.deriveMultisigAddress(0, isChange: false),
        "33TU5DyVi2kFSGQUfmZxNHgPDPqruwdesY",
      );
    });

    test("Path validation and derivation", () {
      final seedHex = "000102030405060708090a0b0c0d0e0f";
      final masterKey = HDPrivateKey.fromSeed(hexToBytes(seedHex));

      final path = bip48DerivationPath(
        coinType: 0,
        account: 0,
        scriptType: Bip48ScriptType.p2shMultisig,
      );
      expect(path, "m/48'/0'/0'/0'");

      // Verify we can derive through this path
      final wallet = Bip48Wallet(
        masterKey: masterKey,
        coinType: 0,
        account: 0,
        scriptType: Bip48ScriptType.p2shMultisig,
        threshold: 2,
        totalKeys: 3,
      );

      expect(wallet.canSign, true);

      // Add the two cosigners from Trezor's test vector.
      wallet.addCosignerXpub(
          "xpub6EexEtC6c2rN5QCpzrL2nUNGDfxizCi3kM1C2Mk5a6PfQs4H3F72C642M3XbnzycvvtD4U6vzn1nYPpH8VUmiREc2YuXP3EFgN1uLTrVEj4");
      wallet.addCosignerXpub(
          "xpub6F6Tq7sVLDrhuV3SpvsVKrKofF6Hx7oKxWLFkN6dbepuMhuYueKUnQo7E972GJyeRHqPKu44V1C9zBL6KW47GXjuprhbNrPQahWAFKoL2rN");

      // Now test address derivation.
      expect(
        () => wallet.deriveMultisigAddress(HDKey.hardenBit, isChange: false),
        throwsArgumentError,
      );
      expect(
        () => wallet.deriveMultisigAddress(0, isChange: true),
        returnsNormally,
      );
    });

    test("Wallet construction validation", () {
      final seedHex = "000102030405060708090a0b0c0d0e0f";
      final masterKey = HDPrivateKey.fromSeed(hexToBytes(seedHex));

      // Invalid M-of-N.
      expect(
        () => Bip48Wallet(
          masterKey: masterKey,
          coinType: 0,
          account: 0,
          scriptType: Bip48ScriptType.p2shMultisig,
          threshold: 4, // Can't have 4-of-3.
          totalKeys: 3,
        ),
        throwsArgumentError,
      );

      // Must provide either master key or xpub.
      expect(
        () => Bip48Wallet(
          coinType: 0,
          account: 0,
          scriptType: Bip48ScriptType.p2shMultisig,
          threshold: 2,
          totalKeys: 3,
        ),
        throwsArgumentError,
      );
    });
  });
}
