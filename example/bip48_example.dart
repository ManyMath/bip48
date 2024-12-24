import 'package:bip48/bip48.dart';
import 'package:coinlib/coinlib.dart';

void main() async {
  // Initialize coinlib.
  await loadCoinlib();

  // Example 1: Create a 2-of-3 P2SH multisig wallet using xpubs.
  print('\nExample 1: 2-of-3 P2SH multisig from xpubs');
  print('===============================================');

  // These xpubs are from Trezor's test vectors.
  //
  // See https://github.com/trezor/trezor-firmware/blob/f10dc86da21734fd7be36bbd269da112747df1f3/tests/device_tests/bitcoin/test_getaddress_show.py#L177.
  final cosignerXpubs = [
    "xpub6EgGHjcvovyMw8xyoJw9ZRUfjGLS1KUmbjVqMKSNfM6E8hq4EbQ3CpBxfGCPsdxzXtCFuKCxYarzY1TYCG1cmPwq9ep548cM9Ws9rB8V8E8",
    "xpub6EexEtC6c2rN5QCpzrL2nUNGDfxizCi3kM1C2Mk5a6PfQs4H3F72C642M3XbnzycvvtD4U6vzn1nYPpH8VUmiREc2YuXP3EFgN1uLTrVEj4",
    "xpub6F6Tq7sVLDrhuV3SpvsVKrKofF6Hx7oKxWLFkN6dbepuMhuYueKUnQo7E972GJyeRHqPKu44V1C9zBL6KW47GXjuprhbNrPQahWAFKoL2rN",
  ];

  // Create wallet with first xpub.
  final xpubWallet = Bip48Wallet(
    accountXpub: cosignerXpubs[0],
    coinType: 0, // Bitcoin mainnet.
    account: 0,
    scriptType: Bip48ScriptType.p2shMultisig,
    threshold: 2, // 2-of-3 multisig.
    totalKeys: 3,
  );

  // Add other cosigner xpubs.
  xpubWallet.addCosignerXpub(cosignerXpubs[1]);
  xpubWallet.addCosignerXpub(cosignerXpubs[2]);

  // Generate first receiving address.
  final address0 = xpubWallet.deriveMultisigAddress(0, isChange: false);
  print('First receiving address: $address0');

  // Generate first change address.
  final change0 = xpubWallet.deriveMultisigAddress(0, isChange: true);
  print('First change address: $change0');

  // Example 2: Create wallet from master private key.
  print('\nExample 2: P2SH multisig from master key');
  print('========================================');

  // Create from a test seed.
  final seedHex = "000102030405060708090a0b0c0d0e0f";
  final masterKey = HDPrivateKey.fromSeed(hexToBytes(seedHex));

  final privWallet = Bip48Wallet(
    masterKey: masterKey,
    coinType: 0,
    account: 0,
    scriptType: Bip48ScriptType.p2shMultisig,
    threshold: 2,
    totalKeys: 3,
  );

  // Get the account xpub for sharing with cosigners.
  print('Account xpub to share: ${privWallet.accountXpub}');

  // Add cosigner xpubs (using example xpubs from above).
  privWallet.addCosignerXpub(cosignerXpubs[1]);
  privWallet.addCosignerXpub(cosignerXpubs[2]);

  // Generate addresses.
  print(
      'First receiving address: ${privWallet.deriveMultisigAddress(0, isChange: false)}');
  print(
      'First change address: ${privWallet.deriveMultisigAddress(0, isChange: true)}');
}
