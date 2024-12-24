# `BIP48`
BIP-0048 "Multi-Script Hierarchy for Multi-Sig Wallets" for Dart.

Used to derive "shared accounts" from Hierarchical Deterministic (HD) wallets.

## Getting started
```bash
git clone https://github.com/cypherstack/bip48
cd bip48
dart pub get
dart run coinlib:build_linux
# Refer to 
# https://github.com/peercoin/coinlib/tree/master/coinlib#installation-and-usage 
# for build instructions for your platform.  Basically, use 
# `dart run coinlib:build_platform` (select from: `linux`, `macos`, `windows`, 
# `windows_crosscompile`, or `wsl`).  If these don't work, check for build 
# scripts for your platform in the `scripts` folder.
dart test
```

## Usage
See the example and tests for usage.
