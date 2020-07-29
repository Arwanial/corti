# corti
Expert Advisor for MetaTrader 4 which trades correlated pairs .

- selection of direction of correlated pairs to trade
- one input field for global usd per pip value for pair
- immediate calculation of lots before entry 
- one input field for equity target 
- close in profit
- cooling time

Hard-coded are the settings i have been trading myself.
It has no Stop Loss because the profit stays floating when you trade correlated pairs.

Logic how it trades :
It can trade up to 3 groups of pairs.
- It trades Group 1 - closes in profit
- Waits cooling time
- Open trades of Group 2 - closes in profit
- Waits cooling time
- Open trades of Group 3 - closes in profit
- Waits cooling time
- <b>REVERSES TRADES DIRECTION OF Group 1,,,,,Group 2.....Group 3....and so on.</b>

