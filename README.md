# Sub Zero ❄️  (Contracts)

> An efficient way to mine and transact vanity addresses, tokenized as
> [ERC-721](https://eips.ethereum.org/EIPS/eip-721) tokens.

## Deployments

The contracts can trustlessly be deployed to their addresses on any chains that has a
[CreateX](https://github.com/pcaversaccio/createx) deployment using the command:

```
forge script script/Deploy.s.sol:DeployScript -vvv --broadcast --sender <WALLET_ADDR> --rpc-url <RPC_URL> --interactives 1
```

**Main Addresses**

|Contract|Address|
|--------|-------|
|Vanity Market|0x000000000000b361194cfe6312ee3210d53c15aa|
|Micro Create2 Factory|0x6D9FB3C412a269Df566a5c92b85a8dc334F0A797|
|Nonce Increaser|0x00000000000001e4a82b33373de1334e7d8f4879|

**Deployed to chains**
- Sepolia
- Sepolia Base
- Ethereum Mainnet
- Base
- Optimism Mainnet
- Arbitrum One
- Avalanche C-chain
- Mantle
- Blast
- Binance Smart Chain
- Fraxtal
- Polygon POS
- Polygon zkEVM

## License

Note some contracts are marked with and licensed using [AGPL](./LICENSE_AGPL) and others under
[MIT](./LICENSE_MIT). By default for files with no explicit license identifier such as this readme
consider them to be MIT licensed.

## Security

**Known Issues**
- deploy proxies persist post-deployment allowing reuse for other deployments, potentially with
  `msg.value > 0` making it behave incorrectly due to `CALLVALUE` being relied upon for pushing
  zeros: Not seen as an issue because the deploy proxy is only relied upon by the owner upon initial
  deployment, what happens to it afterwards is of little importance
- burning of token upon deployment prevents redeploys on chains that still support classic
  `SELFDESTRUCT`: Not seen as an issue because `SELFDESTRUCT` is considered deprecated regardless
  and because certain second order effects such as the ability to sell no longer usable tokens
  seemed undesirable. Furthermore the complexity required to mitigate the second order effects
  seemed not worth the capability.
