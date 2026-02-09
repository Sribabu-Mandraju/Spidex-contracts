
# EIP-712 Permit Signing Explained (ERC20 / Uniswap-style)

In this article, we will walk through a **real EIP-712 Permit signing flow** using `ethers.js`.
The goal is to understand **how an ERC20 permit signature is created off-chain**, verified, and split into `v`, `r`, `s` so it can later be submitted on-chain.

This pattern is used by protocols like **Uniswap**, **Aave**, and many modern DeFi applications to enable **gasless approvals**.

---

## What is Permit?

`permit` allows a token holder to approve token spending **using a signature instead of a transaction**.

Key properties:

* Signing happens **off-chain**
* No gas is paid by the signer
* Anyone can submit the signature on-chain
* Replay attacks are prevented using a nonce

---

## Prerequisites

* Node.js 18+
* `ethers` v6
* An ERC20 token that supports `permit`
* Environment variables for sensitive values

---

## Environment Variables

Create a `.env` file:

```env
PRIVATE_KEY=0x...
OWNER=0x...
SPENDER=0x...
CONTRACT=0x...
RPC_URL=https://...
```

---

## Complete Signing Script

This script:

* Reads the nonce from the token contract
* Builds the EIP-712 domain
* Signs a Permit message
* Verifies the signature
* Splits the signature into `v`, `r`, `s`

```js
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
```

---

## Step-by-Step Explanation

### 1. Reading the Nonce

```js
const nonce = await token.nonces(OWNER);
```

The nonce:

* Prevents replay attacks
* Ensures each permit can be used only once
* Must always come from the contract

Hardcoding the nonce will break the signature.

---

### 2. EIP-712 Domain

```js
const domain = {
  name: "Spidex-ERC20",
  version: "1",
  chainId: CHAIN_ID,
  verifyingContract: TOKEN_ADDRESS
};
```

The domain binds the signature to:

* A specific token contract
* A specific chain

Without this, signatures could be reused across contracts or networks.

---

### 3. Permit Type Definition

```js
const types = {
  Permit: [
    { name: "owner", type: "address" },
    { name: "spender", type: "address" },
    { name: "value", type: "uint256" },
    { name: "nonce", type: "uint256" },
    { name: "deadline", type: "uint256" }
  ]
};
```

This must **exactly match** the Solidity `PERMIT_TYPEHASH`.

Any mismatch will result in `INVALID_SIGNATURE`.

---

### 4. Message Being Signed

```js
const message = {
  owner: OWNER,
  spender: SPENDER,
  value: ethers.parseEther("0.5"),
  nonce,
  deadline
};
```

This represents the user’s intent:

> “I allow `SPENDER` to spend `0.5` tokens once, before the deadline.”

---

### 5. Signing Off-Chain

```js
const signature = await wallet.signTypedData(
  domain,
  types,
  message
);
```

* No gas is spent
* The private key never leaves the user
* This is safe to do in frontend or backend environments

---

### 6. Verifying the Signature

```js
const recovered = ethers.verifyTypedData(
  domain,
  types,
  message,
  signature
);
```

This confirms:

* The signature was created by `OWNER`
* The contract will accept it

---

### 7. Splitting Signature into `v`, `r`, `s`

```js
const sig = ethers.Signature.from(signature);

const v = sig.v;
const r = sig.r;
const s = sig.s;
```

Solidity does not accept a full signature string.
It requires these three components for `ecrecover`.

---

## How This Is Used On-Chain

Later, anyone can submit:

```solidity
function permit(address owner,address spender,uint256 amount,uint256 nonce,uint256 deadline,uint8 v, bytes32 r, bytes32 s) external {
        require(deadline >= block.timestamp,"invalid signature");
        bytes32 digest = keccak256(
            abi.encodePacked(
                 '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encodePacked(PERMIT_TYPEHASH,owner,spender,amount,nonce,deadline))
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner,"invalid signature");
        _approve(owner,spender,amount);
    }
```

* The caller pays gas
* The signer does not
* The nonce is consumed
* The approval is applied

---

## Key Takeaways

* Permit enables gasless approvals
* Nonce is mandatory and must come from the contract
* Domain separator prevents cross-contract replay
* Signatures are one-time use
* `v`, `r`, `s` are required for Solidity verification

---

## Final Thought

Understanding this flow means you understand the **foundation of modern DeFi UX**.
Most protocols today rely on this exact pattern for better user experience and security.
