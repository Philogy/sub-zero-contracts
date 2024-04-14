import type { TypedDataDomain, TypedDataField } from "ethers";
import { BaseWallet, SigningKey } from "ethers";

if (Bun.argv.some((arg) => arg === "-h" || arg === "--help")) {
  console.log("give-up.ts privKey id nonce claimer deadline?");
  process.exit(0);
}

const [, , privKey, ...args] = Bun.argv;

const VANITY_MARKET = "0x000000000000b361194cfe6312ee3210d53c15aa";

const crossChainDomain: TypedDataDomain = {
  name: "Tokenized CREATE3 Vanity Addresses",
  version: "1.0",
  verifyingContract: VANITY_MARKET,
};

const GIVE_UP_EVERWHERE: Record<string, Array<TypedDataField>> = {
  GiveUpEverywhere: [
    { type: "uint256", name: "id" },
    { type: "uint8", name: "nonce" },
    { type: "address", name: "claimer" },
    { type: "uint256", name: "deadline" },
  ],
};

const wallet = new BaseWallet(new SigningKey(privKey));
const values = Object.fromEntries(
  GIVE_UP_EVERWHERE.GiveUpEverywhere.map(({ name }, i) => [name, args[i]]),
);
values.deadline ??= (1n << 248n).toString();
const signature = await wallet.signTypedData(
  crossChainDomain,
  GIVE_UP_EVERWHERE,
  values,
);

console.log({
  ...values,
  signature,
});
