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

$ forge script script/anvil/SafeSingleton.s.sol:SafeSingletonScript --sig "deploy()"  --rpc-url http://127.0.0.1:8545

$ forge script script/anvil/SessionManagerModuleAnvil.s.sol:SessionManagerModuleAnvilScript --sig "deploy()"  --rpc-url http://127.0.0.1:8545
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
$ forge script script/UpgradeableCommunityToken.s.sol:UpgradeableCommunityTokenScript --sig "deploy(address[], string, string)" "[0xc7f0faE75ff61A28A6CC48C168469Bc5A0Ee39bd]" "DAO Brussels" "DAOB" --rpc-url $GNOSIS_MAINNET_RPC_URL --etherscan-api-key $GNOSIS_MAINNET_ETHERSCAN_API_KEY --verify --verifier-url $GNOSIS_ETHERSCAN_VERIFIER_URL --private-key $PRIVATE_KEY 
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
$ forge script script/Paymaster.s.sol:PaymasterDeploy --sig "deploy(address,address[])" 0xAD364095327753CC338e7cDF9752e039F51676F8 "[0x77917475e63E6f4e6966169E66c8FaB7dC891772,0x1371907cfe89Dc5022a3cB99ffBc4d7430f760cE,0xBA861e2DABd8316cf11Ae7CdA101d110CF581f28]" --rpc-url $CELO_MAINNET_RPC_URL --etherscan-api-key $CELO_MAINNET_ETHERSCAN_API_KEY --verify --verifier-url $CELO_ETHERSCAN_VERIFIER_URL --private-key $PRIVATE_KEY --broadcast
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

# Session Module Upgrade (v2)
```shell
$ forge script script/upgrade/UpgradeSessionManagerModule.s.sol:UpgradeSessionManagerModuleScript --sig "run(address)" "0xE544c1dC66f65967863F03AEdEd38944E6b87309" --rpc-url $GNOSIS_MAINNET_RPC_URL --etherscan-api-key $GNOSIS_MAINNET_ETHERSCAN_API_KEY --verify --verifier-url $GNOSIS_ETHERSCAN_VERIFIER_URL --private-key $PRIVATE_KEY 
```

# Swapper
```shell
$ forge script script/OnRampSwapper.s.sol:OnRampSwapperScript --sig "deploy(address,address,address,address)" 0xf5b509bB0909a69B1c207E495f687a596C168E12 0x0D9B0790E97e3426C161580dF4Ee853E4A7C4607 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270 0xA232F16aB37C9a646f91Ba901E92Ed1Ba4B7b544 --rpc-url $POLYGON_MAINNET_RPC_URL --etherscan-api-key $POLYGON_MAINNET_ETHERSCAN_API_KEY --verify --verifier-url $POLYGON_ETHERSCAN_VERIFIER_URL --private-key $PRIVATE_KEY 
```