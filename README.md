# Sub Zero ❄️  (Contracts)

> An efficient way to mine and transact vanity addresses, tokenized as
> [ERC-721](https://eips.ethereum.org/EIPS/eip-721) tokens.

## Deployments

The contracts can trustlessly be deployed to their addresses on any chains that has a
[CreateX](https://github.com/pcaversaccio/createx) deployment using the command:

```bash
forge script script/Deploy.s.sol:DeployScript -vvv --broadcast --sender <WALLET_ADDR> --rpc-url <RPC_URL> --interactives 1
```

### Main Addresses

|Contract|Address|
|--------|-------|
|Vanity Market|0x000000000000b361194cfe6312EE3210d53C15AA|
|Micro Create2 Factory|0x6D9FB3C412a269Df566a5c92b85a8dc334F0A797|
|Nonce Increaser|0x00000000000001E4A82b33373DE1334E7d8F4879|

### Mainnet

- Ethereum (1)
- Base (8453)
- Optimism (10)
- Arbitrum One (42161)
- Avalanche C-Chain (43114)
- Mantle (5000)
- Blast (81457)
- Binance Smart Chain (56)
- Polygon PoS (137)
- Polygon zkEVM (1101)
- Katana (747474)
- Unichain (130)
- Plasma (9745)
- Berachain (80094)
- Sei (1329)
- Monad (143)
- Plume (98866)
- Immutable zkEVM (13371)
- Fraxtal (252)
- Citrea (4114)
- Chiliz (88888)

### Testnet

- Ethereum Sepolia (11155111)
- Base Sepolia (84532)
- Unichain Sepolia (1301)
- Plasma Testnet (9746)
- Berachain Bepolia (80069)
- Sei Testnet (1328)
- Mega ETH (6342)
- Chiliz Spicy (88882)

## License

Note some contracts are marked with and licensed using [AGPL](./LICENSE_AGPL) and others under
[MIT](./LICENSE_MIT). By default for files with no explicit license identifier such as this readme
consider them to be MIT licensed.

## Security

### Known Issues

- deploy proxies persist post-deployment allowing reuse for other deployments, potentially with
  `msg.value > 0` making it behave incorrectly due to `CALLVALUE` being relied upon for pushing
  zeros: Not seen as an issue because the deploy proxy is only relied upon by the owner upon initial
  deployment, what happens to it afterwards is of little importance
- burning of token upon deployment prevents redeploys on chains that still support classic
  `SELFDESTRUCT`: Not seen as an issue because `SELFDESTRUCT` is considered deprecated regardless
  and because certain second order effects such as the ability to sell no longer usable tokens
  seemed undesirable. Furthermore the complexity required to mitigate the second order effects
  seemed not worth the capability.
