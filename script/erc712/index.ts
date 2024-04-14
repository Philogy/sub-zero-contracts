import type { TypedDataDomain, TypedDataField } from "ethers";
import { TypedDataEncoder } from "ethers";

const [, , addr, chainId, struct, ...args] = Bun.argv;

const crossChainDomain: TypedDataDomain = {
  name: "Tokenized CREATE3 Vanity Addresses",
  version: "1.0",
  verifyingContract: addr,
};

const fullDomain: TypedDataDomain = {
  ...crossChainDomain,
  chainId,
};

const GIVE_UP_EVERWHERE: Record<string, Array<TypedDataField>> = {
  GiveUpEverywhere: [
    { type: "uint256", name: "id" },
    { type: "uint8", name: "nonce" },
    { type: "address", name: "claimer" },
    { type: "uint256", name: "deadline" },
  ],
};

const MINT_AND_SELL: Record<string, Array<TypedDataField>> = {
  MintAndSell: [
    { type: "uint256", name: "id" },
    { type: "uint8", name: "saltNonce" },
    { type: "uint256", name: "price" },
    { type: "address", name: "beneficiary" },
    { type: "address", name: "buyer" },
    { type: "uint256", name: "nonce" },
    { type: "uint256", name: "deadline" },
  ],
};

const hash = (function(): string {
  let values;
  switch (struct) {
    case "GiveUpEverywhere":
      values = Object.fromEntries(
        GIVE_UP_EVERWHERE.GiveUpEverywhere.map(({ name }, i) => [
          name,
          args[i],
        ]),
      );
      return TypedDataEncoder.hash(crossChainDomain, GIVE_UP_EVERWHERE, values);
    case "MintAndSell":
      values = Object.fromEntries(
        MINT_AND_SELL.MintAndSell.map(({ name }, i) => [name, args[i]]),
      );
      return TypedDataEncoder.hash(fullDomain, MINT_AND_SELL, values);

    default:
      throw new Error(`Unrecognized struct "${struct}"`);
  }
})();

console.log(hash);
