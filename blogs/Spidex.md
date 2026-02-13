## <center>Spidex : Decentralized AMM Protocol</center>

Spidex is a decentralized AMM protocol that is inspired from uniswap v2. which is permission lesson pools for dex , its a simple and efficient clean AMM using simple AMM math `x*y = k ` where `x` and `y` are the reserves of the pool 


the protocol users constant AMM product rule to detect price of the token based on reserve in initial supply `x*y = k`  where `k` is constant so 
![Constant product AMM](image.png)
```solidity
    x0 = initial reserve0;
    y0 = initial reserve1;
    k = x*y // some constant value 
    dx = amount of x tokens that is adding to the pool to get y;
    dy = amount of y tokens that is transfered to the user after swap
    // now if we want y0 and swaping x0 the pool becomes 
    //before 
    x0 * y0 = k;
    // after swap 
    (x0 + dx) * (y0 - dy) = k;

    // so the protocol logic ensures that K will remains constant after and before the swap
```



### Architecture of the Spidex Protocol
# Project Structure

```
src/
├── interfaces/
│   ├── IERC20.sol
│   ├── ISpidexFactory.sol
│   ├── ISpidexPair.sol
│   ├── ISpidexRouter.sol
│   └── IUniswapV2Callee.sol
│
├── libraries/
│   ├── SpidexLibrary.sol
│   └── UQ112x112.sol
│
├── SpidexERC20.sol
├── SpidexFactory.sol
├── SpidexPair.sol
└── SpidexRouter.sol
```

#### SpidexFactory.sol
Main contract of the protocol to create new pairs or to store all pairs factory contract is responsible for deploying new pair contracts 


#### SpidexERC20.sol 
customized ERC20 token contract designed for pool shares aka `liquidity` tokens for liquidity providers to represent there share in the pool


#### SpidexPair.sol
this contract implements `SpidexERC20` contract for token behavior, this contract is similar behaviour of vaults `ERC-4626` but in `ERC-4626` we will deal with only one asset as underlying token but in SpidexPair holds 2 underlying assets which is key theme of `uniswap-v2`

this contract have two underlying asserts `token0` and `token1` and reserves of the token as `reserve0` and `reserve1` . based on the amount of ratio of reserves the price depends , so it does not reply on external oracle to get price of the token 

#### SpidexRouter.sol
this contract is the uesr interactable constract to swap the tokens or adding or removing liquidity of the pool , the main reason behind to develop this contract is to interact the pool or pair contract efficiently to maximize the outcome for the liquidity providers and users



#### Creating pools
creating pools can be done by any one , they are permission less pools , so to create pools we need to interact with the factory contract 
```solidity
function createPair(address _token0, address _token1) external  returns (address _pair) {
        require(_token0 != _token1, "invalid tokens");
        (address token0, address token1) = _token0 < _token1 ? (_token0, _token1) : (_token1, _token0);
        require(token0 != address(0), "invalid tokens");
        require(pair[token0][token1] == address(0), "pair already exists");
        bytes memory bytecode = type(SpidexPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            _pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        SpidexPair(_pair).initialize(token0, token1);
        pair[token0][token1] = _pair;
        pair[token1][token0] = _pair;
        pairs.push(_pair);

        emit SpidexFactory__PairCreated(_pair, token0, token1);
    }
```

factory contract uses create2 method to deploy pools so `CREATE2` is a method to deploy contract that can be computed off-chain,

we can compute address of the pair contract with `deployer` and `tokenA` and `tokenB` addresses in off-chain or in contracts

###### In solidity
```solidity
    function computePair(address tokenA, address tokenB, address factory) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory, // deployer of the contract
                            keccak256(abi.encodePacked(token0, token1)),  // asset of the tokens
                            keccak256(type(SpidexPair).creationCode)  // bytecode of the contract
                        )
                    )
                )
            )
        );
    }
```

###### In javascript
```javascript
import { keccak256, solidityPacked, getCreate2Address } from "ethers";

// ---- edit these ----
const factory = "0xYourFactoryAddress";
const tokenA  = "0xTokenAAddress";
const tokenB  = "0xTokenBAddress";
const pairBytecode = "0x...PASTE_CREATION_BYTECODE...";
// ---------------------

function sort(a, b) {
  return a.toLowerCase() < b.toLowerCase() ? [a, b] : [b, a];
}

function computePair(tokenA, tokenB, factory, bytecode) {
  const [token0, token1] = sort(tokenA, tokenB);

  const salt = keccak256(
    solidityPacked(["address", "address"], [token0, token1])
  );

  const initCodeHash = keccak256(bytecode);

  return getCreate2Address(factory, salt, initCodeHash);
}

const pair = computePair(tokenA, tokenB, factory, pairBytecode);

console.log("Predicted Pair:", pair);

``` 
Here’s a clean, developer-style blog explanation you can use.

No fluff. Just clear logic and simple breakdown.

---

#### Understanding Add Liquidity in a Constant Product AMM

When someone adds liquidity to an AMM pool (like `x * y = k`), they are not just depositing tokens randomly.
They must deposit tokens in the **correct ratio** based on current reserves.

Let’s break down how this works in the router and pair contract.

---

##### Step One: Finding or Creating the Pair

When `_addLiquidity` is called, the router first ensures the pair exists.

```solidity
address pair = ISpidexFactory(factory).getPair(tokenA, tokenB);
if (pair == address(0)) {
    pair = ISpidexFactory(factory).createPair(tokenA, tokenB);
}
```

If the pool doesn’t exist, it creates one.

Simple.

---

##### Fetch Current Reserves

Next, we read the pool reserves.

```solidity
(uint256 _res0, uint256 _res1) = 
    SpidexLibrary.getReserves(factory, tokenA, tokenB);
```

These reserves define the price ratio:

```
price = reserveB / reserveA
```

Liquidity must follow this ratio.

---

##### First Liquidity Case (Empty Pool)

If reserves are zero:

```solidity
if (_res0 == 0 && _res1 == 0) {
    (amountA, amountB) = (desiredAmountA, desiredAmountB);
}
```

The first liquidity provider sets the initial price.

Whatever ratio they deposit becomes the starting ratio of the pool.

---

##### Existing Pool: Enforcing Correct Ratio

If reserves exist, we must maintain the ratio.

We calculate the optimal amount using:

```solidity
function quote(
    uint256 amountA,
    uint256 _reserveA,
    uint256 _reserveB
) internal pure returns (uint256 amountB) {
    require(amountA > 0, "Insufficient_amount");
    require(_reserveA > 0 && _reserveB > 0, "insufficient reserves");

    amountB = amountA * _reserveB / _reserveA;
}
```

This formula keeps:

```
amountA / amountB = reserveA / reserveB
```

So the pool price doesn't change.

---

### Router Logic

```solidity
uint256 amountBOptimal = 
    SpidexLibrary.quote(desiredAmountA, _res0, _res1);

if (amountBOptimal <= desiredAmountB) {
    require(amountBOptimal >= amountBMin);
    (amountA, amountB) = (desiredAmountA, amountBOptimal);
}
```

If the user provided too much of tokenB, we reduce it.

Otherwise we compute optimal A:

```solidity
uint256 amountAOptimal =
    SpidexLibrary.quote(desiredAmountB, _res1, _res0);

(amountA, amountB) = (amountAOptimal, desiredAmountB);
```

So liquidity is always added in correct proportion.

---

##### Minting LP Tokens

After tokens are transferred to the pair contract, `mint()` is called.

```solidity
uint256 amount0 = balance0 - reserveA;
uint256 amount1 = balance1 - reserveB;
```

These are the actual tokens added.

---

#### First Liquidity Provider

```solidity
liquidity = sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
```

Why square root?

Because liquidity tokens represent the **geometric mean** of deposited tokens.

This ensures fairness across price ranges.

We subtract `MINIMUM_LIQUIDITY` to permanently lock a tiny amount and prevent division issues.

---

#### Later Liquidity Providers

```solidity
liquidity = min(
    amount0 * totalSupply / reserve0,
    amount1 * totalSupply / reserve1
);
```

This ensures LP tokens are minted proportional to:

```
(liquidity added / total pool liquidity)
```

If someone provides too much of one side, the smaller proportional side determines minting.

---

##### Updating Reserves

After minting:

```solidity
_update(balance0, balance1, reserveA, reserveB);
```

The reserves are updated.

Now the pool reflects the new liquidity.

---

#### What This Guarantees

* Price doesn’t change when adding liquidity
* LP tokens represent proportional ownership
* First provider sets initial price
* Future providers must respect pool ratio

---

#### Mental Model

Think of it like adding water to two connected tanks.

If tank A has 100L and tank B has 200L,
you must add water in the same 1:2 ratio.

Otherwise, price shifts — and that’s a swap, not liquidity.

---

#### Final Summary

Add liquidity does three important things:

1. Enforces reserve ratio
2. Calculates optimal token amounts
3. Mints proportional LP shares


---

#### Remove Liquidity Functionality in Constant Product AMM

Removing liquidity is the reverse of adding liquidity.
Instead of depositing tokens and minting LP tokens, the user returns LP tokens and receives their proportional share of the pool reserves.

The router coordinates the process, and the pair contract calculates and transfers the correct token amounts.

---

#### removeLiquidity – Router Entry Point

```solidity
function removeLiquidity(
    address tokenA,
    address tokenB,
    uint256 liquidity,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline
)
```

This function performs four main steps.

---

##### Step 1: Compute Pair Address

```solidity
address pair = 
    SpidexLibrary.computePair(tokenA, tokenB, factory);
```

The router deterministically calculates the pair address using CREATE2 logic.

No external lookup required.

---

##### Step 2: Transfer LP Tokens to Pair

```solidity
_safeTransferFrom(pair, msg.sender, pair, liquidity);
```

The user sends LP tokens to the pair contract.

Why?

Because the pair contract burns LP tokens from its own balance during `burn()`.

---

##### Step 3: Call burn()

```solidity
(uint256 amount0, uint256 amount1) = 
    ISpidexPair(pair).burn(to);
```

Now execution moves into the pair contract.

This is where the proportional share is calculated.

---

##### Step 4: Reorder Tokens

Because reserves are stored as token0 and token1 internally, but the user passed tokenA and tokenB, the router adjusts ordering:

```solidity
(address token0,) = 
    SpidexLibrary.sortTokens(tokenA, tokenB);

(amountA, amountB) = 
    token0 == tokenA 
        ? (amount0, amount1) 
        : (amount1, amount0);
```

This ensures the user receives tokens in the same order they requested.

---

##### Step 5: Slippage Protection

```solidity
require(amountAMin <= amountA);
require(amountBMin <= amountB);
```

If the returned amounts are lower than the user’s minimum expectations, the transaction reverts.

This protects against reserve changes between submission and execution.

---

#### burn – Core Liquidity Removal Logic

```solidity
function burn(address to)
```

This function calculates how much of each token the LP is entitled to.

---

##### Step 1: Read Current Reserves

```solidity
(uint112 _reserve0, uint112 _reserve1,) = getReserves();
```

These represent the last stored reserves.

---

##### Step 2: Read Current Token Balances

```solidity
uint256 Balance0 = IERC20(_token0).balanceOf(address(this));
uint256 Balance1 = IERC20(_token1).balanceOf(address(this));
```

Balances may include fees accumulated from swaps.

This is important because LPs are entitled to swap fees as well.

---

##### Step 3: Determine LP Tokens Being Burned

```solidity
uint256 liquidity = balanceOf[address(this)];
uint256 _totalSupply = totalSupply;
```

Since LP tokens were transferred to the pair, the pair contract now holds them.

---

##### Step 4: Calculate Proportional Share

```solidity
amount0 = liquidity * Balance0 / _totalSupply;
amount1 = liquidity * Balance1 / _totalSupply;
```

This formula ensures:

```
User share = (LP tokens burned / total LP supply)
```

multiplied by total pool balances.

This means liquidity providers own a proportional percentage of the entire pool, including earned fees.

---

##### Step 5: Validate Non-Zero Output

```solidity
require(amount0 > 0 && amount1 > 0);
```

Prevents dust or invalid burns.

---

##### Step 6: Burn LP Tokens

```solidity
_burn(address(this), liquidity);
```

LP tokens are permanently destroyed.

Total supply decreases.

---

##### Step 7: Transfer Tokens to User

```solidity
_safeTransfer(_token0, to, amount0);
_safeTransfer(_token1, to, amount1);
```

The user receives their underlying assets.

---

##### Step 8: Update Reserves

```solidity
_update(Balance0, Balance1, _reserve0, _reserve1);
```

Reserves are updated to reflect reduced balances.

Event is emitted:

```solidity
emit SpidexPair__Burn(to, liquidity);
```

---

#### What This Guarantees

• LPs always receive proportional ownership
• Swap fees are included in withdrawal
• Total supply decreases correctly
• Reserves remain consistent
• No invariant violation occurs

---

#### Conceptual Model

If the pool has:

```
100 ETH
20000 USDC
Total LP Supply = 1000
```

If a user burns 100 LP tokens:

```
100 / 1000 = 10% share
```

They receive:

```
10 ETH
2000 USDC
```

No pricing formula is involved here.

This is purely ownership-based distribution.

---



#### Swap Functionality in Constant Product AMM

Your swap flow follows the standard constant product model where the invariant `x * y = k` must always hold after every trade. The router coordinates the swap, and the pair contract enforces the invariant and fee logic.

Let’s go step by step.

---

#### swapExactTokensForTokens – Entry Point

```solidity
function swapExactTokensForTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] memory path,
    address to,
    uint256 deadline
)
```

This is the public function users call.

It performs three major tasks:

##### 1. Calculate Expected Output

```solidity
amounts = SpidexLibrary.getAmountsOut(factory, amountIn, path);
```

`getAmountsOut` walks through the swap path and calculates how much output each pair will return based on reserves and the constant product formula.

For a single hop swap:

```
amountOut = (amountIn * 997 * reserveOut) 
            / (reserveIn * 1000 + amountIn * 997)
```

The 997 / 1000 represents the 0.3% fee.

For multi-hop swaps, this calculation repeats for each pair in the path.

---

##### 2. Slippage Protection

```solidity
require(
    amounts[path.length - 1] >= amountOutMin,
    SpidexRouter__InsufficientAmount()
);
```

This protects users from price movement between transaction submission and execution.

If the final output is less than `amountOutMin`, the transaction reverts.

---

##### 3. Transfer Input Tokens to First Pair

```solidity
_safeTransferFrom(
    path[0],
    msg.sender,
    SpidexLibrary.computePair(path[0], path[1], factory),
    amounts[0]
);
```

The router sends the input tokens directly to the first pair contract.

After that, it calls:

```solidity
_swap(amounts, path, to);
```

---

#### _swap – Multi-Hop Execution

```solidity
function _swap(uint256[] memory amounts, address[] memory path, address to)
```

This function loops through the path and executes swaps pair by pair.

For each step:

```solidity
(address inputToken, address outputToken) = 
    (path[i], path[i + 1]);
```

It determines the direction of the swap using token sorting:

```solidity
(address token0,) = 
    SpidexLibrary.sortTokens(inputToken, outputToken);
```

Then it determines which side of the pair should output tokens:

```solidity
(uint256 amount0Out, uint256 amount1Out) =
    token0 == inputToken
        ? (0, amountOut)
        : (amountOut, 0);
```

If swapping token0 → token1, then `amount1Out` is set.
If swapping token1 → token0, then `amount0Out` is set.

For multi-hop swaps, the output of one pair becomes the input of the next pair:

```solidity
address _to =
    i < path.length - 2
        ? nextPair
        : finalReceiver;
```

This chains swaps without intermediate transfers through the router.

Finally, it calls:

```solidity
ISpidexPair(pair).swap(
    amount0Out,
    amount1Out,
    _to,
    new bytes(0)
);
```

Now execution moves into the pair contract.

---

#### swap – Core AMM Logic in Pair

```solidity
function swap(
    uint256 amount0Out,
    uint256 amount1Out,
    address to,
    bytes memory data
)
```

This is where the invariant is enforced.

---

##### Step 1: Basic Validations

```solidity
require(amount0Out > 0 || amount1Out > 0);
```

At least one token must be requested.

```solidity
require(
    amount0Out <= _reserve0 &&
    amount1Out <= _reserve1
);
```

The pool cannot send more tokens than it holds.

---

##### Step 2: Transfer Output Tokens

```solidity
if (amount0Out > 0)
    _safeTransfer(_token0, to, amount0Out);

if (amount1Out > 0)
    _safeTransfer(_token1, to, amount1Out);
```

Tokens are optimistically transferred before verifying the invariant.

If `data` is present, flash swap logic is triggered:

```solidity
IUniswapV2Callee(to).uniswapV2Call(...)
```

---

##### Step 3: Calculate Actual Input Amount

After transfers, the contract checks its new balances:

```solidity
balance0 = IERC20(_token0).balanceOf(address(this));
balance1 = IERC20(_token1).balanceOf(address(this));
```

It calculates how much input was actually received:

```solidity
uint256 amount0In =
    balance0 > _reserve0 - amount0Out
        ? balance0 - (_reserve0 - amount0Out)
        : 0;
```

This detects how much was sent in by comparing balances before and after.

At least one input must exist:

```solidity
require(amount0In > 0 || amount1In > 0);
```

---

##### Step 4: Enforce Constant Product with Fee

Fee logic is applied here:

```solidity
uint256 balance0Adjusted =
    (balance0 * 1000) - (amount0In * 3);

uint256 balance1Adjusted =
    (balance1 * 1000) - (amount1In * 3);
```

Since fee is 0.3%, 3 is subtracted from 1000.

Then invariant is checked:

```solidity
require(
    balance0Adjusted * balance1Adjusted >=
    reserve0 * reserve1 * (1000 ** 2)
);
```

This ensures:

```
(x_new * y_new) >= (x_old * y_old)
```

after accounting for fees.

If not satisfied, transaction reverts.

---

##### Step 5: Update Reserves

```solidity
_update(balance0, balance1, _reserve0, _reserve1);
```

Reserves are updated to new balances.

Event is emitted:

```solidity
emit SpidexPair__Swap(...);
```

---

#### What This Guarantees

• The constant product invariant is preserved
• 0.3% fee is collected on input amount
• Multi-hop swaps are supported
• Flash swaps are possible
• No price manipulation without cost

---

#### Conceptual Flow

1. Router calculates output amounts
2. Router sends input tokens to first pair
3. Each pair sends output tokens forward
4. Pair verifies invariant after fee
5. Reserves update

All price movement is determined purely by reserve ratios and the invariant check inside the pair contract.

This design keeps router logic simple and makes the pair contract the single source of truth for pricing and safety.
