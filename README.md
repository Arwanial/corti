# corti
This is an Expert Advisor for MetaTrader 4 which is designed to trade correlated pairs .

- Buy/Sell your preferred correlated pairs . 
- Take profit in currency (not pips)
- "Common Cost Per Point" automatically calculates lot before entering the trade .
- Minutes to restart after closing in profit
- Cycle=true;//Cycle With Profit ? - rotates order directions of the groups
- Dont Trade Fridays (broker time) true/false

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

ForexFactory thread for discussions and tests : https://www.forexfactory.com/thread/post/13103685#post13103685
