## Citizen Wallet Smart Contracts

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>

$ forge script script/anvil/CardManagerAnvil.s.sol:CardManagerAnvilScript --sig "deploy()"  --rpc-url http://127.0.0.1:8545
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

# Create2

```shell
forge create --rpc-url $GNOSIS_MAINNET_RPC_URL --private-key $PRIVATE_KEY src/Create2/Create2.sol:Create2
```

Add `--broadcast` to the end of the following the actually publish.

# Token
```shell
$ forge script script/UpgradeableCommunityToken.s.sol:UpgradeableCommunityTokenScript --sig "deploy(address[], string, string)" "[0x123]" "My Token" "MT" --rpc-url $GNOSIS_MAINNET_RPC_URL --etherscan-api-key $GNOSIS_MAINNET_ETHERSCAN_API_KEY --verify --verifier-url $GNOSIS_ETHERSCAN_VERIFIER_URL --private-key $PRIVATE_KEY 
```

# Community Module
```shell
$ forge script script/CommunityModule.s.sol:CommunityModuleScript --sig "deploy()" --rpc-url $GNOSIS_MAINNET_RPC_URL --etherscan-api-key $GNOSIS_MAINNET_ETHERSCAN_API_KEY --verify --verifier-url $GNOSIS_ETHERSCAN_VERIFIER_URL --private-key $PRIVATE_KEY 
```

# Community Module Upgrade (v2)
```shell
$ forge script script/upgrade/UpgradeCommunityModule.s.sol:UpgradeCommunityModuleScript --sig "run(address)" "0x7079253c0358eF9Fd87E16488299Ef6e06F403B6" --rpc-url $POLYGON_ZK_MAINNET_RPC_URL --etherscan-api-key $POLYGON_ZK_MAINNET_ETHERSCAN_API_KEY --verify --verifier-url $POLYGON_ZK_ETHERSCAN_VERIFIER_URL --private-key $PRIVATE_KEY 
```

# Community + Paymaster Module
```shell
$ forge script script/CommunityAndPaymaster.s.sol:CommunityAndPaymasterModuleScript --sig "deploy(address[])" "[]" --rpc-url $GNOSIS_MAINNET_RPC_URL --etherscan-api-key $GNOSIS_MAINNET_ETHERSCAN_API_KEY --verify --verifier-url $GNOSIS_ETHERSCAN_VERIFIER_URL --private-key $PRIVATE_KEY 
```

# Paymaster
```shell
$ forge script script/Paymaster.s.sol:PaymasterDeploy --sig "deploy(address,address[])" 0x61a5c5aB3Bf53bD60aac8954e7904B0F97aA456e "[0x27F69bcDB85E6Ed437Ff3Efc114d7125B7338BFA]" --rpc-url $GNOSIS_MAINNET_RPC_URL --etherscan-api-key $GNOSIS_MAINNET_ETHERSCAN_API_KEY --verify --verifier-url $GNOSIS_ETHERSCAN_VERIFIER_URL --private-key $PRIVATE_KEY 
```

# Account Factory
```shell
$ forge script script/AccountFactory.s.sol:AccountFactoryScript --sig "deploy(address)" 0x7079253c0358eF9Fd87E16488299Ef6e06F403B6 --rpc-url $GNOSIS_MAINNET_RPC_URL --etherscan-api-key $GNOSIS_MAINNET_ETHERSCAN_API_KEY --verify --verifier-url $GNOSIS_ETHERSCAN_VERIFIER_URL --private-key $PRIVATE_KEY 
```

# Card Manager
```shell
$ forge script script/CardManagerModule.s.sol:CardManagerModuleScript --sig "deploy(address)" 0x7079253c0358eF9Fd87E16488299Ef6e06F403B6 --rpc-url $ARBITRUM_MAINNET_RPC_URL --etherscan-api-key $ARBITRUM_MAINNET_ETHERSCAN_API_KEY --verify --verifier-url $ARBITRUM_ETHERSCAN_VERIFIER_URL --private-key $PRIVATE_KEY 
```

# Session Manager
```shell
$ forge script script/SessionManagerModule.s.sol:SessionManagerModuleScript --sig "deploy(address)" 0x7079253c0358eF9Fd87E16488299Ef6e06F403B6 --rpc-url $GNOSIS_MAINNET_RPC_URL --etherscan-api-key $GNOSIS_MAINNET_ETHERSCAN_API_KEY --verify --verifier-url $GNOSIS_ETHERSCAN_VERIFIER_URL --private-key $PRIVATE_KEY 
```