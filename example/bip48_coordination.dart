// bip48_example.dart, but with an additional classes necessary for
// coordinating a shared multisig account according to BIP48.

import 'package:bip48/bip48.dart';
import 'package:bip48/src/networks/bitcoin.dart';
import 'package:coinlib/coinlib.dart';

/// Represents the parameters needed to create a shared multisig account.
class MultisigParams {
  final int threshold;
  final int totalCosigners;
  final int coinType;
  final int account;
  final Bip48ScriptType scriptType;

  const MultisigParams({
    required this.threshold,
    required this.totalCosigners,
    required this.coinType,
    required this.account,
    required this.scriptType,
  });

  // Validate parameters.
  bool isValid() {
    return threshold > 0 &&
        threshold <= totalCosigners &&
        account >= 0 &&
        coinType >= 0;
  }
}

/// Represents a participant in the multisig setup process.
class CosignerInfo {
  final String accountXpub;
  final int index; // Position in the sorted set of cosigners.

  const CosignerInfo({
    required this.accountXpub,
    required this.index,
  });
}

/// Coordinates the creation of a shared multisig account between multiple users.
class MultisigCoordinator {
  final HDPrivateKey? localMasterKey;
  final MultisigParams params;
  final List<CosignerInfo> _cosigners = [];
  String? _accountXpub;

  MultisigCoordinator({
    required this.localMasterKey,
    required this.params,
  }) {
    if (!params.isValid()) {
      throw ArgumentError('Invalid multisig parameters');
    }
  }

  /// Create a coordinator from an account xpub instead of master key.
  MultisigCoordinator.fromXpub({
    required String accountXpub,
    required this.params,
  }) : localMasterKey = null {
    if (!params.isValid()) {
      throw ArgumentError('Invalid multisig parameters');
    }
    _accountXpub = accountXpub;
  }

  /// Get this user's account xpub that needs to be shared with other cosigners.
  String getLocalAccountXpub() {
    if (_accountXpub != null) {
      return _accountXpub!;
    }

    if (localMasterKey == null) {
      throw StateError('No master key or account xpub available');
    }

    final path = bip48DerivationPath(
      coinType: params.coinType,
      account: params.account,
      scriptType: params.scriptType,
    );
    final accountKey = localMasterKey!.derivePath(path);
    return accountKey.hdPublicKey.encode(bitcoinNetwork.mainnet.pubHDPrefix);
  }

  /// Add a cosigner's account xpub to the set.
  void addCosigner(String accountXpub) {
    if (_cosigners.length >= params.totalCosigners - 1) {
      throw StateError('All cosigners have been added');
    }

    // Assign index based on current position
    _cosigners.add(CosignerInfo(
      accountXpub: accountXpub,
      index: _cosigners.length + 1, // Local user is always index 0.
    ));
  }

  /// Check if we have collected all required cosigner information.
  bool isComplete() {
    return _cosigners.length == params.totalCosigners - 1;
  }

  /// Create the local wallet instance once all cosigners are added.
  Bip48Wallet createWallet() {
    if (!isComplete()) {
      throw StateError('Not all cosigners have been added');
    }

    // Create wallet with our key or xpub.
    final wallet = localMasterKey != null
        ? Bip48Wallet(
            masterKey: localMasterKey,
            coinType: params.coinType,
            account: params.account,
            scriptType: params.scriptType,
            threshold: params.threshold,
            totalKeys: params.totalCosigners,
          )
        : Bip48Wallet(
            accountXpub: _accountXpub,
            coinType: params.coinType,
            account: params.account,
            scriptType: params.scriptType,
            threshold: params.threshold,
            totalKeys: params.totalCosigners,
          );

    // Add all cosigner xpubs.
    for (final cosigner in _cosigners) {
      wallet.addCosignerXpub(cosigner.accountXpub);
    }

    return wallet;
  }

  /// Verify that derived addresses match between all participants.
  ///
  /// Returns true if all provided addresses match our derivation.
  bool verifyAddresses(List<String> sharedAddresses,
      {required List<int> indices, required bool isChange}) {
    if (!isComplete()) return false;

    final wallet = createWallet();
    for (final idx in indices) {
      final derivedAddress =
          wallet.deriveMultisigAddress(idx, isChange: isChange);
      final sharedAddress = sharedAddresses[indices.indexOf(idx)];
      if (derivedAddress != sharedAddress) return false;
    }
    return true;
  }

  /// Get a list of test addresses for verification.
  List<String> getVerificationAddresses(
      {required List<int> indices, required bool isChange}) {
    if (!isComplete()) {
      throw StateError('Not all cosigners have been added');
    }

    final wallet = createWallet();
    return indices
        .map((idx) => wallet.deriveMultisigAddress(idx, isChange: isChange))
        .toList();
  }
}

/// Example usage with Trezor test vectors.
void main() async {
  // Initialize coinlib.
  await loadCoinlib();

  print('\nExample 1: Using Trezor test vectors for 2-of-3 P2SH multisig');
  print('==========================================================');

  // These are from Trezor's test vectors.
  final trezorXpubs = [
    "xpub6EgGHjcvovyMw8xyoJw9ZRUfjGLS1KUmbjVqMKSNfM6E8hq4EbQ3CpBxfGCPsdxzXtCFuKCxYarzY1TYCG1cmPwq9ep548cM9Ws9rB8V8E8",
    "xpub6EexEtC6c2rN5QCpzrL2nUNGDfxizCi3kM1C2Mk5a6PfQs4H3F72C642M3XbnzycvvtD4U6vzn1nYPpH8VUmiREc2YuXP3EFgN1uLTrVEj4",
    "xpub6F6Tq7sVLDrhuV3SpvsVKrKofF6Hx7oKxWLFkN6dbepuMhuYueKUnQo7E972GJyeRHqPKu44V1C9zBL6KW47GXjuprhbNrPQahWAFKoL2rN",
  ];

  // Define shared parameters matching Trezor test vectors.
  final params = MultisigParams(
    threshold: 2,
    totalCosigners: 3,
    coinType: 0, // Bitcoin mainnet.
    account: 0, // First account.
    scriptType: Bip48ScriptType.p2shMultisig, // P2SH multisig.
  );

  // Create coordinator starting with first xpub.
  final coordinator = MultisigCoordinator.fromXpub(
    accountXpub: trezorXpubs[0],
    params: params,
  );

  print('First cosigner xpub: ${trezorXpubs[0]}');

  // Add other cosigners
  coordinator.addCosigner(trezorXpubs[1]);
  coordinator.addCosigner(trezorXpubs[2]);

  // Once complete, create the wallet and verify addresses.
  if (coordinator.isComplete()) {
    final wallet = coordinator.createWallet();
    // This is the final shared wallet which would be used for signing.

    // Get first receiving and change addresses.
    final addresses =
        coordinator.getVerificationAddresses(indices: [0], isChange: false);
    final changeAddresses =
        coordinator.getVerificationAddresses(indices: [0], isChange: true);

    print('\nFirst receiving address: ${addresses[0]}');
    print('First change address: ${changeAddresses[0]}');
  }

  print('\nExample 2: Using master private key');
  print('================================');

  // Create from test seed.
  final seedHex = "000102030405060708090a0b0c0d0e0f";
  final masterKey = HDPrivateKey.fromSeed(hexToBytes(seedHex));

  // Create coordinator with private key.
  final privKeyCoordinator = MultisigCoordinator(
    localMasterKey: masterKey,
    params: params,
  );

  // Get account xpub to share with others.
  final accountXpub = privKeyCoordinator.getLocalAccountXpub();
  print('Account xpub to share: $accountXpub');

  // Add same cosigner xpubs as before.
  privKeyCoordinator.addCosigner(trezorXpubs[1]);
  privKeyCoordinator.addCosigner(trezorXpubs[2]);

  if (privKeyCoordinator.isComplete()) {
    final wallet = privKeyCoordinator.createWallet();
    // This is the final shared wallet which would be used for signing.

    // Get addresses for verification.
    final addresses = privKeyCoordinator
        .getVerificationAddresses(indices: [0], isChange: false);
    final changeAddresses = privKeyCoordinator
        .getVerificationAddresses(indices: [0], isChange: true);

    print('\nFirst receiving address: ${addresses[0]}');
    print('First change address: ${changeAddresses[0]}');
  }
}
