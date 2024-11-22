import type { TypedDataDomain, TypedDataField } from "ethers";
import {
  BaseWallet,
  AbiCoder,
  keccak256,
  SigningKey,
  parseUnits,
  JsonRpcProvider,
  Signature,
} from "ethers";
import { parseArgs } from "util";

const VANITY_MARKET = "0x000000000000b361194cfe6312ee3210d53c15aa";

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

const { values: args, positionals } = parseArgs({
  args: Bun.argv.slice(2),
  options: {
    help: { type: "boolean" },
    beneficiary: { type: "string" },
    buyer: {
      type: "string",
      default: "0x0000000000000000000000000000000000000000",
    },
    deadline: { type: "string", default: (1n << 248n).toString() },
    "rpc-url": { type: "string" },
    "chain-id": { type: "string" },
    nonce: { type: "string" },
  },
  allowPositionals: true,
  strict: true,
});

if (args.help) {
  console.log(
    "privKey id saltNonce price --chain-id --nonce --beneficiary --buyer --deadline --rpc-url",
  );
  process.exit(0);
}

const [privKey, id, saltNonce, price] = positionals;

const wallet = new BaseWallet(new SigningKey(privKey));

const getBitmapSlot = (slot: any, index: bigint): string => {
  return keccak256(
    AbiCoder.defaultAbiCoder().encode(["uint256", "uint256"], [index, slot]),
  );
};

const [nonce, chainId] = await (async function () {
  if (args["rpc-url"] !== undefined) {
    const provider = new JsonRpcProvider(args["rpc-url"]);
    const chainId = (await provider.getNetwork()).chainId;
    const walletBitmapBaseSlot = keccak256(
      AbiCoder.defaultAbiCoder().encode(
        ["address", "uint256"],
        [wallet.address, 0],
      ),
    );

    let index = -1n;
    let bitmap: bigint;
    do {
      index++;
      const bitmapSlot = getBitmapSlot(walletBitmapBaseSlot, index);
      bitmap = BigInt(await provider.getStorage(VANITY_MARKET, bitmapSlot));
    } while (bitmap == (1n << 256n) - 1n);

    let freeBit = 0n;
    while (((1n << freeBit) & bitmap) != 0n) freeBit++;

    return [(index * 256n + freeBit).toString(), chainId.toString()];
  }
  return [args.nonce, args["chain-id"]];
})();

const domain: TypedDataDomain = {
  name: "Tokenized CREATE3 Vanity Addresses",
  version: "1.0",
  verifyingContract: VANITY_MARKET,
  chainId,
};

const values = {
  id,
  saltNonce,
  price: parseUnits(price, "ether").toString(),
  beneficiary: args.beneficiary ?? wallet.address,
  buyer: args.buyer,
  nonce: nonce,
  deadline: args.deadline ?? (1n << 248n).toString(),
};

const signature = Signature.from(
  await wallet.signTypedData(domain, MINT_AND_SELL, values),
);

console.log({
  ...values,
  signature: signature.r + signature.yParityAndS.slice(2),
});
