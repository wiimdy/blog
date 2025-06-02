---
title: "Berachain protocol analysis - Infrared"
date: 2025-05-22 T09:23:02+09:00
authors:
  - wiimdy
description: "Berachain protocol analysis - Infrared"
tags:
  - Web3, Berachain
categories:
  - Web3
image:
  path: /assets/img/upside_img/infrared_thumbnail.jpeg
---

The code is quite long, so I've included GitHub links in the Reference section. It would be beneficial to refer to them while reading.

[https://github.com/wiimdy/infrared\_](https://github.com/wiimdy/infrared_)

## What's Infrared

Infrared is focused on building infrastructure around the [Proof of Liquidity (PoL)](https://infrared.finance/docs/berachain#what-is-proof-of-liquidity) mechanism pioneered by [Berachain](https://infrared.finance/docs/berachain). The protocol aims to maximize value capture by providing easy-to-use liquid staking solutions for [BGT](https://infrared.finance/docs/tokens#bgt) and [BERA](https://infrared.finance/docs/tokens#bera), node infrastructure, and vaults. Through building solutions around [Proof of Liquidity (PoL)](https://infrared.finance/docs/berachain#what-is-proof-of-liquidity), Infrared is dedicated to enhancing the user experience and driving the growth of the [Berachain](https://infrared.finance/docs/berachain) ecosystem.

## Why use Infrared?

Infrared simplifies participation in [Berachain](https://infrared.finance/docs/berachain)'s [Proof of Liquidity (PoL)](https://infrared.finance/docs/berachain#what-is-proof-of-liquidity), helping users maximize their [BGT](https://infrared.finance/docs/tokens#bgt) and [BERA](https://infrared.finance/docs/tokens#bera) rewards through easy-to-use products like [iBGT](https://infrared.finance/docs/tokens#ibgt) and [iBERA](https://infrared.finance/docs/tokens#ibera). Infrared's products also enable new flywheels throughout the [Berachain](https://infrared.finance/docs/berachain) ecosystem that wouldn't otherwise be possible by making [BGT](https://infrared.finance/docs/tokens#bgt) and staked [BERA](https://infrared.finance/docs/tokens#bera) composable.

## PoL Related Function Summary

## IBERA ←→ BeaconDeposit

How is deposit executed when a user mints IBERA?

### asset: BERA, IBERA

```javascript
function mint(address receiver) public payable returns (uint256 shares) {
    // @dev make sure to compound yield earned from EL rewards first to avoid accounting errors.
    compound();

    // cache prior since updated in _deposit call
    uint256 d = deposits;
    uint256 ts = totalSupply();

    // deposit bera request
    uint256 amount = msg.value;
    _deposit(amount);
    ...
    }
```

1. User executes `InfraredBERA.mint`.
2. BERA is queued to `InfraredBERADepositor.queue` (actual deposit is processed by an administrator, separating user and administrator functions).
3. IBERA is minted proportionally to `(totalSupply * amount) / deposits`.
4. Keeper executes `InfraredBERADepositor.execute` to deposit to BeaconDeposit with the corresponding Pubkey.

## Infrared ←→ BaseBGT

How to use the baseBGT given by BlockrewardController?

```javascript
function harvestBase(
    address ibgt,
    address bgt,
    address ibera
) external returns (uint256 bgtAmt) {
    // Since BGT balance has accrued to this contract, we check for what we've already accounted for
    uint256 minted = IInfraredBGT(ibgt).totalSupply();

    // The balance of BGT in the contract is the rewards accumilated from base rewards since the last harvest
    // Since is paid out every block our validators propose (have a `Distributor::distibuteFor()` call)
    uint256 balance = IBerachainBGT(bgt).balanceOf(address(this));
    if (balance == 0) return 0;

    // @dev the amount that will be minted is the difference between the balance accrued since the last harvestVault and the current balance in the contract.
    // This difference should keep getting bigger as the contract accumilates more bgt from `Distributor::distibuteFor()` calls.
    bgtAmt = balance - minted;

    // @dev ensure that the `BGT::redeem` call won't revert if there is no BERA backing it.
    // This is not unlikley since https://github.com/berachain/beacon-kit slots/blocks are not consistent there are times
    // where the BGT rewards are not backed by BERA, in this case the BGT rewards are not redeemable.
    // https://github.com/berachain/contracts-monorepo/blob/a28404635b5654b4de0627d9c0d1d8fced7b4339/src/pol/BGT.sol#L363
    if (bgtAmt > bgt.balance) return 0;

    // catch try can be used for additional security
    try IBerachainBGT(bgt).redeem(IInfraredBERA(ibera).receivor(), bgtAmt) {
        return bgtAmt;
    } catch {
        return 0;
    }
}
```

1. BGT in Infrared is rewardBGT + baseBGT. Of this, IBGT is minted for the amount of rewardBGT received, so baseBGT = totalBGT - total ibgt. (Where does it go from where?)
2. Executing `harvestBase` redeems BaseBGT for BERA.
3. This BERA is sent to IBERAFeeReceivor.

<aside> 💡

Conclusion: BaseBGT is redeemed for BERA and sent to IBERAFeeReceivor.

</aside>

## InfraredVault ←→ Reward Vault

How is the Reward BGT distributed by Reward Vault to users?

```javascript
function harvestVault(
    RewardsStorage storage $,
    IInfraredVault vault,
    address bgt,
    address ibgt,
    address voter,
    address ir,
    uint256 rewardsDuration
) external returns (uint256 bgtAmt) {
    // Ensure the vault is valid
    if (vault == IInfraredVault(address(0))) {
        revert Errors.VaultNotSupported();
    }

    // Record the BGT balance before claiming rewards since there could be base rewards that are in the balance.
    uint256 balanceBefore = IBerachainBGT(bgt).balanceOf(address(this));

    // Get the underlying Berachain RewardVault and claim the BGT rewards.
    IBerachainRewardsVault rewardsVault = vault.rewardsVault();
    rewardsVault.getReward(address(vault), address(this));

    // Calculate the amount of BGT rewards received
    bgtAmt = IBerachainBGT(bgt).balanceOf(address(this)) - balanceBefore;

    // If no BGT rewards were received, exit early
    if (bgtAmt == 0) return bgtAmt;

    // Mint InfraredBGT tokens equivalent to the BGT rewards
    IInfraredBGT(ibgt).mint(address(this), bgtAmt);

    // Calculate the voter and protocol fees to charge on the rewards
    (
        uint256 _amt,
        uint256 _amtVoter,
        uint256 _amtProtocol
    ) = chargedFeesOnRewards(
            bgtAmt,
            $.fees[uint256(ConfigTypes.FeeType.HarvestVaultFeeRate)],
            $.fees[uint256(ConfigTypes.FeeType.HarvestVaultProtocolRate)]
        );

    // Distribute the fees on the rewards.
    _distributeFeesOnRewards(
        $.protocolFeeAmounts,
        voter,
        ibgt,
        _amtVoter,
        _amtProtocol
    );

    // Send the post-fee rewards to the vault
    if (_amt > 0) {
        ERC20(ibgt).safeApprove(address(vault), _amt);
        vault.notifyRewardAmount(ibgt, _amt);
    }

    // If IR token is set and mint rate is greater than zero, handle IR rewards.
    uint256 mintRate = $.irMintRate;
    if (ir != address(0) && mintRate > 0) {
        // Calculate the amount of IR tokens to mint = BGT rewards * mint rate
        uint256 irAmt = (bgtAmt * mintRate) / UNIT_DENOMINATOR;
        if (!IInfraredGovernanceToken(ir).paused()) {
            IInfraredGovernanceToken(ir).mint(address(this), irAmt);
            {
                // Check if IR is already a reward token in the vault
                (, uint256 IRRewardsDuration, , , , , ) = vault.rewardData(
                    ir
                );
                if (IRRewardsDuration == 0) {
                    // Add IR as a reward token if not already added
                    vault.addReward(ir, rewardsDuration);
                }
            }

            // Send the remaining IR rewards to the vault
            if (irAmt > 0) {
                ERC20(ir).safeApprove(address(vault), irAmt);
                vault.notifyRewardAmount(ir, irAmt);
            }
        } else {
            // @dev Misconfigured Role or Hit Supply Cap
            emit ErrorMisconfiguredIRMinting(irAmt);
        }
    }
}
```

### asset: lp token, reward bgt

### LP stake

1. User deposits LP by executing `InfraredVault.stake`.
2. This is `approve`d by InfraredVault and then `stake` in RewardVault.

### Receiving LP stake rewards

1. User executes `onReward` via `InfraredVault.getReward`.
2. `Infrared.harvestVault` → `RewardLib.harvestVault` is executed.
   1. BGT is received as a reward by Infrared through `rewardsVault.getReward`.
   2. IBGT is minted for the amount of BGT received and `addReward`ed to InfraredVault.
3. Returns to `MultiReward.getRewardForUser` and provides IBGT만큼 stored in rewards[\_user][_rewardsToken].

### LP withdraw

1. User requests LP withdrawal via `InfraredVault.withdraw`.
2. LP is withdrawn with `rewardVault.withdraw` and then `transfer`red to the user.

<aside> 💡

Conclusion: Infrared holds the reward BGT received from the lp token deposited by the user, mints IBGT, and puts it into each vault. IBGT is sent to the user according to the calculation formula.

</aside>

## Infrared ←→ BGTIncentiveDistributor…

How is the incentive taken by the operator (Infrared) used?

### asset: incentive token, WBERA, BERA

1. Keeper receives the incentive given by rewardVault via `Infrared.claimBGTIncentives`.
2. Anyone can execute `Infrared.harvestBribes` to move the incentive in Infrared to BribeCollector (the token must be whitelisted at this time).
3. Anyone can exchange WBERA and incentive token via `BribeCollector.claimFees`.
4. Infrared reclaims the WBERA in BribeCollector via `collectBribes` and distributes it to BERAfeeReceivor and IBGT Vault via `collectBribesInWBERA`.

<aside> 💡

Conclusion: Protocol incentive is collected, exchanged for WBERA, and the received WBERA is distributed to BERAfeeReceivor and IBGT Vault. (Refer to `RewardsLib.collectBribesInWBERA`)

</aside>

### Bonus: What does IBERAfeeReceivor do? Why does it keep receiving BERA?

- Source of BERA: Protocol incentive, base BGT, i.e., most of the rewards received by the operator.
- `sweep()` is executed frequently externally. This consolidates the accumulated BERA, setting aside 10% of the total as operator rewards and putting the rest into `_deposit()`.
- Accumulated operator rewards are distributed via `RewardLib.harvestOperatorRewards`.

## Infrared ←→ Validator Operator

1. The operator selected by the validator uses Infrared's contract. [https://berascan.com/address/0xb71b3daea39012fb0f2b14d2a9c86da9292fc126](https://berascan.com/address/0xb71b3daea39012fb0f2b14d2a9c86da9292fc126) a41 is the operator.
2. Various interactions here, such as chef settings, boosts, etc.

## Lido diff

Infrared, broadly speaking, is a Liquid Staking solution, so I investigated its differences from Lido, the most famous one.

### Lido stake logic

[https://app.blocksec.com/explorer/tx/eth/0x21fae646ba22c004e530ff58c3b2a1633a895b009611ea73cee50839896ca2d0](https://app.blocksec.com/explorer/tx/eth/0x21fae646ba22c004e530ff58c3b2a1633a895b009611ea73cee50839896ca2d0)

1. Lido.submit()
   [https://github.com/lidofinance/core/blob/d186530e74e07569295ac5de399389e5438bf567/contracts/0.4.24/Lido.sol#L917-L947](https://github.com/lidofinance/core/blob/d186530e74e07569295ac5de399389e5438bf567/contracts/0.4.24/Lido.sol#L917-L947)

   When a user sends Ether via submit, it's placed in a buffer, and deposits are made in multiples of 32 ETH. Therefore, stETH is minted to the user immediately.

2. Lido.deposit()
   [https://github.com/lidofinance/core/blob/d186530e74e07569295ac5de399389e5438bf567/contracts/0.4.24/Lido.sol#L694-L723](https://github.com/lidofinance/core/blob/d186530e74e07569295ac5de399389e5438bf567/contracts/0.4.24/Lido.sol#L694-L723)

   Once a certain amount of ETH is accumulated, it checks if it's possible and then forwards it to the stakingRouter.

3. StakingLouter.deposit()
   [https://github.com/lidofinance/core/blob/d186530e74e07569295ac5de399389e5438bf567/contracts/0.8.9/StakingRouter.sol#L1251-L1289](https://github.com/lidofinance/core/blob/d186530e74e07569295ac5de399389e5438bf567/contracts/0.8.9/StakingRouter.sol#L1251-L1289)

   It retrieves the stored withdrawal address and creates the publickey and signature based on the data.

4. BeaconChainDepositor.`_makeBeaconChainDeposits32ETH()`
   [https://github.com/lidofinance/core/blob/d186530e74e07569295ac5de399389e5438bf567/contracts/0.8.9/BeaconChainDepositor.sol#L41-L69](https://github.com/lidofinance/core/blob/d186530e74e07569295ac5de399389e5438bf567/contracts/0.8.9/BeaconChainDepositor.sol#L41-L69)

   It performs an argument length check (pubkey, signature) and passes it to the deposit contract.

5. DEPOSIT_CONTRACT.deposit()
   [https://github.com/lidofinance/core/blob/d186530e74e07569295ac5de399389e5438bf567/contracts/0.6.11/deposit_contract.sol#L101-L159](https://github.com/lidofinance/core/blob/d186530e74e07569295ac5de399389e5438bf567/contracts/0.6.11/deposit_contract.sol#L101-L159)

   The corresponding deposit contract: [https://etherscan.io/address/0x00000000219ab540356cBB839Cbe05303d7705Fa#readContract](https://etherscan.io/address/0x00000000219ab540356cBB839Cbe05303d7705Fa#readContract)

   It verifies the arguments and deposit value, then adds a node to the tree based on pubkey, withdrawal, and amount.

<aside> 💡

Lido.submit → Lido.deposit → StakingLouter.deposit() → BeaconChainDepositor.\_makeBeaconChainDeposits32ETH() → DEPOSIT_CONTRACT.deposit()

</aside>

### Infrared stake logic

1. InfraredBERA.mint()
   [https://github.com/wiimdy/infrared\_/blob/265182e933452ec867565ffc56ef976a34fe4db3/src/staking/InfraredBERA.sol#L213-L232](https://github.com/wiimdy/infrared_/blob/265182e933452ec867565ffc56ef976a34fe4db3/src/staking/InfraredBERA.sol#L213-L232)

   The user executes this by sending BERA. After \_deposit is executed, IBERA.mint is executed.

2. \_deposit()
   [https://github.com/wiimdy/infrared\_/blob/265182e933452ec867565ffc56ef976a34fe4db3/src/staking/InfraredBERA.sol#L270-L278](https://github.com/wiimdy/infrared_/blob/265182e933452ec867565ffc56ef976a34fe4db3/src/staking/InfraredBERA.sol#L270-L278)

   Calculates the total deposit and passes it to the depositor.

3. InfraredBERADepositor.queue()
   [https://github.com/wiimdy/infrared\_/blob/265182e933452ec867565ffc56ef976a34fe4db3/src/staking/InfraredBERADepositor.sol#L55-L69](https://github.com/wiimdy/infrared_/blob/265182e933452ec867565ffc56ef976a34fe4db3/src/staking/InfraredBERADepositor.sol#L55-L69)

   Calculates the reserved amount and waits for execute to be called.

4. InfraredBERADepositor.execute()
   [https://github.com/wiimdy/infrared\_/blob/265182e933452ec867565ffc56ef976a34fe4db3/src/staking/InfraredBERADepositor.sol#L76-L159](https://github.com/wiimdy/infrared_/blob/265182e933452ec867565ffc56ef976a34fe4db3/src/staking/InfraredBERADepositor.sol#L76-L159)

   - Corresponding transaction log: [https://app.blocksec.com/explorer/tx/berachain/0x26f147fa2d8ac7b3bb857f042a3106548f042024de401f2fbce5b892d04c29a3](https://app.blocksec.com/explorer/tx/berachain/0x26f147fa2d8ac7b3bb857f042a3106548f042024de401f2fbce5b892d04c29a3)

   - Total execution log: [https://dune.com/queries/5149238/8481973/](https://dune.com/queries/5149238/8481973/)

5. BeraDeposit.deposit()
   [https://github.com/berachain/contracts/blob/b3da3d3452999975c8c93f07a97c7b107d18a6f4/src/pol/BeaconDeposit.sol#L84-L128](https://github.com/berachain/contracts/blob/b3da3d3452999975c8c93f07a97c7b107d18a6f4/src/pol/BeaconDeposit.sol#L84-L128)

   Deposit Contract: [https://berascan.com/address/0x4242424242424242424242424242424242424242](https://berascan.com/address/0x4242424242424242424242424242424242424242)

   After argument verification, it executes with \_deposit().

6. \_deposit()
   [https://github.com/berachain/contracts/blob/b3da3d3452999975c8c93f07a97c7b107d18a6f4/src/pol/BeaconDeposit.sol#L189-L202](https://github.com/berachain/contracts/blob/b3da3d3452999975c8c93f07a97c7b107d18a6f4/src/pol/BeaconDeposit.sol#L189-L202)

   Burns the received BERA to the 0 address.

<aside> 💡

InfraBera.mint() → \_deposit() → IInfraredBERADepositor.queue()

keeper → InfraedBeraDepositor.execute() → IInfraredBERA.register → IBeaconDeposit.deposit()

</aside>

### Differences

1. In Berachain, the entire deposited amount is sent to the 0 address, unlike Ethereum. The actual Ethereum deposit contract shows a large amount of Ether accumulated.
2. In Ethereum, the Merkle root is recorded in the contract during deposit, whereas in Berachain, the Merkle root is managed via a beaconkit helper.

### Similarities

1. Both accumulate a certain amount, and then an authorized account executes the deposit. (Minimum deposit exists, gas saving)
2. The user does not specify which validator to stake to (pubkey), so the protocol sets it.
   (In the case of Infrared, validators are divided by company. What is the criterion?)
3. The logic flow (user stake, administrator deposit process) is similar.

## Reference

- [https://infrared.finance/docs](https://infrared.finance/docs)
- [https://github.com/wiimdy/infrared\_](https://github.com/wiimdy/infrared_)
- [https://github.com/lidofinance/core.git](https://github.com/lidofinance/core.git)
