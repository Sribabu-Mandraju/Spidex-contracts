import { ethers } from "ethers";
import "dotenv/config";
import ABI from "./SpidexERC20_ABI.json" with { type: "json" };

const PRIVATE_KEY = process.env.PRIVATE_KEY;
const OWNER = process.env.OWNER;
const SPENDER = process.env.SPENDER;
const TOKEN_ADDRESS = process.env.CONTRACT;
const RPC_URL = process.env.RPC_URL;
const CHAIN_ID = 84532;

const provider = new ethers.JsonRpcProvider(RPC_URL);

const token = new ethers.Contract(
    TOKEN_ADDRESS,
    ABI,
    provider
);

const nonce = await token.nonces(OWNER);

const domain = {
    name: "Spidex-ERC20",
    version: "1",
    chainId: CHAIN_ID,
    verifyingContract: TOKEN_ADDRESS
};

const types = {
    Permit: [
        { name: "owner", type: "address" },
        { name: "spender", type: "address" },
        { name: "value", type: "uint256" },
        { name: "nonce", type: "uint256" },
        { name: "deadline", type: "uint256" }
    ]
};

const message = {
    owner: OWNER,
    spender: SPENDER,
    value: ethers.parseEther("0.5"),
    nonce,
    deadline: Math.floor(Date.now() / 1000) + 3600
};

async function main() {
    const wallet = new ethers.Wallet(PRIVATE_KEY);

    const signature = await wallet.signTypedData(
        domain,
        types,
        message
    );

    const recovered = ethers.verifyTypedData(
        domain,
        types,
        message,
        signature
    );

    console.log("Signature:", signature);
    console.log("Recovered:", recovered);
    console.log("Valid:", recovered === wallet.address);
    const sig = ethers.Signature.from(signature);

    const v = sig.v;
    const r = sig.r;
    const s = sig.s;

    console.log("v:", v);
    console.log("r:", r);
    console.log("s:", s);

}

main().catch(console.error);
