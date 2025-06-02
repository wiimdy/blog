---
title: "Berachain protocol analysis - Infrared"
date: 2025-06-02 T09:23:02+09:00
authors:
  - wiimdy
description: "Berachain protocol analysis - Infrared"
tags:
  - Web3
categories:
  - Web3
image:
  Path: /assets/img/upside_img/upside_thumbnail.jpeg
---

## What's Infrared

Infrared is focused on building infrastructure around the [Proof of Liquidity (PoL)](https://infrared.finance/docs/berachain#what-is-proof-of-liquidity) mechanism pioneered by [Berachain](https://infrared.finance/docs/berachain). The protocol aims to maximize value capture by providing easy-to-use liquid staking solutions for [BGT](https://infrared.finance/docs/tokens#bgt) and [BERA](https://infrared.finance/docs/tokens#bera), node infrastructure, and vaults. Through building solutions around [Proof of Liquidity (PoL)](https://infrared.finance/docs/berachain#what-is-proof-of-liquidity), Infrared is dedicated to enhancing the user experience and driving the growth of the [Berachain](https://infrared.finance/docs/berachain) ecosystem.

## Why use Infrared?

Infrared simplifies participation in [Berachain](https://infrared.finance/docs/berachain)’s [Proof of Liquidity (PoL)](https://infrared.finance/docs/berachain#what-is-proof-of-liquidity), helping users maximize their [BGT](https://infrared.finance/docs/tokens#bgt) and [BERA](https://infrared.finance/docs/tokens#bera) rewards through easy-to-use products like [iBGT](https://infrared.finance/docs/tokens#ibgt) and [iBERA](https://infrared.finance/docs/tokens#ibera). Infrared’s products also enable new flywheels throughout the [Berachain](https://infrared.finance/docs/berachain) ecosystem that wouldn’t otherwise be possible by making [BGT](https://infrared.finance/docs/tokens#bgt) and staked [BERA](https://infrared.finance/docs/tokens#bera) composable.

## Lido diff

인프라레드는 크게 보면 Liquid Staking solution이기 때문에 가장 유명한 Lido와 차이점을 조사해보았다.

### Lido stake logic

[https://app.blocksec.com/explorer/tx/eth/0x21fae646ba22c004e530ff58c3b2a1633a895b009611ea73cee50839896ca2d0](https://app.blocksec.com/explorer/tx/eth/0x21fae646ba22c004e530ff58c3b2a1633a895b009611ea73cee50839896ca2d0)

1. Lido.submit()[https://github.com/lidofinance/core/blob/d186530e74e07569295ac5de399389e5438bf567/contracts/0.4.24/Lido.sol#L917-L947](https://github.com/lidofinance/core/blob/d186530e74e07569295ac5de399389e5438bf567/contracts/0.4.24/Lido.sol#L917-L947)

   유저가 submit을 통해 이더를 보내 주면 buffer에 넣어 32ETH 배수 만큼 deposit을 진행한다. 따라서 유저에게는 바로 steth를 mint 해준다

2. Lido.deposit()[https://github.com/lidofinance/core/blob/d186530e74e07569295ac5de399389e5438bf567/contracts/0.4.24/Lido.sol#L694-L723](https://github.com/lidofinance/core/blob/d186530e74e07569295ac5de399389e5438bf567/contracts/0.4.24/Lido.sol#L694-L723)

   어느 정도 eth가 모이면 가능한지 확인 한 후 stakingLouter에게 전달을 한다.

3. StakingLouter.deposit()[https://github.com/lidofinance/core/blob/d186530e74e07569295ac5de399389e5438bf567/contracts/0.8.9/StakingRouter.sol#L1251-L1289](https://github.com/lidofinance/core/blob/d186530e74e07569295ac5de399389e5438bf567/contracts/0.8.9/StakingRouter.sol#L1251-L1289)

   저장되어 있는 withdraw 주소를 가져와 publickey, signature를 data 바탕으로 만든다.

4. BeaconChainDepositor.`_makeBeaconChainDeposits32ETH()` [https://github.com/lidofinance/core/blob/d186530e74e07569295ac5de399389e5438bf567/contracts/0.8.9/BeaconChainDepositor.sol#L41-L69](https://github.com/lidofinance/core/blob/d186530e74e07569295ac5de399389e5438bf567/contracts/0.8.9/BeaconChainDepositor.sol#L41-L69)

   인자 길이 검사(pubkey, signature)를 진행하고 deposit contract 에게 넘긴다

5. DEPOSIT_CONTRACT.deposit()[https://etherscan.io/address/0x00000000219ab540356cBB839Cbe05303d7705Fa#readContract](https://etherscan.io/address/0x00000000219ab540356cBB839Cbe05303d7705Fa#readContract) 해당 deposit contract

- [https://github.com/lidofinance/core/blob/d186530e74e07569295ac5de399389e5438bf567/contracts/0.6.11/deposit_contract.sol#L101-L159](https://github.com/lidofinance/core/blob/d186530e74e07569295ac5de399389e5438bf567/contracts/0.6.11/deposit_contract.sol#L101-L159)

  인자와 deposit vaule를 검사하고 pubkey, withdrawal, amount를 바탕으로 node를 tree에 추가한다

<aside> 💡

Lido.submit → Lido.deposit → StakingLouter.deposit() → BeaconChainDepositor.\_makeBeaconChainDeposits32ETH() → DEPOSIT_CONTRACT.deposit()

</aside>

## Infrared stake logic

1. InfraredBERA.mint()

- [https://github.com/wiimdy/infrared\_/blob/265182e933452ec867565ffc56ef976a34fe4db3/src/staking/InfraredBERA.sol#L213-L232](https://github.com/wiimdy/infrared_/blob/265182e933452ec867565ffc56ef976a34fe4db3/src/staking/InfraredBERA.sol#L213-L232) user가 bera를 보내며 실행 한다. \_deposit 실행 후 IBERA.mint가 실행된다.

2. \_deposit()

- [https://github.com/wiimdy/infrared\_/blob/265182e933452ec867565ffc56ef976a34fe4db3/src/staking/InfraredBERA.sol#L270-L278](https://github.com/wiimdy/infrared_/blob/265182e933452ec867565ffc56ef976a34fe4db3/src/staking/InfraredBERA.sol#L270-L278) 총 deposit을 계산하고, depositor로 넘긴다.

3. InfraredBERADepositor.queue()

- [https://github.com/wiimdy/infrared\_/blob/265182e933452ec867565ffc56ef976a34fe4db3/src/staking/InfraredBERADepositor.sol#L55-L69](https://github.com/wiimdy/infrared_/blob/265182e933452ec867565ffc56ef976a34fe4db3/src/staking/InfraredBERADepositor.sol#L55-L69) reserve된 양을 구하고, execute가 실행 될 때까지 기다린다.

4. InfraredBERADepositor.execute()

- [https://github.com/wiimdy/infrared\_/blob/265182e933452ec867565ffc56ef976a34fe4db3/src/staking/InfraredBERADepositor.sol#L76-L159](https://github.com/wiimdy/infrared_/blob/265182e933452ec867565ffc56ef976a34fe4db3/src/staking/InfraredBERADepositor.sol#L76-L159) [https://app.blocksec.com/explorer/tx/berachain/0x26f147fa2d8ac7b3bb857f042a3106548f042024de401f2fbce5b892d04c29a3](https://app.blocksec.com/explorer/tx/berachain/0x26f147fa2d8ac7b3bb857f042a3106548f042024de401f2fbce5b892d04c29a3) 해당 트젝 로그 [https://dune.com/queries/5149238/8481973/](https://dune.com/queries/5149238/8481973/) - 총 실행 로그

5. BeraDeposit.deposit()

- [https://berascan.com/address/0x4242424242424242424242424242424242424242](https://berascan.com/address/0x4242424242424242424242424242424242424242)
- [https://github.com/berachain/contracts/blob/b3da3d3452999975c8c93f07a97c7b107d18a6f4/src/pol/BeaconDeposit.sol#L84-L128](https://github.com/berachain/contracts/blob/b3da3d3452999975c8c93f07a97c7b107d18a6f4/src/pol/BeaconDeposit.sol#L84-L128) 인자 검증 후 \_deposit() 으로 실행

6. \_deposit()

- [https://github.com/berachain/contracts/blob/b3da3d3452999975c8c93f07a97c7b107d18a6f4/src/pol/BeaconDeposit.sol#L189-L202](https://github.com/berachain/contracts/blob/b3da3d3452999975c8c93f07a97c7b107d18a6f4/src/pol/BeaconDeposit.sol#L189-L202) 받는 BERA 0 주소로 소각

<aside> 💡

InfraBera.mint() → \_deposit() → IInfraredBERADepositor.queue()

keeper → InfraedBeraDepositor.execute() → IInfraredBERA.register → IBeaconDeposit.deposit()

</aside>

## 차이점

1. 베라체인에서는 deposit한 금액을 전부 0으로 보내지만 이더리움은 그렇지 않다. 실제 이더리움의 deposit contract를 보면 많은 이더가 쌓여있다.
2. 이더리움에서는 deposit 할 때 컨트랙트에서 머클루트를 통해 기록하지만, 베라체인에서는 beaconkit helper를 통해 머클 루트를 관리한다.

## 공통점

1. 둘다 어느 정도 모은 다음, 권한이 있는 계정이 deposit을 실행한다. (최소 deposit 존재, 가스 절약)
2. 유저가 어느 validator에게 stake할지 pubkey를 명시하지 않아 protocol이 설정 한다.

   (infrared 경우 validator가 회사 단위로 나뉘어지던데 무슨 기준인지?)

3. 로직 흐름 (유저 stake, 관리자 deposit 진행) 은 비슷하다

# PoL 관련 기능 정리

## IBERA ←→ BeaconDeposit

유저가 IBERA를 민팅하면서 어떻게 deposit이 실행되는가

### asset: BERA, IBERA

1. user가 `InfraredBERA.mint` 실행
2. `InfraredBERADepositor.queue`로 BERA를 queue 해둠 (실제 deposit을 관리자가 진행, 사용자 func과 관리자 func 기능 분리)
3. _`(totalSupply * amount) / deposits`_ 에 비례하여 IBERA mint
4. keeper가 `InfraredBERADepositor.execute` 로 해당하는 Pubkey로 Beacondeposit에 deposit 실행

## Infrared ←→ BaseBGT

BlockrewardController가 주는 baseBGT를 어떻게 사용할 것인가?

1. infrared에 있는 BGT는 rewardBGT + baseBGT 이다. 이중 rewardBGT 받은 만큼 IBGT로 mint 하기 때문에 baseBGT = totalBGT - total ibgt 이다. (어디서 어디로 가는지 )
2. `harvestBase`를 실행하면 BaseBGT만큼 BERA로 `redeem` 한다.
3. 이 BERA를 IBERAFeeReceivor로 보낸다

<aside> 💡

**결론: BaseBGT는 bera로 redeem하여 IBERAFeeReceivor로 보낸다.**

</aside>

## InfraredVault ←→ Reward Vault

Reward Vault가 나누어주는 Reward BGT를 유저에게 어떻게 분배하는가

### asset: lp token, reward bgt

### LP stake

1. user가 `InfraredVault.stake` 로 LP 예치
2. 이걸 InfraredVault에서 `approve` 한 후 RewardVault에 `stake` 실행

### LP stake 보상 수령

1. user가 `InfraredVault.getReward`를 통해 `onReward` 실행
2. `Infrared.harvestVault` → `RewardLib.harvestVault` 실행
   1. `rewardsVault.getReward` 를 통해 BGT를 Infrared로 보상 수령
   2. BGT 나온 만큼 IBGT mint해서 InfraredVault에 `addReward`
3. 다시 `MultiReward.getRewardForUser`로 돌아와 rewards[\_user][_rewardsToken] 에 저장된 만큼 IBGT 제공

### LP withdraw

1. user가 `InfraredVault.withdraw` 로 LP 인출 요청
2. `rewardVault.withdraw`로 LP withdraw 후 user에게 `transfer`

<aside> 💡

**결론: user가 넣은 lp token으로 받은 reward BGT를 infrared가 보유하고, IBGT를 민팅하여 각 vault에 넣는다.** 계산식에 맞게 유저에게 IBGT를 보내준다.

</aside>

## Infrared ←→ BGTIncentiveDistributor…

operator(Infrared)가 가져간 incentive를 어떻게 사용하는 것인가

### asset: incentive token, WBERA, BERA

1. keeper가 `Infrared.claimBGTIncentives` 를 통해 rewardVault가 준 incentive를 수령한다.
2. 아무나 `Infrared.harvestBribes`를 실행 하여 Infrared에 있는 incentive가 BribeCollector로 이동한다(이때 token은 whitelist 되어야 함)
3. 아무나 `BribeCollector.claimFees`를 통해 WBERA와 incentive token을 교환한다.
4. Infrared는 `collectBribes`를 통해 BribeCollector에 있는 WBERA를 다시 가져가 `collectBribesInWBERA` 를 통해 BERAfeeReceivor, IBGT Vault로 분배한다.

<aside> 💡

**결론: protocol incentive를 수집하여 WBERA와 교환하고 받은 WBERA를** BERAfeeReceivor, IBGT Vault로 분배한다. (`RewardsLib.collectBribesInWBERA` 참조)

</aside>

### 번외: IBERAfeeReceivor는 무엇을 하는 아이인가? 왜 계속 bera를 받는가?

- BERA의 출처: protocol incentive, base BGT 즉 operator 가 받는 보상이 대부분이다.
- 외부에서 `sweep()`을 많이 실행하는데 이를 통해 쌓인 BERA를 정리하여 전체의 10%는 operator 보상으로 쌓아 두고 나머지는 `_deposit()` 에 넣는다
- `RewardLib.harvestOperatorRewards` 를 통해 쌓인 operator 보상을 나누어준다

## Infrared ←→ Validator Operator

1. validator가 선정한 operator는 Infrared의 컨트랙트 사용 [https://berascan.com/address/0xb71b3daea39012fb0f2b14d2a9c86da9292fc126](https://berascan.com/address/0xb71b3daea39012fb0f2b14d2a9c86da9292fc126) a41 이 operator 임
2. 여기서 chef 설정, boost, 등 다양한 상호 작용..

### Reference

- https://infrared.finance/docs
- https://berascan.com/accounts/label/infrared?subcatid=undefined&size=25&start=0&col=1&order=asc
- https://github.com/wiimdy/infrared_
-
- [https://github.com/lidofinance/core.git](https://github.com/lidofinance/core.git)
