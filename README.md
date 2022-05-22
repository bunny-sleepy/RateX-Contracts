# RateX Protocol

## Introduction

RateX is a decentralized interest rate swap (IRS) product that offers synthetic exposure to interest rates. The RateX protocol supports up to 100x leverage trading, and the trades will have expiry.

Note: synthetic means you need only provide margin to trade.

## Protocol Details

For an interest rate market, suppose the underlying's variable interest rate is $r_v$. For a trade to happen the both sides should agree on a swap rate $r_s$, and each pool will have a expiry time $T_e$.

### Market Participants

#### Fixed Rate Receivers

Fixed rate receivers look to exchange variable interest rate for fixed interest rate.

#### Variable Rate Receivers

Variable rate receivers look to exchange fixed interest rate for variable interest rate.

#### Liquidators (Keepers)

Liquidators play the role of triggering the liquidation accounts that has insufficient margin through partial liquidation or total liquidation. They can earn certain rewards from doing so. Currently RateX uses Chainlink Keepers as liquidators.

### Margin

You need to provide margin in order to trade. The minimum amount of margin required by a position is calculated by the maximum leverage of the pool and the position size.

#### Profit And Loss (PnL) Calculation

Suppose the notional value is $N$, and the time the order takes place is $T_b$.

- For Fixed Rate Receivers, the PnL of a position at time $T~ (T \leq T_e)$ is
  $$
  \text{PnL} = N \cdot \big((T - T_b) \cdot r_s -  \int_{T_b}^{T} r_v \mathrm{d}t\big) = N \cdot (T - T_b)\cdot (r_s - \overline{r_v})
  $$

- For Variable Rate Receivers, the PnL of a position at time $T~(T\leq T_e)$ is
  $$
  \text{PnL} = N \cdot \big(-(T - T_b) \cdot r_s +  \int_{T_b}^{T} r_v \mathrm{d}t\big) = N \cdot (T - T_b)\cdot ( -r_s + \overline{r_v})
  $$

The average variable interest rate $\overline{r_v}$ is over the period $T_b$ to $T$ and is read via the oracle.

#### Margin Ratio

The margin ratio $R_M$ of a position at time $T$ is calculated as
$$
R_M = \frac{M + \text{PnL}}{N}
$$
$M$ is the total margin provided by the user for this position.

#### Leverage

RateX supports leverage trading, the maximum leverage $\lambda_m$ is defined by the pool. If a trader is to open a position with leverage $\lambda$, and the notional value is $N$, then he need pay $\lambda \cdot N$ as margin. 

### Liquidations

#### Maintenance Margin Ratio

When the loss of a position is high, and the margin ratio falls behind a certain ratio, the maintenance margin ratio, the liquidators will be allowed to liquidate the position. The maintenance margin ratio $\overline{R_M}$ is a parameter calculated by the parameters in pool.

#### Liquidation Process

When a position's margin ratio is below the maintenance ratio, the liquidators can liquidate his position. The liquidation process goes as follows.

The liquidator takes over the position owned by the user, and a portion of the user's margin goes into the liquidator's account. Then the liquidator will supplement for the position's margin to ensure that the counterparties can continue to earn profit.

When a liquidator liquidates, he will take over ALL the positions that have insufficient margin ratio. By doing so, he will also be rewarded by funds in the insurance fund if no one liquidates within a certain time.

### Matching Engine

The matching engine will match the orders that appears on the orderbook.

#### Open A Position

The market orders will be automatically filled by being matched with limit orders. The limit orders will appear on the orderbook and wait to be matched. Currently all the limit orders follows a good-till-date manner. The pool will collect $0.02\% \cdot \frac{T_e}{365} \cdot N$ fee for each trade. Parts of them will go into the insurance fund. (Currently set to 50%)

#### Close A Position in Advance

By closing a position, the trader posts a liquidation order to the liquidators. Then the liquidator can take over your position even if your margin left is above of maintenance margin. The remain margin the trader can receive is calculated in the same way as the that of positions being liquidated.

### Mathematical Setting

#### Setting for Minimum Margin

The pool will have estimation of lower and upper bounds of interest rate of the underlying, which are denoted by $r_l$ and $r_u$ separately.

Suppose that the time after the creation of the pool is $T$, and if at this point a trader is to trade $N$ notional the minimum amount of margin needed is
$$
M_{min} = N\cdot \frac{T_e - T}{365} \cdot (r_u - r_l) \cdot \mu
$$
Where $\mu = 1.5$ is the reserve factor for the trade.

#### Setting for Liquidation

We set the minimum margin needed in order to avoid liquidation from happening while maximizing capital efficiency. Still in severe cases liquidations can happen, so we define the following.

The position can be liquidated when the margin plus PnL (suppose that value is $M_l$) at some time $T$ is less than
$$
M_{maintain} = N\cdot \frac{T_e - T}{365} \cdot (r_u - r_l)
$$
The amount of margin taken by the liquidator will be ($r_s$ is the swap rate)
$$
C=
\begin{cases}
\frac{T_e - T}{365} \cdot {(r_u - r_s)} \cdot N &\text{when the fixed rate receiver is to be liquidated}\\
\frac{T_e - T}{365} \cdot {(r_s - r_l)} \cdot N &\text{when the variable rate receiver is to be liquidated}
\end{cases}
$$
And the rest of the margin plus PnL $M_l - C$ will be returned to the trader.

```
Example setting for aUSDC supply rate:
r_l = 0.5%
r_u = 20%
T_e = 30 (days)
leverage_max = 100x (on genesis)

Suggestion: leverage be <= 50x if you do not check your margin ratio often.
```

## Contract Modules

### Pool

> The pool is the place where trade can take place. A pool specifies the underlying interest rate / debt rate to speculate, provide the PnL oracle, the term length and transaction parameters such as max leverage, maintenance ratio, and exit fee (fee to pay when one party exists in advance).



### Order Book

> The order book module lists, matches and executes the orders. There are two kinds of orders in total, market order and limit order. Also, the order book collect fees from trades and send parts of them into the insurance fund.



### Position Manager

> The position manager manages all users' position and margin. It records each position after an order is (fully or partially) filled, each position's PnL / Margin Ratio. Also, it allows users to increase / decrease margin for their position, and it will allow liquidators to execute liquidation orders when one position's margin ratio is below maintenance ratio.



### Insurance Fund

> The insurance fund will collect parts of the transaction fees. When a liquidation is to happen, the insurance fund will compensate the liquidator with parts of its vault's storage.



### Oracle

> The oracle will record the interest rate from Aave or Compound or Yearn by Chainlink Keepers constantly. The PositionManager will use the oracle to calculate PnL of each position, and to decide whether a position is liquidable.

```
Example:

Alice Market price 10000 aUSDC to trade fixed rate, she places 100 aUSDC as margin

2%: 5000
1.99%: 15000 (6000 B, 5000 C, 4000 D) -> in FCFS order

90 / 365 * 0.02%
```
