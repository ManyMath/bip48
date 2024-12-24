import 'package:coinlib/coinlib.dart' as coinlib;

class BitcoinNetwork {
  final coinlib.Network mainnet;
  final coinlib.Network testnet;

  const BitcoinNetwork({
    required this.mainnet,
    required this.testnet,
  });
}

// See https://github.com/cypherstack/stack_wallet/blob/4197ff40f45a96c6b9bbe590ab5fc7e7d3310bc0/lib/wallets/crypto_currency/coins/bitcoin.dart#L91-L123.
final bitcoinNetwork = BitcoinNetwork(
  mainnet: coinlib.Network(
    wifPrefix: 0x80,
    p2pkhPrefix: 0x00,
    p2shPrefix: 0x05,
    privHDPrefix: 0x0488ade4,
    pubHDPrefix: 0x0488b21e,
    bech32Hrp: "bc",
    messagePrefix: '\x18Bitcoin Signed Message:\n',
    minFee: BigInt.from(1),
    minOutput: BigInt.from(294),
    feePerKb: BigInt.from(1),
  ),
  testnet: coinlib.Network(
    wifPrefix: 0xef,
    p2pkhPrefix: 0x6f,
    p2shPrefix: 0xc4,
    privHDPrefix: 0x04358394,
    pubHDPrefix: 0x043587cf,
    bech32Hrp: "tb",
    messagePrefix: "\x18Bitcoin Signed Message:\n",
    minFee: BigInt.from(1),
    minOutput: BigInt.from(294),
    feePerKb: BigInt.from(1),
  ),
);
