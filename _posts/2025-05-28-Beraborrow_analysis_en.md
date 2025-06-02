---
title: "Berachain protocol analysis - Beraborrow"
date: 2025-05-28 T09:23:02+09:00
authors:
  - wiimdy
description: "Berachain protocol analysis - Beraborrow"
tags:
  - Web3, Berachain
categories:
  - Web3
image:
  path: /assets/img/upside_img/beraborrow_thumbnail.png
---

## What is Beraborrow?

Beraborrow unlocks instant liquidity against Berachain assets through the first PoL powered stablecoin, Nectar ($NECT). Built with simplicity and flexibility at its core, Beraborrow is designed to maximise opportunities for users without forcing them to sacrifice yield.

The code is quite long, so I've included GitHub links . It would be beneficial to refer to them while reading.

[https://github.com/wiimdy/beraborrow](https://github.com/wiimdy/beraborrow)

## Logic Summary

### Loan

#### open den position (Execute Loan)

1. [`collVaultRouter.openDenVault`](https://github.com/wiimdy/beraborrow/blob/1620db2d87556bdab43ce300d24dcb0c82c8e56d/src/periphery/CollVaultRouter.sol#L67-L109)

   Deposits into the vault, records it in the den, and mints Nectar to send.

2. [`collVaultRouter.adjustDenVault`](https://github.com/wiimdy/beraborrow/blob/1620db2d87556bdab43ce300d24dcb0c82c8e56d/src/periphery/CollVaultRouter.sol#L111-L168)

   **A function to adjust the collateral/debt of an already open (existing) Den Vault (deposit, withdraw, borrow, repay).**

3. [`collVaultRouter.closeDenVault`](https://github.com/wiimdy/beraborrow/blob/1620db2d87556bdab43ce300d24dcb0c82c8e56d/src/periphery/CollVaultRouter.sol#L170-L200)

   **A function to close a Den Vault's loan.**

4. [`collVaultRouter.redeemCollateral`](https://github.com/wiimdy/beraborrow/blob/1620db2d87556bdab43ce300d24dcb0c82c8e56d/src/periphery/CollVaultRouter.sol#L202-L238)

   A function to withdraw collateral (share) after debt repayment (Redemption).

### **Collateral Vault**

- A vault that receives rewards by putting collateral into Infrared.

  [CompoundingInfraredCOllateralVault](https://github.com/wiimdy/beraborrow/blob/main/test/deploy/CompoundingInfraredCollateralVault.sol)
  [InfraredCOllateralVault](https://github.com/wiimdy/beraborrow/blob/main/src/core/vaults/InfraredCollateralVault.sol)

#### deposit

`deposit → _stake → infraredVault.stake`

#### **withdraw**

- **Input:** assets (quantity of assets to withdraw)
- **Action:**
  - The user requests, "I want to receive this much asset (Underlying Asset)!"
  - The vault calculates the number of shares needed to withdraw this asset and burns that many shares.
  - Share fees are applied if any.
- **Summary:**
  - "I want to receive this much asset" → "Then I'll burn this much of your shares."

#### **redeem**

- **Input:** shares (quantity of vault shares to burn)
- **Action:**
  - The user requests, "I'll burn this many shares!"
  - The vault burns these shares and calculates and returns the corresponding underlying asset.
  - Share fees are applied if any.
- **Summary:**
  - "I'll burn this many shares" → "Then I'll give you the corresponding asset."

### Flashloan

```javascript
function flashLoan(
    IERC3156FlashBorrower receiver,
    address token,
    uint256 amount,
    bytes calldata data
) external returns (bool) {
    uint256 fee = flashFee(token, amount);
    require(amount <= maxFlashLoan(token), "ERC20FlashMint: amount exceeds maxFlashLoan");

    _mint(address(receiver), amount);
    require(
        receiver.onFlashLoan(msg.sender, token, amount, fee, data) == _RETURN_VALUE,
        "ERC20FlashMint: invalid return value"
    );
    _spendAllowance(address(receiver), address(this), amount + fee);
    _burn(address(receiver), amount);
    _transfer(address(receiver), _metaBeraborrowCore.feeReceiver(), fee);
    return true;
}
```

![image.png](/assets/img/upside_img/beraborrow_flashloan.png)

- Infinite flashloans are possible by only paying a fee, so potential issues arising from this should be considered.

## NECT MINT

### What is NECT?

A debt token received by issuing collateral.

But it can be minted?!!?

[Nect mint, redeem Contract](https://github.com/wiimdy/beraborrow/blob/e4fa703d53da07ae7363a87e17abcadd1738689f/src/core/PermissionlessPSM.sol#L82-L120)

#### deposit

- NECT can be minted by depositing whitelisted stables.
  - stables: HONEY, USDC.E, USD.e
- Mint cap is 15,000,000 BERA.

#### mint

- Input the nectAmount to receive, it takes the stable amount and mints.

#### withdraw

- Input the stableAmount to withdraw, give NECT and receive stable.

#### redeem

- Input the nectAmount to redeem and receive stable.

## Nect peg

### Pegging Method

#### 1. **Redemptions**

[Beraborrow docs](https://beraborrow.gitbook.io/docs/nect-stablecoin/redemptions)

Simply put, the theory is that the peg to $1 is maintained by users swapping their NECT with collateral.

- If NECT is below $1:

  - If a user holds NECT, the system exchanges it for collateral at $1.
    Therefore, it incentivizes purchasing NECT from the market and exchanging it for HONEY or collateral, thus raising the price.

  [Beraborrow App redeem](https://app.beraborrow.com/redeem/HONEY)

  [Redeem tx log](https://app.blocksec.com/explorer/tx/berachain/0x90e68c30751bb4e49e6b833650dc9fac7a81a25abb965e83413267755d2bad92?line=0)

        This site exchanges NECT for HONEY. If NECT is below $1, one can buy it cheaply on a DEX and exchange it for HONEY to make a profit.

        Alternatively, one can close their existing loan position and exchange NECT for collateral.

- If NECT is above $1:

  - Users deposit collateral, mint NECT, and exchange it on the market. The price is lowered through arbitrage profits.

    Reference code: [Logic for minting NECT with stable coin](https://github.com/wiimdy/beraborrow/blob/e4fa703d53da07ae7363a87e17abcadd1738689f/src/core/PermissionlessPSM.sol#L142-L160)

    Actual arbitrage bot contract:

    [arbitrage contract log](https://berascan.com/address/0x9daca2b7df5c12de905934b492d745da085d8eba#code)
    ![image](/assets/img/upside_img/arbitrage_bot.png)

## Liquity Mechanism Comparison Analysis

[modern-stablecoins-how-they-re-made-liquity-v2](https://mixbytes.io/blog/modern-stablecoins-how-they-re-made-liquity-v2#rec869248566)

It seems to have a similar logic to Liquity V2.

![image.png](/assets/img/upside_img/liquityV2.png){: width="400" height="200"}

![image.png](/assets/img/upside_img/beraborrow_use.png){: width="600" height="400"}

Differences:

- Liquity can set interest rates.
- In Beraborrow, DenManager sets the interest rate on collateral.

Similarities:

- The lower Liquity's interest rate, the more likely redemptions occur.
- Naturally, the more borrowed against collateral, the higher the chance of liquidation.
- In Beraborrow's case, through redeemCollateral, positions with lower ICR are repaid first, potentially losing collateral.

## Recovery Mode

[Beraborrow Docs: Recovery-mode](https://beraborrow.gitbook.io/docs/borrowing/recovery-mode)

This occurs when the most important collateral ratio in a lending protocol drops below 150%.

If the collateral ratio of all loans falls below 150%, the protocol suspends lending functions to prevent this Global Total Collateral Ratio (**GTCR**) from falling further.

In Recovery Mode, NECT can only be minted by increasing the collateral ratio of an existing Den or by opening a Den with a collateral ratio of 150% or more.

### Key Changes in Recovery Mode

- Stricter liquidation criteria:
  - Normally, only loan positions with a collateral ratio below 110% are liquidated.
  - In Recovery Mode, all positions (Dens) with a ratio below GTCR (i.e., below 150%) become subject to liquidation.
  - Therefore, positions between 110-150% can also be liquidated.
- Lending restrictions:
  - All borrower transactions that would further lower the GTCR (e.g., additional borrowing, collateral withdrawal) are blocked.
  - To mint new $NECT, one must either increase the collateral ratio of an existing position or open a new position with a collateral ratio of at least 150%.
  - Adjustments that lower the collateral ratio of an existing position are only allowed if the resulting GTCR remains at or above 150%.
- Fee changes:
  - The new stablecoin minting fee is lowered to 0% to encourage adding more collateral and taking out healthy loans.
  - Redemption fees remain unchanged.

### Conclusion

Recovery by reducing new loans and clearing low-collateral positions through liquidation.

## Price feed

So, how are the prices of various assets used as collateral obtained?

[Price feed.sol](https://github.com/wiimdy/beraborrow/blob/main/src/core/PriceFeed.sol)

### fetchPrice

```javascript
function fetchPrice(address _token) public view returns (uint256) {
    if (feedType[_token].isCollVault) {
        return IInfraredCollateralVault(_token).fetchPrice();
    }

    ISpotOracle spotOracle = feedType[_token].spotOracle;
    if (address(spotOracle) != address(0)) {
        return spotOracle.fetchPrice();
    }

    OracleRecord memory oracle = oracleRecords[_token];

    require(address(oracle.chainLinkOracle) != address(0), "PriceFeed: token not supported");

    (FeedResponse memory currResponse, FeedResponse memory prevResponse) = _fetchFeedResponses(
        oracle.chainLinkOracle
    );

    return _processFeedResponses(_token, oracle, currResponse, prevResponse);
}
```

1. Check if the token is a vault type.

   If the token address is registered as an InfraredCollateralVault (collateral vault)
   → Call `IInfraredCollateralVault(token).fetchPrice()`
   _For tokens like https://berascan.com/address/0x9158d1b0c9cc4ec7640eaef0522f710dadee9a1b, calculate using the function below (getPrice here also uses this Price feed contract)_

   ```javascript
       function fetchPrice() public view virtual returns (uint) {
           uint _totalSupply = totalSupply();
           if (_totalSupply == 0) return 0;
           return (totalAssets() * 10 ** _decimalsOffset()).mulDiv(getPrice(asset()), _totalSupply);
       }
   ```

2. Check if the price needs to be fetched from a spot oracle.

   Mostly LPs of external pools used by Beraborrow. Currently, Kodiak's **WBTC-HONEY, WETH-HONEY, WETH-WBTC** exist.

3. Fetch the price from Chainlink.

   Other assets traded on the market are fetched from Chainlink.

### Summary

- NECT - chainlink oracle
- WBERA - chainlink
- WBTC - chainlink
- pumpBTC - chainlink
- BB.WBERA - whitelistvault
- BB.PUMPBTC - whitelistVault
- WETH - chainlink
- solveBTC - chainlink
- solveBTC BBN - chainlink
- BB.SOLVBTC.BBN - whitelistvault
- uniBTC - chainlink
- BB.uniBTC - whitelistvault
- beraETH - chainlink
- BB.beraETH - whitelistvault
- stakestone - chainlink
- BB.STONEETH - whitelistvault
- WETH - chainlink

## Reference

- [Beraborrow Docs](https://beraborrow.gitbook.io/docs)
- [Beraborrow Onchain code](https://github.com/wiimdy/beraborrow)
