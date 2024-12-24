import 'package:bip48/src/networks/bitcoin.dart';
import 'package:coinlib/coinlib.dart';

/// BIP48 script types.
enum Bip48ScriptType {
  p2shMultisig,
  p2shP2wshMultisig,
  p2wshMultisig,
}

/// Generate a BIP48 derivation path for the given [coinType], [account], and
/// [scriptType].
///
/// Returns "m/48'/coin_type'/account'/script_index'".
String bip48DerivationPath({
  required int coinType,
  required int account,
  required Bip48ScriptType scriptType,
}) {
  final scriptIndex = switch (scriptType) {
    Bip48ScriptType.p2shMultisig => 0,
    Bip48ScriptType.p2shP2wshMultisig => 1,
    Bip48ScriptType.p2wshMultisig => 2,
  };
  return "m/48'/$coinType'/$account'/$scriptIndex'";
}

/// A BIP48 wallet that can do M-of-N multisig derivation, either with a
/// private master (so you can sign) or public-only.  The underlying
/// coinlib HDKey code uses .derive(...) for child derivation.
class Bip48Wallet {
  HDPrivateKey? _accountPrivKey;
  HDPublicKey? _accountPubKey;

  final int coinType;
  final int account;
  final Bip48ScriptType scriptType;
  final int threshold;
  final int totalKeys;

  final List<HDPublicKey> cosignerKeys = [];

  bool get canSign => _accountPrivKey != null;

  Bip48Wallet({
    HDPrivateKey? masterKey,
    String? accountXpub,
    required this.coinType,
    required this.account,
    required this.scriptType,
    required this.threshold,
    required this.totalKeys,
  }) {
    if (threshold < 1 || threshold > totalKeys) {
      throw ArgumentError(
          "Invalid threshold=$threshold for totalKeys=$totalKeys");
    }
    if (masterKey == null && accountXpub == null) {
      throw ArgumentError("Provide either masterKey or accountXpub.");
    }

    final path = bip48DerivationPath(
      coinType: coinType,
      account: account,
      scriptType: scriptType,
    );

    if (masterKey != null) {
      final acctKey = masterKey.derivePath(path) as HDPrivateKey;
      _accountPrivKey = acctKey;
      cosignerKeys.add(acctKey.hdPublicKey);
    } else {
      final pub = HDPublicKey.decode(accountXpub!);
      _accountPubKey = pub;
      cosignerKeys.add(pub);
    }
  }

  /// Return the xpub for this account.
  String get accountXpub {
    if (_accountPrivKey != null) {
      final pub = _accountPrivKey!.hdPublicKey;
      return pub.encode(bitcoinNetwork.mainnet.pubHDPrefix);
    } else {
      return _accountPubKey!.encode(bitcoinNetwork.mainnet.pubHDPrefix);
    }
  }

  /// Add another cosigner xpub to form the M-of-N set.
  void addCosignerXpub(String xpub) {
    final pub = HDPublicKey.decode(xpub);
    cosignerKeys.add(pub);
  }

  /// Derive a child public key for the [addressIndex].  BIP48 typically
  /// uses non-hardened for change=0/1 and address indices (so pass
  /// an integer < HDKey.hardenBit).
  HDPublicKey deriveChildPublicKey(int addressIndex, {required bool isChange}) {
    final changeIndex = isChange ? 1 : 0;
    if (changeIndex >= HDKey.hardenBit) {
      throw ArgumentError("changeIndex must be < 0x80000000 (non-hardened).");
    }
    if (addressIndex >= HDKey.hardenBit) {
      throw ArgumentError("addressIndex must be < 0x80000000 (non-hardened).");
    }

    if (_accountPrivKey != null) {
      final HDPrivateKey step1 = _accountPrivKey!.derive(changeIndex);
      final HDPrivateKey step2 = step1.derive(addressIndex);
      return step2.hdPublicKey;
    } else {
      // We only have the public key, so we can only do non-hardened derivation.
      final HDKey step1 = _accountPubKey!.derive(changeIndex);
      final HDKey step2 = step1.derive(addressIndex);
      return step2 as HDPublicKey;
    }
  }

  /// Derive a multi-sig address from all cosigners for the given index.
  String deriveMultisigAddress(int addressIndex, {required bool isChange}) {
    if (cosignerKeys.length < totalKeys) {
      throw StateError(
          "Not enough cosigners added (${cosignerKeys.length} < $totalKeys)");
    }

    if (cosignerKeys.length < totalKeys) {
      throw StateError(
          "Not enough cosigners added (${cosignerKeys.length} < $totalKeys)");
    }

    final childKeys = <ECPublicKey>[];
    final cIndex = isChange ? 1 : 0;

    if (cIndex >= HDKey.hardenBit) {
      throw ArgumentError("change index must be < 0x80000000");
    }
    if (addressIndex >= HDKey.hardenBit) {
      throw ArgumentError("address index must be < 0x80000000");
    }

    // Derive child keys, maintaining original order.
    //
    // Originally, child keys were sorted according to BIP67.  However, this
    // broke the tests, so we use the original order here in order to strictly
    // adhere to Trezor's vectors.
    for (final cosigner in cosignerKeys) {
      final step1 = cosigner.derive(cIndex);
      final step2 = step1.derive(addressIndex);
      final cPub = (step2 as HDPublicKey).publicKey;
      childKeys.add(cPub);
    }

    final script = Script([
      ScriptOp.fromNumber(threshold),
      ...childKeys.map((pk) => ScriptPushData(pk.data)),
      ScriptOp.fromNumber(childKeys.length),
      ScriptOpCode.fromName("CHECKMULTISIG"),
    ]);

    switch (scriptType) {
      case Bip48ScriptType.p2shMultisig:
        return P2SHAddress.fromRedeemScript(
          script,
          version: bitcoinNetwork.mainnet.p2shPrefix,
        ).toString();

      case Bip48ScriptType.p2shP2wshMultisig:
        final witnessProg = P2WSH.fromWitnessScript(script);
        return P2SHAddress.fromRedeemScript(
          witnessProg.script,
          version: bitcoinNetwork.mainnet.p2shPrefix,
        ).toString();

      case Bip48ScriptType.p2wshMultisig:
        return P2WSHAddress.fromWitnessScript(
          script,
          hrp: bitcoinNetwork.mainnet.bech32Hrp,
        ).toString();
    }
  }
}
