__includes ["market_maker_agent.nls" "liquidity_demander_agent.nls" "orders.nls" "writefileaudit.nls" "writefiledepth.nls" "writefileagent.nls" "liquidity_supplier_agent.nls" "forced_sale_agent.nls" "market_impact_agent.nls"]

;********************************************************************************************************************************************************************************
;Global Variables
;********************************************************************************************************************************************************************************
; price - the current price of the asset
; buyQueue - The Bid Side of the Open Order Book
; sellQueue - The Ask Side of the Open Order Book
; tradeWipeQueue - coding wipe queue for transactions
; tradeMatch - trade match id variable
; currentAsk - current best ask price
; currentBid - current best bid price

; numberBid, numberAsk - ploting variables
; volume - single agent volume of executed trades
; volatility - volatility of the market
; currentPriceVol - used to determine the price volatility
; totalVolume - total volume of executed trades in the market
; currentVol - most recent volume executed

; movingAverage - the moving average price of the asset for 1 min (600 ticks)
; currentMA - the most recent moving average price
; stopMarketMakers - market maker stop counter for markeet crash
; movingAverageV - the moving average volume of the asset for 1 min (600 ticks)
; currentMAV - the most recent moving average volume
; currentBQD - the current bid book depth

; currentSQD - the current ask book depth
; pastMA - previous moving average price
; stablePrice - moving average stable price for market
; stopTriggered - market stop lose trigger mechanisum
; stopTriggerCounter - market stop lose trigger mechanisum tick counter
; priceReturns - list of all price returns

; transactionCost - cost of trading
; aggresiveBid - number of market orders to buy
; aggresiveAsk - number of market orders to sell
; minPriceValue - minimum price of asset, used for measuring flash crash effect
; randNumOT - variable used to represent directional trend in the market which makes trader prefer a side of the order book to participate in
; pastPrices - keeps track of previous prices
; period -allows to keep track of a sequence in a trade strategy

; tradeWipeQueueB, tradeWipeQueueA - list contrining all the trades that occured in a tick period, used for updating the orderbok
; arrayQ - array contrainging the quantities for each order
; tradeExNumber - used to keep track of the order of actions in the audit trail book
; traderListNumbers - used in verfying theat each trader has a unique trader account number

; priceVolatilityVar - volatility variable, in order to create trends in volatility

; marketImpactValue


extensions [array table]

Globals [price buyQueue sellQueue orderNumber tradeWipeQueue tradeMatch currentAsk currentBid
        numberBid numberAsk volume volatility currentPriceVol totalVolume currentVol
        movingAverage currentMA movingAverageV currentMAV currentBQD
        currentSQD pastMA priceReturns
        transactionCost aggresiveBid aggresiveAsk minPriceValue randNumOT pastPrices period
        tradeWipeQueueB tradeWipeQueueA arrayQ tradeExNumber traderListNumbers
        currentBuyInterest currentSellInterest currentBuyInterestPrice currentSellInterestPrice maxBuyInterest
        priceVolatilityVar

        BuyOrderQueue SellOrderQueue ; ???
        numberOrderBid numberOrderAsk
        currentOrderAsk currentOrderBid
        MatchID

        marketImpactValue
      ]

;********************************************************************************************************************************************************************************
;Agents Variables
;********************************************************************************************************************************************************************************
; movingAverageDIS - the moving average differance between the moviing average price and the current price, used as a threshold for a trader
; totalCanceled - total number of trades canceled or modified by a trader
; reversion - price reversion mechanisum used to remove positions from market makers and high frequency traders
; typeOfTrader - indicates the type of trader a patch is playing as
; traderNumber - The randomly assigned number to indicate trader in the Order Book

; tradeStatus - Current trade Status (Buy, Sell, Bought, Sold, Canceled) in the Open Order Book
; tradeQuantity - Current Quantity trading in the Open Order Book
; tradeOrderNumber - Number of the Order that is currently in the Open Order Book
; speed - Frequency of the Trader to Trade
; tradeSpeedAdjustment - random variability given to each traders trading speed, baset on class of trader
; tradePrice - Price of the current trade in the Open Order Book
; tradeQ - Current Quantity trading in the Open Order Book, needed for audit trail

; tradeOrderForm - Order Book info
; countticks - the length that trade has been in the book
; sharesOwned - number of shares out standing
; tradeAccount - the porfiatability of that trader
; totalBought - total number shares of bought
; totalSold - total number shares sold

; averageBoughtPrice - average buy price
; averageSoldPrice - average sell price
; marketDumpTimer - variable to impliment stop lose orders
; marketPauseTickCount - market pause mechanisum for agents to stop exicuting tranactions for a select quanitty of time (150 ticks) while the market is pause from a quick price drop

; checkTraderNumber - used in verfying theat each trader has a unique trader account number
; buysell - used in the audit trail to determine if the trader is acting on the Buy (B) or Sell (S) side of the order book
; modify - used to determine if an order has been modified

turtles-own [ movingAverageDIS totalCanceled reversion typeOfTrader traderNumber
              tradeStatus tradeQuantity tradeOrderNumber speed tradeSpeedAdjustment tradePrice
              tradeOrderForm countticks sharesOwned tradeAccount totalBought totalSold
              averageBoughtPrice averageSoldPrice
              checkTraderNumber buysell modify
              ]

breed [orders an-order] ; orders is the name of the order set, an-order is the name of a single member.

orders-own [ OrderPrice OrderB/A OrderID OrderTraderID OrderQuantity PriceOrder TraderWho TraderWhoType HON1 HON2]

breed [traders a-trader]; again traders is one breed

traders-own [openOrders PriceOrder OrderPositionDesired ]

;********************************************************************************************************************************************************************************
;Setup Model Function
;*******************************************************************************************************************************************************************************

to setup
  __clear-all-and-reset-ticks
  setup-economy
  file-close-all
  set currentMA 100
  set volatility [1 2 3 5 7]
  set pastPrices [1 2 3 5 7]
  set movingAverage []
  set movingAverageV []
  set priceReturns []
  set currentPriceVol 1
  set currentBQD 2
  set currentSQD 2
  set transactionCost 0
  set pastMA 400

  set currentOrderBid 399
  set currentOrderAsk 401
  set price 400

  my-setup-plots
  set arrayQ array:from-list n-values 10000 ["B"]
  carefully [file-delete "OrderBook.csv"][]
  carefully [file-delete "OrderBookDepth.csv"][]
  set randNumOT 0
  set period 0
  set tradeExNumber 0
  set numberAsk []
  set numberBid []

  set BuyOrderQueue []
  set SellOrderQueue []
  set numberOrderAsk []
  set numberOrderBid []

  carefully [file-delete "OrderBook.csv"][]
  carefully [file-delete "OrderBookDepth.csv"][]
  carefully [file-delete "AgentData.csv"][]
  carefully [writeFileTitles][]
  carefully [writeFileTitleDepth][]
  carefully [writeFileTitleAgent][]
end

;********************************************************************************************************************************************************************************
;Initial Model and Agent Conditions
;*******************************************************************************************************************************************************************************

to setup-economy  ;; turtles procedure for setup
  set traderListNumbers [0]
  create-traders #_Liquidity_Demander [LD_Setup]  ; create-<breed> syntax, #_Liquidity_Demander is from the interface.
  create-traders #_Market_Makers [MM_Setup]
  create-traders #_Liquidity_Supplier[LS_Setup]
  create-traders 1[FS_Setup]
  create-traders 1[MI_Setup]

  set buyQueue []
  set sellQueue []
  set tradeWipeQueue []
  set tradeWipeQueueB []
  set tradeWipeQueueA []
  ask traders [
   if(ticks = 0) [  checkTraderNumberUnique
     ifelse (checkTraderNumber = 1) [set traderListNumbers lput traderNumber traderListNumbers][ checkTraderNumberUnique ]
   ]
  ]
end

;********************************************************************************************************************************************************************************
;Function that is run to for every tick of the model to advance it one time step ahead
;********************************************************************************************************************************************************************************

to go
  set currentBuyInterest 0
  set currentSellInterest 0
  set currentBuyInterestPrice 0
  set currentSellInterestPrice 0

  if( ticks mod 10 = 0)
  [
    set aggresiveBid 0
    set aggresiveAsk 0
  ]

  if (ticks = (MIPeriod)) [
    set marketImpactValue price
  ]
  if (ticks = (MIPeriod + 5)) [
    set marketImpactValue (marketImpactValue - price)
  ]

  ask traders [

    set countticks (countticks + 1)

    if (typeOfTrader = "LiquidityDemander") [
      if countticks >= (liquidityDemanderTradeLength + tradeSpeedAdjustment) [
        set tradeStatus "Transact"

        if(ticks > 5000) [set totalCanceled (totalCanceled + tradeQuantity)]

        set speed int(random-poisson liquidity_Demander_Arrival_Rate) + 1
      ]
    ]

    if (typeOfTrader = "MarketMakers") [
        if countticks >= (marketMakerTradeLength + tradeSpeedAdjustment)[
          set tradeStatus "Transact"

          set speed int(random-poisson market_Makers_Arrival_Rate) + 2
        ]
    ]

    if (typeOfTrader = "LiquiditySupplier") [
      if countticks >= (liquiditySupplierTradeLength + tradeSpeedAdjustment)  [
        set tradeStatus "Transact"

        if(ticks > 5000) [set totalCanceled (totalCanceled + tradeQuantity)]

        set speed int(random-poisson liquidity_Supplier_Arrival_Rate) + 1
      ]
    ]

    if (typeOfTrader = "ForcedSale" and QuntitySale > 0) [
      if ((countticks >= (5 + tradeSpeedAdjustment)) and (PeriodtoStartExecution < ticks) and (PeriodtoEndExecution >= ticks)) [
        set tradeStatus "Transact"
        set speed 5
      ]
    ]

    if (typeOfTrader = "MarketImpact" and MIQuantity > 0) [
      if ((countticks >= (5 + tradeSpeedAdjustment)) and (MIPeriod = ticks)) [
        set tradeStatus "Transact"
        set speed 5
      ]
    ]

    set tradeAccount ((sharesOwned * ( price / 4) - averageBoughtPrice * totalBought + averageSoldPrice * totalSold) - (transactionCost * (totalBought + totalSold)))

    if((typeOfTrader = "LiquidityDemander" or typeOfTrader = "LiquiditySupplier" or typeOfTrader = "MarketMakers" ) and tradeStatus = "Buy" and tradeQuantity > 0)[
      set currentBuyInterestPrice ((currentBuyInterestPrice * currentBuyInterest + tradeQuantity * tradePrice) / (currentBuyInterest + tradeQuantity))
      set currentBuyInterest (currentBuyInterest + tradeQuantity)
    ]

    if((typeOfTrader = "LiquidityDemander" or typeOfTrader = "LiquiditySupplier" or typeOfTrader = "MarketMakers" ) and tradeStatus = "Sell" and tradeQuantity > 0)[
      set currentSellInterestPrice ((currentSellInterestPrice * currentSellInterest + tradeQuantity * tradePrice) / (currentSellInterest + tradeQuantity))
      set currentSellInterest (currentSellInterest + tradeQuantity)
    ]

    if (tradeStatus = "Transact")[
      if countticks > (speed + tradeSpeedAdjustment)  [
        set countticks 0
        set modify 0

        if typeOfTrader = "LiquidityDemander"
        [
          liquidityDemanderStrategy
        ]

        if typeOfTrader = "MarketMakers"
        [
          strategyMedium
        ]

        if typeOfTrader = "LiquiditySupplier"
        [
          liquiditySupplierStrategy
        ]

        if typeOfTrader = "ForcedSale"
        [
          forcedSaleStrategy
        ]

        if typeOfTrader = "MarketImpact"
        [
          marketImpactStrategy
        ]

        if(tradeStatus = "Buy")
        [
           set buysell "B"
        ]

        if(tradeStatus = "Sell")
        [
           set buysell "S"
        ]

        if(tradePrice <= currentOrderBid and tradeStatus = "Buy")[set aggresiveBid (aggresiveBid + tradeQuantity)]
        if(tradePrice >= currentOrderAsk and tradeStatus = "Sell")[set aggresiveAsk (aggresiveAsk + tradeQuantity)]
      ]

      let transactionVar 0

      if (ticks > 5000 ) [
        transactionOrder
      ]
    ]
  ]

  if ( count orders with [OrderB/A = "Buy"] > 0 )
  [
    set numberOrderBid []
    histoSetupTestBuy
    setup-plot2
  ]

  if ( count orders with [OrderB/A = "Sell"] > 0 )
  [
    set numberOrderAsk []
    histoSetupTestSell

  ]

  do-plots

  if(ticks >= 5000)
  [
    if((ticks - 4700) mod 600 = 0 )
    [
      calculatePriceReturns
    ]
  ]

  if(ticks > 12000) [
    set minPriceValue min movingAverage
  ]
  if(DepthFile = true and ticks > 4999)[
    writetofiledepth
  ]
  if(AgentFile = true and ticks > 4999)[
    writetofileagent
  ]

  tick
end

;********************************************************************************************************************************************************************************
;Function for transacting Trades to be run in the Market
;********************************************************************************************************************************************************************************

to transactionOrder
  if ( count orders with [OrderB/A = "Buy"] > 0 and count orders with [OrderB/A = "Sell"] > 0) [
    let firstInBuyQueue first (sort-on [(- PriceOrder)] orders with [OrderB/A = "Buy"] )
    let firstInSellQueue first (sort-on [PriceOrder] orders with [OrderB/A = "Sell"])

    let quantityDiff 0
    let orderBidID 0
    let orderAskID 0
    let traderBid 0
    let traderAsk 0

    let traderBidNum 0
    let traderAskNum 0

    let traderBidType 0
    let traderAskType 0

    let orderQunatityBid 0
    let orderQunatityAsk 0

    let orderHON1Bid 0
    let orderHON2Bid 0
    let orderHON1Ask 0
    let orderHON2Ask 0

    ask firstInBuyQueue [
      set currentOrderBid OrderPrice
      set quantityDiff OrderQuantity
      set orderQunatityBid OrderQuantity
      set orderBidID OrderID
      set traderBid TraderWho
      set orderHON1Bid HON1
      set orderHON2Bid HON2
    ]

    ask firstInSellQueue [
      set currentOrderAsk OrderPrice
      set quantityDiff (quantityDiff - OrderQuantity)
      set orderQunatityAsk OrderQuantity
      set orderAskID OrderID
      set traderAsk TraderWho
      set orderHON1Ask HON1
      set orderHON2Ask HON2
    ]

    if (currentOrderAsk <= currentOrderBid) [
      if ( quantityDiff = 0 ) [

        ask traderBid [ set openorders remove firstInBuyQueue openorders set traderBidNum traderNumber set traderBidType typeOfTrader]
        ask traderAsk [ set openorders remove firstInSellQueue openorders set traderAskNum traderNumber set traderAskType typeOfTrader]
        ask firstInBuyQueue [ die ]
        ask firstInSellQueue [ die ]

        if orderBidID > orderAskID [
          set price currentOrderAsk
        ]
        if orderBidID < orderAskID [
          set price currentOrderBid
        ]

        if(AuditTrail = true)[
          set MatchID (MatchID + 1)

          writetofile orderBidID "Bought" price orderQunatityBid traderBidType traderBidNum 1 MatchID orderHON1Bid orderHON2Bid
          writetofile orderAskID "Sold" price orderQunatityAsk traderAskType traderAskNum 2 MatchID orderHON1Ask orderHON2Ask
        ]

        ask traderBid [ set sharesOwned (sharesOwned + orderQunatityBid) set averageBoughtPrice ((averageBoughtPrice * totalBought + (price / 4) * orderQunatityBid) / (totalBought + orderQunatityBid)) set totalBought (totalBought + orderQunatityBid) ]
        ask traderAsk [ set sharesOwned (sharesOwned - orderQunatityAsk) set averageSoldPrice ((averageSoldPrice * totalSold + (price / 4) * orderQunatityAsk) / (totalSold + orderQunatityAsk)) set totalSold (totalSold + orderQunatityAsk)]
        set volume (volume + orderQunatityAsk)

      ]

      if ( quantityDiff > 0 ) [

        ask firstInBuyQueue [ set OrderQuantity quantityDiff ]
        ask traderBid [ set traderBidNum traderNumber set traderBidType typeOfTrader]
        ask traderAsk [ set openorders remove firstInSellQueue openorders set traderAskNum traderNumber set traderAskType typeOfTrader]
        ask firstInSellQueue [ die ]

        if orderBidID > orderAskID [
          set price currentOrderAsk
        ]
        if orderBidID < orderAskID [
          set price currentOrderBid
        ]

        if(AuditTrail = true)[
          set MatchID (MatchID + 1)

          writetofile orderBidID "Bought" price orderQunatityAsk traderBidType traderBidNum 1 MatchID orderHON1Bid orderHON2Bid
          writetofile orderAskID "Sold" price orderQunatityAsk traderAskType traderAskNum 2 MatchID orderHON1Ask orderHON2Ask
        ]

        ask traderBid [ set sharesOwned (sharesOwned + orderQunatityAsk)
          set averageBoughtPrice ((averageBoughtPrice * totalBought + (price / 4) * orderQunatityAsk) / (totalBought + orderQunatityAsk)) set totalBought (totalBought + orderQunatityAsk)]

        ask traderAsk [ set sharesOwned (sharesOwned - orderQunatityAsk)
          set averageSoldPrice ((averageSoldPrice * totalSold + (price / 4) * orderQunatityAsk) / (totalSold + orderQunatityAsk)) set totalSold (totalSold + orderQunatityAsk)  ]
        set volume (volume + orderQunatityAsk)

        transactionOrder
      ]

      if ( quantityDiff < 0 ) [

        ask traderBid [ set openorders remove firstInBuyQueue openorders set traderBidNum traderNumber set traderBidType typeOfTrader]
        ask firstInSellQueue [ set OrderQuantity ( -1 * quantityDiff) ]
        ask traderAsk [ set traderAskNum traderNumber set traderAskType typeOfTrader]
        ask firstInBuyQueue [ die ]

        if orderBidID > orderAskID [
          set price currentOrderAsk
        ]
        if orderBidID < orderAskID [
          set price currentOrderBid
        ]

        if(AuditTrail = true)[
          set MatchID (MatchID + 1)

          writetofile orderBidID "Bought" price orderQunatityBid traderBidType traderBidNum 1 MatchID orderHON1Bid orderHON2Bid
          writetofile orderAskID "Sold" price orderQunatityBid traderAskType traderAskNum 2 MatchID orderHON1Ask orderHON2Ask
        ]

        ask traderBid [ set sharesOwned (sharesOwned + orderQunatityBid) set averageBoughtPrice ((averageBoughtPrice * totalBought + (price / 4) * orderQunatityBid) / (totalBought + orderQunatityBid)) set totalBought (totalBought + orderQunatityBid)]
        ask traderAsk [ set sharesOwned (sharesOwned - orderQunatityBid) set averageSoldPrice ((averageSoldPrice * totalSold + (price / 4) * orderQunatityBid) / (totalSold + orderQunatityBid)) set totalSold (totalSold + orderQunatityBid)]
        set volume (volume + orderQunatityBid)

        transactionOrder
      ]
    ]
  ]
end

;********************************************************************************************************************************************************************************
;Calculate Price Returns
;********************************************************************************************************************************************************************************

to calculatePriceReturns
  set priceReturns lput (ln((item (length movingAverage - 1) movingAverage) / (item (length movingAverage - 30) movingAverage)))  priceReturns
end

;********************************************************************************************************************************************************************************
;Ploting of Booking to the Histogram, Price, Volume, Volatility, Moving Average ....
;********************************************************************************************************************************************************************************

to histoSetupTestBuy
  let lengthofList count orders with [OrderB/A = "Buy"]
  if lengthofList > 0 [
    ask orders with [OrderB/A = "Buy"] [
      repeat OrderQuantity [
        set numberOrderBid lput ((OrderPrice / 4 ) * 100) numberOrderBid
      ]
    ]
  ]
end

to histoSetupTestSell
  let lengthofList count orders with [OrderB/A = "Sell"]
  if lengthofList > 0 [
    ask orders with [OrderB/A = "Sell"] [
      repeat OrderQuantity [
        set numberOrderAsk lput ((OrderPrice / 4 ) * 100) numberOrderAsk
      ]
    ]
  ]
end

to my-setup-plots ;;initialize plots
  clear-all-plots
  setup-plot2
  setup-plot3
  setup-plot31
  if((ticks mod 10) = 0)[
    setup-plot4
  ]
  setup-plot5
  setup-plot6
  setup-plot7
  setup-plot8
  setup-plot9
  setup-plot10
  setup-plot11
  setup-plot12
  setup-plot13
end

to setup-plot2
  set-current-plot "Distribution of Bid/Ask"
  set-plot-x-range ((price / 4) * 100 - 1000) ((price / 4 ) * 100 + 1000)
  set-histogram-num-bars 100
end

to setup-plot3
  set-current-plot "Price"
  plot (price / 4)
end

to setup-plot31
  set-current-plot "Kyle Obizhaeva Measure"
  plot 0
end

to setup-plot4
  set-current-plot "Volume"
  plot volume
end

to setup-plot5
  set-current-plot "Volatility"
end

to setup-plot6
  set-current-plot "Ten Minute Moving Average Price"
  plot currentMA
end

to setup-plot7
  set-current-plot "Ten Minute Moving Average Volume"
  plot currentMAV
end

to setup-plot8
  set-current-plot "Market Depth"
  plot currentMAV
end

to setup-plot9
  set-current-plot "Bid-Ask Spread"
  set-plot-y-range 0 5
end

to setup-plot10
  set-current-plot "Turnover Rate"
  plot 0
end

to setup-plot11
  set-current-plot "Averages Shared Owned"
  plot 0
end

to setup-plot12
  set-current-plot "Average Profit-Loss"
  plot 0
end

to setup-plot13
  set-current-plot "Daily Price"
  plot (price / 4)
end

to do-plots

  set-current-plot "Distribution of Bid/Ask"
  set-plot-x-range ((price / 4) * 100 - 1000) ((price / 4 ) * 100 + 1000)
  plot-pen-reset
  set-plot-pen-mode 1
  let n2 numberOrderBid
  set-current-plot-pen "Bid"
  histogram n2
  set-histogram-num-bars 100
  let a2 numberOrderAsk
  set-current-plot-pen "Ask"
  histogram a2
  set-histogram-num-bars 100

  if(ticks > 5000)
  [
    set-current-plot "Price Returns"
    plot-pen-reset
    set-plot-pen-mode 1
    set-plot-x-range -0.025 .025
    set-histogram-num-bars 51
    histogram priceReturns
  ]

  if(ticks > 5000)
  [
    set-current-plot "Price"
    plot (price / 4)

      set-current-plot "Daily Price"
      plot (price / 4)
      set-plot-x-range (ticks - 6440) (ticks - 5000)


    if((ticks mod 10) = 8)[
      set-current-plot "Volume"
      set-plot-pen-mode 1

      plot volume

      set totalVolume (totalVolume + volume)
    ]]

  if(ticks  > 1000)[
    if((ticks mod 10) = 8)[
     set volatility lput ((price / 4) ) volatility
     set pastPrices lput price pastPrices
     let lengthVola length volatility
     if(ticks  > 5000)[
       let subVL sublist volatility (lengthVola - 29) lengthVola
       let avgVL mean subVL
       set movingAverage lput avgVL movingAverage
     ]
     set movingAverageV lput volume movingAverageV
     set currentPriceVol (currentPriceVol + 1)
     if (currentPriceVol > 1000)[set currentPriceVol 1000]
     set volume 0
    ]
  ]

  set currentVol 0
  if(ticks >= 5600)[
    let lengthVol length volatility
    let subVol sublist volatility (lengthVol - 10) lengthVol
    let maxVol max subVol
    let minVol min subVol
    set currentVol ln (maxVol / minVol)
      set-current-plot "Volatility"
      let lPR length priceReturns
      plot (sqrt(abs (item (lPR - 1) priceReturns)) * 15.87)


  ]

  set-current-plot "Ten Minute Moving Average Price"
  if(ticks > 5000)[
    let lengthMA length volatility
    let lengthMB length pastPrices
    let subMA sublist volatility (lengthMA - 29) lengthMA
    let subMB sublist pastPrices (lengthMB - 29) lengthMB
    let avgMA mean subMA
    set pastMA item 1 subMB
    set currentMA avgMA
    plot currentMA
  ]


  set-current-plot "Ten Minute Moving Average Volume"
  set currentMAV 2
  if(ticks >= 5000)[
    let lengthMAV length movingAverageV
    let subMAV sublist movingAverageV (lengthMAV - 29) lengthMAV
    let avgMAV mean subMAV
    set currentMAV avgMAV
    plot currentMAV
  ]


  set-current-plot "Market Depth"
  set currentBQD 2
  set currentSQD 2
  if(ticks >= 5000)[
    set-current-plot-pen "Bid"
    plot sum [OrderQuantity] of orders with [OrderB/A = "Buy"]
    set-current-plot-pen "Ask"
    plot sum [OrderQuantity] of orders with [OrderB/A = "Sell"]
  ]

  set-current-plot "Bid-Ask Spread"
  if(ticks >= 5000)[
    ifelse ((currentOrderAsk - currentOrderBid) / 2 >= 0)[
      plot (currentOrderAsk - currentOrderBid) / 2
    ][
      plot 0
    ]
  ]

  set-current-plot "Turnover Rate"
  if(ticks >= 5000)[
    plot (currentMAV / (sum [OrderQuantity] of orders with [OrderB/A = "Sell"] + 1))
  ]

  if(ticks >= 5000)[
    if((ticks mod 10) = 9)[
      set-current-plot "Aggressive Trades"
      plot (aggresiveBid - aggresiveAsk)
    ]
  ]

  if(ticks >= 5000)[
    set-current-plot "Averages Shared Owned"
    set-current-plot-pen "MM"
    plot avgSharesMarketMakers
    set-current-plot-pen "Demander"
    plot avgSharesLiquidityDemander
    set-current-plot-pen "Supplier"
    plot avgSharesLiquiditySupplier
    set-current-plot-pen "Forced"
    plot avgSharesForcedSale
  ]

  if(ticks >= 6000)[
    set-current-plot "Kyle Obizhaeva Measure"
    set-current-plot-pen "pen-0"
    let lPR length priceReturns
    ;plot (((sqrt(abs (item (lPR - 1) priceReturns)) * 15.87) / 0.02)*((2.08 / 10000)*((100 * (sqrt(abs (item (lPR - 1) priceReturns)) * 15.87) * (140 * currentMAV + 1)) / (0.02 * 40 * 1000000))^(-1 / 3) + (12.08 / 10000)*( 4 /(0.01 * (140 * currentMAV + 1)))^(0.5)))
    print (((sqrt(abs (item (lPR - 1) priceReturns)) * 15.87) / 0.02)*((2.08 / 10000)*((100 * (sqrt(abs (item (lPR - 1) priceReturns)) * 15.87) * (140 * currentMAV + 1)) / (0.02 * 40 * 1000000))^(-1 / 3) + (12.08 / 10000)*( 4 /(0.01 * (140 * currentMAV + 1)))^(0.5)))
  ]

  if(ticks >= 5000)[
    set-current-plot "Average Profit-Loss"
    set-current-plot-pen "MM"
    plot accountValueMarketMakers
    set-current-plot-pen "Demander"
    plot accountValueLiquidityDemander
    set-current-plot-pen "Supplier"
    plot accountValueLiquiditySupplier
  ]

end

;********************************************************************************************************************************************************************************
;Market Statisitics and Variables Reporters
;********************************************************************************************************************************************************************************

to-report volumeTraded
  report precision ((sum [totalBought + totalSold] of traders)) 0
end

to-report volumeCanceled
  report precision ((sum [totalCanceled] of traders)) 0
end

to-report day
  report (int (((ticks) / 60) + 9.5 - ((5000) / 60)) / 24 )
end

to-report hour
  ifelse (int (((ticks ) / 60) + 9.5 - ((5000) / 60))) mod 24 > 12 [ report (int (((ticks) / 60) + 9.5 - ((5000) / 60)) mod 24) - 12
    ][
      ifelse (int (((ticks ) / 60) + 9.5 - ((5000) / 60)) mod 24 = 0)[
        report 12
        ][
        report int (((ticks ) / 60) + 9.5 - ((5000) / 60)) mod 24]
    ]
end

to-report hourOutput
    report int (((ticks ) / 60) + 9.5 - ((5000) / 60))
end

to-report minute
  report int(((((ticks ) / 60) + 9.5 - ((5000) / 60)) mod 1)* 60)
end

to-report AMPM
    ifelse (int (((ticks) / 60) + 9.5 - ((5000) / 60))) mod 24 > 11 [ report "AM"
    ][
      report "PM"
    ]
end

;********************************************************************************************************************************************************************************
;Check Trader Account Number is Unique
;********************************************************************************************************************************************************************************

to checkTraderNumberUnique
  let countTradersintradelist length traderListNumbers - 1
  set traderNumber  10 + random 9990
  let countTraderNumber 0
  set checkTraderNumber 1
  loop [
   if(item countTraderNumber traderListNumbers = traderNumber)[set checkTraderNumber 0]
   if(countTraderNumber = countTradersintradelist) [stop]
   set countTraderNumber (countTraderNumber + 1)
  ]
end

to-report occurrences [x the-list]
  report reduce
    [ifelse-value (?2 = x) [?1 + 1] [?1]] (fput 0 the-list)
end

to-report frequency [val thelist]
  report length filter [? = val] thelist
end


@#$#@#$#@
GRAPHICS-WINDOW
534
759
945
1191
200
200
1.0
1
10
1
1
1
0
1
1
1
-200
200
-200
200
0
0
1
ticks
30.0

BUTTON
22
36
122
69
Setup Model
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
474
43
558
92
Price
(price / 4)
2
1
12

BUTTON
38
103
101
136
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
474
17
624
37
Market State
16
0.0
1

TEXTBOX
-17
308
1403
348
===============================================================================================================
16
0.0
1

SLIDER
792
58
982
91
#_Liquidity_Demander
#_Liquidity_Demander
0
250
250
1
1
NIL
HORIZONTAL

SLIDER
792
163
982
196
#_Market_Makers
#_Market_Makers
0
8
8
1
1
NIL
HORIZONTAL

TEXTBOX
823
34
1855
52
Numbers of Traders                              Trader Order Duration(Mins)               Trader Order Arrival Rate(Mins)                  Trader Order Size Multipler
12
0.0
1

SLIDER
1018
59
1234
92
liquidityDemanderTradeLength
liquidityDemanderTradeLength
30
600
60
30
1
NIL
HORIZONTAL

TEXTBOX
986
67
1017
87
 ---->\n\n
11
0.0
1

TEXTBOX
986
119
1016
195
\n---->\n   \n\n---->
11
0.0
1

PLOT
9
613
656
733
Price
Time (1 Min)
Price
0.0
10.0
95.0
105.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

PLOT
9
732
656
852
Volume
Time (10 Min)
Qty
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

PLOT
9
851
656
971
Volatility
Time (1 Hr)
NIL
0.0
10.0
0.0
0.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

MONITOR
599
731
656
776
Volume
int (totalVolume)
17
1
11

MONITOR
597
851
656
896
Volatility
precision (sqrt(abs (item ((length priceReturns) - 1) priceReturns)) * 15.87) 4
17
1
11

MONITOR
599
613
656
658
Price
(price / 4)
17
1
11

PLOT
10
971
655
1091
Ten Minute Moving Average Price
Time (10 Min))
MA Price
0.0
10.0
95.0
105.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

MONITOR
596
972
655
1017
MAP
precision currentMA  2
17
1
11

PLOT
10
1091
655
1211
Ten Minute Moving Average Volume
Time (1 Min)
NIL
0.0
10.0
0.0
5.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

MONITOR
598
1092
655
1137
MAV
precision currentMAV 2
17
1
11

PLOT
655
733
1304
853
Market Depth
Time (1 Min)
Qty
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Bid" 1.0 0 -16777216 true "" ""
"Ask" 1.0 0 -2674135 true "" ""

PLOT
655
613
1303
734
Bid-Ask Spread
Time (1 Min)
Spread Diff
0.0
10.0
0.0
5.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

PLOT
655
852
1304
972
Turnover Rate
Time (1 Min)
Volume/Stock
0.0
10.0
0.0
0.01
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

PLOT
655
1092
1306
1212
Price Returns
NIL
NIL
0.5
0.5
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

TEXTBOX
591
587
741
607
Market Measures
16
0.0
1

SLIDER
1019
163
1236
196
marketMakerTradeLength
marketMakerTradeLength
0
60
30
10
1
NIL
HORIZONTAL

MONITOR
186
43
236
88
H
hour
17
1
11

MONITOR
236
43
286
88
M
minute
17
1
11

TEXTBOX
233
12
383
30
Clock
16
0.0
1

TEXTBOX
1312
315
1332
1737
||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n||\n
11
0.0
1

PLOT
655
972
1305
1092
Aggressive Trades
Time (10 Min)
Qty
0.0
10.0
-2.0
2.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

TEXTBOX
-3
1349
1343
1384
==============================================================================================================
16
0.0
1

PLOT
291
134
760
302
Distribution of Bid/Ask
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Bid" 1.0 0 -16777216 true "" ""
"Ask" 1.0 0 -2674135 true "" ""

MONITOR
584
74
660
119
Current Ask
(currentOrderAsk / 4)
2
1
11

MONITOR
379
70
457
115
Current Bid
(currentOrderBid / 4)
2
1
11

MONITOR
13
214
146
259
Current Order ID
ordernumber
0
1
11

MONITOR
13
259
145
304
Number of Active Orders
count orders
0
1
11

TEXTBOX
958
98
1108
118
Behavior Traders
16
0.0
1

TEXTBOX
926
11
1141
51
Zero Intelligence Traders
16
0.0
1

MONITOR
288
43
345
88
AM/PM
AMPM
17
1
11

SWITCH
14
144
122
177
AuditTrail
AuditTrail
1
1
-1000

SLIDER
792
124
982
157
#_Liquidity_Supplier
#_Liquidity_Supplier
0
50
20
1
1
NIL
HORIZONTAL

SLIDER
1018
126
1236
159
liquiditySupplierTradeLength
liquiditySupplierTradeLength
0
1440
720
60
1
NIL
HORIZONTAL

TEXTBOX
1336
489
1682
741
Liquidity Demands:\nDistribution of Order Size\nProbability of Buying vs Selling\nNumber of Agents\n\nMarket Maker: \nDistrabution uniform of buy and selling on offered liquidity\nFunction of liquidity(inventory, shape(uniform), E(Liquidity Suppler Arrival Rate)\nNumber of Agents\nThe Inventory Limits are a finction of Balance Sheet conditions\n\nLarge Liquidity Suppler:\nArival Rate\nNumber of Agents\nDecision to Buy at what Price Funaction?
11
0.0
1

SLIDER
1481
338
1708
371
ProbabilityBuyofLiqyuidityDemander
ProbabilityBuyofLiqyuidityDemander
0
100
48.75
1
1
NIL
HORIZONTAL

SLIDER
1244
126
1460
159
liquidity_Supplier_Arrival_Rate
liquidity_Supplier_Arrival_Rate
0
1440
1440
60
1
NIL
HORIZONTAL

SLIDER
1242
59
1459
92
liquidity_Demander_Arrival_Rate
liquidity_Demander_Arrival_Rate
0
1440
120
60
1
NIL
HORIZONTAL

SLIDER
1243
163
1461
196
market_Makers_Arrival_Rate
market_Makers_Arrival_Rate
0
120
0
5
1
NIL
HORIZONTAL

MONITOR
136
43
186
88
D
day
0
1
11

PLOT
9
363
652
573
Averages Shared Owned
Time (1 Min)
Shares
0.0
10.0
-10.0
10.0
true
true
"" ""
PENS
"MM" 1.0 0 -16777216 true "" ""
"Demander" 1.0 0 -2674135 true "" ""
"Supplier" 1.0 0 -13840069 true "" ""
"Forced" 1.0 0 -8630108 true "" ""

TEXTBOX
574
329
724
349
Participant Measures
16
0.0
1

PLOT
652
363
1304
573
Average Profit-Loss
Time (1 Min)
$
0.0
10.0
-10.0
10.0
true
true
"" ""
PENS
"MM" 1.0 0 -16777216 true "" ""
"Demander" 1.0 0 -2674135 true "" ""
"Supplier" 1.0 0 -13840069 true "" ""

SLIDER
1474
125
1705
158
liquiditySupplierOrderSizeMultipler
liquiditySupplierOrderSizeMultipler
1
25
10
1
1
NIL
HORIZONTAL

SLIDER
1472
59
1705
92
liquidityDemanderOrderSizeMultipler
liquidityDemanderOrderSizeMultipler
1
10
1
1
1
NIL
HORIZONTAL

SLIDER
1474
163
1707
196
marketMakerOrderSizeMultipler
marketMakerOrderSizeMultipler
1
5
1
1
1
NIL
HORIZONTAL

TEXTBOX
1413
313
1785
341
Probability of Buy Order from Liquidity Demander
16
0.0
1

TEXTBOX
950
204
1100
224
Forced Sell Trader
16
0.0
1

INPUTBOX
782
246
867
306
QuntitySale
0
1
0
Number

INPUTBOX
880
246
1003
306
PeriodtoStartExecution
8000
1
0
Number

INPUTBOX
1015
246
1137
306
PeriodtoEndExecution
9440
1
0
Number

MONITOR
1146
247
1279
292
Duration of Execution
PeriodtoEndExecution - PeriodtoStartExecution
17
1
11

TEXTBOX
1360
385
1873
425
Percent Price Change per Order Size Multiple for Liquidity Supplier
16
0.0
1

SLIDER
1482
409
1709
442
PercentPriceChangetoOrderSizeMultiple
PercentPriceChangetoOrderSizeMultiple
0.25
5
2
0.25
1
NIL
HORIZONTAL

MONITOR
202
93
266
138
NIL
ticks
17
1
11

TEXTBOX
782
226
1299
271
Quantity to Sell      Tick Start Selling             Tick End Selling       Number of Period to Sell
12
0.0
1

MONITOR
1187
1092
1249
1137
Mean
mean(priceReturns)
4
1
11

MONITOR
1249
1092
1306
1137
StdDev
standard-deviation(priceReturns)
4
1
11

PLOT
655
1211
1306
1331
Daily Price
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

SLIDER
1501
477
1702
510
MarketMakerInventoryLimit
MarketMakerInventoryLimit
5
100
50
5
1
NIL
HORIZONTAL

TEXTBOX
1479
454
1741
472
Market Maker Inventory Constraint
16
0.0
1

SWITCH
124
144
232
177
DepthFile
DepthFile
0
1
-1000

SWITCH
67
178
175
211
AgentFile
AgentFile
1
1
-1000

TEXTBOX
1438
202
1543
222
Market Impact
16
0.0
1

INPUTBOX
1412
226
1483
286
MIQuantity
0
1
0
Number

INPUTBOX
1492
226
1565
286
MIPeriod
6000
1
0
Number

PLOT
10
1211
655
1331
Kyle Obizhaeva Measure
NIL
NIL
0.0
10.0
0.0
0.001
true
false
"" ""
PENS
"pen-0" 1.0 0 -7500403 true "" ""

INPUTBOX
1586
221
1741
281
privateViewPrice
110
1
0
Number

@#$#@#$#@
## ## WHAT IS IT?

This is a model of traders (agents) trading in futures market (OFR Exchange), placing orders in to a limit order book. The agents are constrcuted using the methodology in Paddrik et al. (2012). The agents are meant to represent 6 trading catagories. The 6 classes of agents are of:

Liquidity Demander -

Market Maker -

Liquidity Suppler -



## ## HOW IT WORKS

At the model set up with a given number of each types of traders and the amount of time they will leave an order into the market, before canceling it. The model is then run and at every tick each agent is examined to see if they can place an order or cancel/modify an order. The agent trading strategies determine what prices and quntites each agent will decided top place depending on market variables (price, moving average, depth of order book, ratio of order book, volatility, ....). The distriutions that are used in this version of the model represent agent decisions are meant to mimic those of true participants but for privcy concerns have been randomly adjusted.

The market is set up as a 'Price-Time Priority' basis. The highest bid order and the lowest ask order consitutes the best market for the given futures contract.

    - If it is a buy order it is matched against sell orders sorted by their price            followed by creation time.
    - If it is a sell order it is matched against buy orders sorted by their price            followed by creation time.

Agent specfic code can be examined by looking at the include button under the code tab. This will all you to see the underlying algorithms and functions that agents contain. This structure is meant to allow new agents to be introduced to the model with ease.

## ## HOW TO USE IT

Pressing the SETUP button will clear all transcations and initialize the traders.
Pressing the GO button will start the trades. Once the GO button is selected the traders are given the opportunitiy to place orders into the market before it opens, to fill the order book.

The 'Number of Traders' section allows you to use a slider bar to input the number of trades of each time they would like to see in the Market. The 'Time Between New Orders' slider can be used to determine the length a order is left in the limit order book for each trader type.

The 'Audit Trail' switch when On produces an audit trail of data that can be used to reconstruct events that occur in the simulated market. This is meant to be a mechanisum for researcher to examine the impact of types for traders with in the order book. The audit trail is a csv file titled "Orderbook" and will be located in the same directory as the netlogo file.


## ## CREDITS AND REFERENCES

Paddrik, M., Hayes, R., Todd, A., Yang, S., Scherer, W.  & Beling, P.  (2012).  An Agent-based Model of the E-Mini S&P 500 and the Flash Crash.  IEEE Computational Intelligence for Financial Engineering and Economics.

Paddrik, M., Hayes, R., Scherer, W.  & Beling, P.  (2014).  Effects of Limit Order Book Information Level on Market Stability Metrics.  OFR Working Paper Series.

Copyright 2014 Mark Paddrik, Roy Hayes, Andrew Todd
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.3.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="8" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100000"/>
    <metric>(price / 4)</metric>
    <metric>avgSharesLiquiditySupplier</metric>
    <metric>avgSharesMarketMakers</metric>
    <enumeratedValueSet variable="liquidity_Supplier_Arrival_Rate">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="AuditTrail">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidity_Demander_Arrival_Rate">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="QuntitySale">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PercentPriceChangetoOrderSizeMultiple">
      <value value="3.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidityDemanderTradeLength">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="marketMakerTradeLength">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquiditySupplierTradeLength">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ProbabilityBuyofLiqyuidityDemander">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PeriodtoEndExecution">
      <value value="8500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="#_Liquidity_Demander">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="#_Liquidity_Supplier">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquiditySupplierOrderSizeMultipler">
      <value value="14"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PeriodtoStartExecution">
      <value value="6500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="market_Makers_Arrival_Rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidityDemanderOrderSizeMultipler">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="marketMakerOrderSizeMultipler">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="#_Market_Makers">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Vary Quantity Sold" repetitions="20" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="9000"/>
    <metric>(price / 4)</metric>
    <metric>avgSharesLiquiditySupplier</metric>
    <metric>avgSharesMarketMakers</metric>
    <enumeratedValueSet variable="market_Makers_Arrival_Rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="#_Liquidity_Supplier">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="QuntitySale">
      <value value="0"/>
      <value value="500"/>
      <value value="1000"/>
      <value value="1500"/>
      <value value="2000"/>
      <value value="2500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidityDemanderOrderSizeMultipler">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="marketMakerOrderSizeMultipler">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquiditySupplierOrderSizeMultipler">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquiditySupplierTradeLength">
      <value value="240"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="#_Liquidity_Demander">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ProbabilityBuyofLiqyuidityDemander">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="marketMakerTradeLength">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="#_Market_Makers">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidity_Supplier_Arrival_Rate">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PeriodtoEndExecution">
      <value value="8440"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="AuditTrail">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidity_Demander_Arrival_Rate">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidityDemanderTradeLength">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PeriodtoStartExecution">
      <value value="7000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PercentPriceChangetoOrderSizeMultiple">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Vary Market Make Up to Shock" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="9000"/>
    <metric>(price / 4)</metric>
    <enumeratedValueSet variable="market_Makers_Arrival_Rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="#_Liquidity_Supplier">
      <value value="0"/>
      <value value="5"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="QuntitySale">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidityDemanderOrderSizeMultipler">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="marketMakerOrderSizeMultipler">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquiditySupplierOrderSizeMultipler">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquiditySupplierTradeLength">
      <value value="240"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="#_Liquidity_Demander">
      <value value="0"/>
      <value value="50"/>
      <value value="100"/>
      <value value="150"/>
      <value value="200"/>
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ProbabilityBuyofLiqyuidityDemander">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="marketMakerTradeLength">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="#_Market_Makers">
      <value value="0"/>
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidity_Supplier_Arrival_Rate">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PeriodtoEndExecution">
      <value value="8440"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="AuditTrail">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidity_Demander_Arrival_Rate">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidityDemanderTradeLength">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PeriodtoStartExecution">
      <value value="7000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PercentPriceChangetoOrderSizeMultiple">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Vary Market Make Up to Variance" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="9000"/>
    <metric>(price / 4)</metric>
    <enumeratedValueSet variable="market_Makers_Arrival_Rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="#_Liquidity_Supplier">
      <value value="0"/>
      <value value="5"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="QuntitySale">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidityDemanderOrderSizeMultipler">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="marketMakerOrderSizeMultipler">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquiditySupplierOrderSizeMultipler">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquiditySupplierTradeLength">
      <value value="240"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="#_Liquidity_Demander">
      <value value="0"/>
      <value value="50"/>
      <value value="100"/>
      <value value="150"/>
      <value value="200"/>
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ProbabilityBuyofLiqyuidityDemander">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="marketMakerTradeLength">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="#_Market_Makers">
      <value value="0"/>
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidity_Supplier_Arrival_Rate">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PeriodtoEndExecution">
      <value value="8440"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="AuditTrail">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidity_Demander_Arrival_Rate">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidityDemanderTradeLength">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PeriodtoStartExecution">
      <value value="7000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PercentPriceChangetoOrderSizeMultiple">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Vary Market Make Up to Shock of 1000" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="8500"/>
    <metric>(price / 4)</metric>
    <enumeratedValueSet variable="market_Makers_Arrival_Rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="#_Liquidity_Supplier">
      <value value="0"/>
      <value value="5"/>
      <value value="10"/>
      <value value="15"/>
      <value value="25"/>
      <value value="50"/>
      <value value="100"/>
      <value value="150"/>
      <value value="200"/>
      <value value="250"/>
      <value value="300"/>
      <value value="350"/>
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="QuntitySale">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidityDemanderOrderSizeMultipler">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="marketMakerOrderSizeMultipler">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquiditySupplierOrderSizeMultipler">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquiditySupplierTradeLength">
      <value value="240"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="#_Liquidity_Demander">
      <value value="0"/>
      <value value="50"/>
      <value value="100"/>
      <value value="150"/>
      <value value="200"/>
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ProbabilityBuyofLiqyuidityDemander">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="marketMakerTradeLength">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="#_Market_Makers">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidity_Supplier_Arrival_Rate">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PeriodtoEndExecution">
      <value value="8440"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="AuditTrail">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidity_Demander_Arrival_Rate">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidityDemanderTradeLength">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PeriodtoStartExecution">
      <value value="7000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PercentPriceChangetoOrderSizeMultiple">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment2526" repetitions="1000" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="#_Market_Makers">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquiditySupplierTradeLength">
      <value value="240"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="AuditTrail">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="marketMakerTradeLength">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidity_Supplier_Arrival_Rate">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PeriodtoStartExecution">
      <value value="7000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="DepthFile">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="QuntitySale">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="#_Liquidity_Supplier">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquiditySupplierOrderSizeMultipler">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="market_Makers_Arrival_Rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="marketMakerOrderSizeMultipler">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PeriodtoEndExecution">
      <value value="8440"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MarketMakerInventoryLimit">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="#_Liquidity_Demander">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidityDemanderOrderSizeMultipler">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PercentPriceChangetoOrderSizeMultiple">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidity_Demander_Arrival_Rate">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ProbabilityBuyofLiqyuidityDemander">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidityDemanderTradeLength">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Market Impact of Execution 25" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="7450"/>
    <metric>marketImpactValue</metric>
    <enumeratedValueSet variable="QuntitySale">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="#_Liquidity_Demander">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="market_Makers_Arrival_Rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidity_Demander_Arrival_Rate">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="AgentFile">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PeriodtoEndExecution">
      <value value="7440"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidityDemanderOrderSizeMultipler">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PeriodtoStartExecution">
      <value value="6000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ProbabilityBuyofLiqyuidityDemander">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="#_Liquidity_Supplier">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="marketMakerTradeLength">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MarketMakerInventoryLimit">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MIQuantity">
      <value value="0"/>
      <value value="5"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
      <value value="25"/>
      <value value="30"/>
      <value value="35"/>
      <value value="40"/>
      <value value="45"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="#_Market_Makers">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquiditySupplierTradeLength">
      <value value="240"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="marketMakerOrderSizeMultipler">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquiditySupplierOrderSizeMultipler">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidity_Supplier_Arrival_Rate">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="DepthFile">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="AuditTrail">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liquidityDemanderTradeLength">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MIPeriod">
      <value value="6000"/>
      <value value="6010"/>
      <value value="6020"/>
      <value value="6030"/>
      <value value="6040"/>
      <value value="6050"/>
      <value value="6060"/>
      <value value="6070"/>
      <value value="6080"/>
      <value value="6090"/>
      <value value="6100"/>
      <value value="6110"/>
      <value value="6120"/>
      <value value="6180"/>
      <value value="6240"/>
      <value value="6300"/>
      <value value="6360"/>
      <value value="6420"/>
      <value value="6480"/>
      <value value="6540"/>
      <value value="6600"/>
      <value value="6660"/>
      <value value="6720"/>
      <value value="6780"/>
      <value value="6840"/>
      <value value="6900"/>
      <value value="6960"/>
      <value value="7020"/>
      <value value="7080"/>
      <value value="7140"/>
      <value value="7200"/>
      <value value="7260"/>
      <value value="7320"/>
      <value value="7380"/>
      <value value="7440"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PercentPriceChangetoOrderSizeMultiple">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
