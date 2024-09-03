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

Add `--broadcast` to the end of the following the actually publish.

# Community Module + Paymaster
```shell
$ forge script script/CommunityModule.s.sol:CommunityModuleScript --sig "deploy(address[])" "[0x5815E61eF72c9E6107b5c5A05FD121F334f7a7f1,0x56Cc38bDa01bE6eC6D854513C995f6621Ee71229,0x37e40A8c3061Bd2cCa824E751768ed0Acd3C88fa]" --rpc-url $GNOSIS_MAINNET_RPC_URL --etherscan-api-key $GNOSIS_MAINNET_ETHERSCAN_API_KEY --verify --private-key $PRIVATE_KEY 
```

# Account Factory
```shell
$ forge script script/AccountFactory.s.sol:AccountFactoryScript --sig "deploy(address)" 0x64B2D50ddc1a20a9b9bAF30f02983ff61B6b9963 --rpc-url $GNOSIS_MAINNET_RPC_URL --etherscan-api-key $GNOSIS_MAINNET_ETHERSCAN_API_KEY --verify --private-key $PRIVATE_KEY 
```

# Card Manager
```shell
$ forge script script/CardManagerModule.s.sol:CardManagerModuleScript --sig "deploy(address)" 0x64B2D50ddc1a20a9b9bAF30f02983ff61B6b9963 --rpc-url $GNOSIS_MAINNET_RPC_URL --etherscan-api-key $GNOSIS_MAINNET_ETHERSCAN_API_KEY --verify --private-key $PRIVATE_KEY 
```