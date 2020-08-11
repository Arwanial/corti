//+------------------------------------------------------------------+
//|                                                        Corti.mq4 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Buy me a coffee"
#property link      "https://www.buymeacoffee.com/besibes"
#property version   "1.22"
#property strict
sinput string g1="[---]";//Group 1 :
input string M_Buys_A="GBPUSD,GBPJPY";//[1]Buy Pairs :
input string M_Sells_A="USDJPY,USDJPY";//[1]Sell Pairs :
sinput string g2="[---]";//Group 2 :
input string M_Buys_B="GBPUSD,GBPUSD";//[2]Buy Pairs :
input string M_Sells_B="EURUSD,EURGBP";//[2]Sell Pairs :
sinput string g3="[---]";//Group 3 :
input string M_Buys_C="";//[3]Buy Pairs :
input string M_Sells_C="";//[3]Sell Pairs :
int M_Magic=1;//Magic Number
input double M_TP=5;//Equity (of ea) take profit
input double M_Common_Cost_Per_Point=0.02;//Common Cost Per Point
 int M_Attempts=10;//Open Trade Attempts 
 uint M_Timeout=300;//Ms Timeout for Opening (milliseconds for attempts)
input string M_Comment="@macrofed";//Comment
 int M_Slippage=100;//Slippage in points
input int M_Restart_Minutes=360;//Minutes to restart  
 bool M_Add_Commision=true;//Added commision 
 bool M_Add_Swaps=true;//Added swap
 bool Cycle=true;//Cycle With Profit ? 
input bool DontTradeFriday=true;//Dont Trade Fridays (broker time)
enum timeused
{
time_local=0,//Local Time
time_broker=1//Broker Time 
};
 timeused FridayTimeUsed=time_broker;//Time used for checking Fridays 
 bool MondayBegin=true;//Begin trading on monday on hour below :
input int MondayHour=10;//Monday Hour to begin : 
 timeused MondayTimeUsed=time_broker;//Time used for checking Mondays

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
bool has_timer=false;
string system_folder="MMEA",system_objects="MMEA_";
struct cycle_texts
{
string sells,buys;
cycle_texts(void){sells=NULL;buys=NULL;}
};
cycle_texts Cycles[];
int CyclesTotal=0;
struct m_restart
{
datetime next_check_time;
bool armed,reverse;
int which_cycle;//non literal
int cycles_total;//for id
m_restart(void){cycles_total=0;which_cycle=0;next_check_time=0;armed=false;reverse=false;}
void Load(string folder,int magic)
     {
     string location=folder+"\\r"+IntegerToString(magic)+".mrz";
     if(FileIsExist(location))
       {
       int fop=FileOpen(location,FILE_READ|FILE_BIN);
       if(fop!=INVALID_HANDLE)
         {
         armed=false;
         next_check_time=0;
         char cc=(char)FileReadInteger(fop,CHAR_VALUE);
         if(cc==1) armed=true;
         reverse=false;
         cc=(char)FileReadInteger(fop,CHAR_VALUE);
         if(cc==1) reverse=true;
         if(armed){next_check_time=(datetime)FileReadDatetime(fop);}
         FileClose(fop);
         }
       }
     }
void Save(string folder,int magic)
     {
     string location=folder+"\\r"+IntegerToString(magic)+".mrz";
     if(FileIsExist(location)) FileDelete(location);
     int fop=FileOpen(location,FILE_WRITE|FILE_BIN);
     if(fop!=INVALID_HANDLE)
       {
       char cc=0;
       if(armed) cc=1;
       FileWriteInteger(fop,cc,CHAR_VALUE);
       cc=0;
       if(reverse) cc=1;
       FileWriteInteger(fop,cc,CHAR_VALUE);
       FileWriteLong(fop,next_check_time);
       FileClose(fop);
       }
     }
};
m_restart M;
bool MTAllow=false;
double system_profit=0,system_drawdown=0,system_drawup=0,max_drawdown=0,max_drawup=0;
int OnInit()
  {
//--- create timer
  MTAllow=false;
  has_timer=EventSetTimer(10);
  //load 
    M.Load(system_folder,M_Magic);
    M_Load();
    //prepare cycles
      ArrayFree(Cycles);
      CyclesTotal=0;
      //group 1
      if(M_Buys_A!=""||M_Sells_A!="")
      {
      CyclesTotal++;
      ArrayResize(Cycles,CyclesTotal,0);
      Cycles[CyclesTotal-1].buys=M_Buys_A;
      Cycles[CyclesTotal-1].sells=M_Sells_A;
      }
      //group 2
      if(M_Buys_B!=""||M_Sells_B!="")
      {
      CyclesTotal++;
      ArrayResize(Cycles,CyclesTotal,0);
      Cycles[CyclesTotal-1].buys=M_Buys_B;
      Cycles[CyclesTotal-1].sells=M_Sells_B;
      }  
      //group 3
      if(M_Buys_C!=""||M_Sells_C!="")
      {
      CyclesTotal++;
      ArrayResize(Cycles,CyclesTotal,0);
      Cycles[CyclesTotal-1].buys=M_Buys_C;
      Cycles[CyclesTotal-1].sells=M_Sells_C;
      }          
      //if difference between cycles total and loaded cycles ,reset current cycle
      if(CyclesTotal!=M.cycles_total)
      {
      M.cycles_total=CyclesTotal;
      M.reverse=false;
      M.which_cycle=1;
      }
    //prepare cycles ends here 
    if(TicketsTotal==0&&!M.armed)
      {
      MTAllow=CheckMTAllow();
      if(IsTradeAllowed()&&IsConnected()&&MTAllow) SplitAndTrade();
      if(!IsTradeAllowed()||!IsConnected()||!MTAllow)
        {
        FindNextInterval(M_Restart_Minutes);//retry after 5
        }
      }
   BuildDeck(clrDarkRed,clrCrimson,clrWhiteSmoke,BORDER_FLAT,ALIGN_LEFT);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
  if(has_timer) EventKillTimer();
  ArrayFree(Cycles);
  ArrayFree(Tickets);
  CyclesTotal=0;
  TicketsTotal=0;
  TicketsSize=0;
  TicketsStep=100;
  ObjectsDeleteAll(ChartID(),system_objects);  
  }
void BuildDeck(color back_col,color brd_col,color txt_col,ENUM_BORDER_TYPE brd_type,ENUM_ALIGN_MODE align)
  {
  int px=10;//position x
  int py=30;//position y
  int sx=200;//width
  int sy=20;//size of row
  int fs=12;//fontsize
  string objna=system_objects+"MAGIC";
  HS_Create_Btn(ChartID(),0,objna,sx,sy,px,py,"Arial",fs,back_col,brd_col,brd_type,txt_col,align,"",false,false);
  py+=sy;
  objna=system_objects+"TRADES_NO";
  HS_Create_Btn(ChartID(),0,objna,sx,sy,px,py,"Arial",fs,back_col,brd_col,brd_type,txt_col,align,"",false,false);
  py+=sy;
  objna=system_objects+"EQUITY";
  HS_Create_Btn(ChartID(),0,objna,sx,sy,px,py,"Arial",fs,back_col,brd_col,brd_type,txt_col,align,"",false,false);
  py+=sy;
  objna=system_objects+"MAX_DD";
  HS_Create_Btn(ChartID(),0,objna,sx,sy,px,py,"Arial",fs,back_col,brd_col,brd_type,txt_col,align,"",false,false);
  py+=sy;
  objna=system_objects+"MAD_DU";
  HS_Create_Btn(ChartID(),0,objna,sx,sy,px,py,"Arial",fs,back_col,brd_col,brd_type,txt_col,align,"",false,false);
  UpdateDeck();
  }

void UpdateDeck()
  {
  string objna=system_objects+"MAGIC";
  ObjectSetString(ChartID(),objna,OBJPROP_TEXT,"--[SYSTEM : "+IntegerToString(M_Magic)+" ]--");
  objna=system_objects+"TRADES_NO";
  ObjectSetString(ChartID(),objna,OBJPROP_TEXT,"Trades# : "+IntegerToString(TicketsTotal));
  objna=system_objects+"EQUITY";
  ObjectSetString(ChartID(),objna,OBJPROP_TEXT,"System EQ : "+DoubleToString(system_profit,2)+"$");
  objna=system_objects+"MAX_DD";
  ObjectSetString(ChartID(),objna,OBJPROP_TEXT,"MaxDrawDown : "+DoubleToString(max_drawdown,2)+"$");
  objna=system_objects+"MAX_DU";
  ObjectSetString(ChartID(),objna,OBJPROP_TEXT,"MaxDrawUp : "+DoubleToString(max_drawup,2)+"$");
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
  system_profit=0;
     for(int t=0;t<TicketsTotal;t++)
     {
     bool sel=OrderSelect(Tickets[t],SELECT_BY_TICKET);
     if(sel)
       {
       if(OrderCloseTime()==0&&OrderMagicNumber()==M_Magic)
         {
         system_profit+=OrderProfit();
         if(M_Add_Commision) system_profit+=OrderCommission();
         if(M_Add_Swaps) system_profit+=OrderSwap();
         }
       }
     } 
     if(system_profit<max_drawdown) max_drawdown=system_profit;
     if(system_profit>max_drawup) max_drawup=system_profit;
     if(TicketsTotal>0&&system_profit>=M_TP) CloseAll();
     UpdateDeck();
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
  if(TimeLocal()>M.next_check_time&&M.armed)
    {
    if(TicketsTotal==0)
      {
      MTAllow=CheckMTAllow();
      if(IsTradeAllowed()&&IsConnected()&&MTAllow) SplitAndTrade();
      if(!IsTradeAllowed()||!IsConnected()||!MTAllow)
        {
        FindNextInterval(M_Restart_Minutes);//retry after 5
        }
      }
    } 
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---
   
  }
//+------------------------------------------------------------------+
int Tickets[];
int TicketsTotal=0,TicketsSize=0,TicketsStep=100;
void M_Save()
{
string location=system_folder+"\\"+IntegerToString(M_Magic)+".mrz";
if(FileIsExist(location)) FileDelete(location);
if(TicketsTotal>0)
{
int fop=FileOpen(location,FILE_WRITE|FILE_BIN);
if(fop!=INVALID_HANDLE)
  {
  FileWriteArray(fop,Tickets,0,TicketsTotal);
  FileClose(fop);
  }
}
}

void M_Load()
{
string location=system_folder+"\\"+IntegerToString(M_Magic)+".mrz";
if(FileIsExist(location))
  {
  int ld[];
  int fop=FileOpen(location,FILE_READ|FILE_BIN);
  if(fop!=INVALID_HANDLE)
    {
    FileReadArray(fop,ld);
    FileClose(fop);
    int ld_total=ArraySize(ld);
    if(ld_total>0)
      {
      TicketsTotal=0;
      //check trades 
        for(int c=0;c<ld_total;c++)
        {
        bool select=OrderSelect(ld[c],SELECT_BY_TICKET);
        if(select)
          {
          if(OrderCloseTime()==0)
            {
            AddTicket(OrderTicket());
            }
          }
        }
      M_Save();
      //check trades ends here 
      }
    }
  }
}

void AddTicket(int ticket)
{
TicketsTotal++;
if(TicketsTotal>TicketsSize)
  {
  TicketsSize+=TicketsStep;
  ArrayResize(Tickets,TicketsSize,0);
  }
Tickets[TicketsTotal-1]=ticket;
}

//Split and trade 
void SplitAndTrade()
{
string buys[],sells[];
//get buy symbols
ushort usep=StringGetCharacter(",",0);
int to_buy=0,to_sell=0;
if(!M.reverse||!Cycle)
{
to_buy=StringSplit(Cycles[M.which_cycle-1].buys,usep,buys);
to_sell=StringSplit(Cycles[M.which_cycle-1].sells,usep,sells);
}
if(M.reverse&&Cycle)
{
to_sell=StringSplit(Cycles[M.which_cycle-1].buys,usep,sells);
to_buy=StringSplit(Cycles[M.which_cycle-1].sells,usep,buys);
}
bool GreenLight=true;
string Msg="OK";
//PASS A : MAKE SURE ALL ORDERS CAN OPEN ON SAME POINT VALUE
//Loop into buys 
  double margin_requirements=0;
  for(int b=0;b<to_buy;b++)
  {
  //formulate symbol
    string sy=buys[b];
    //get its data 
    double tvol=MarketInfo(sy,MODE_TICKVALUE);
    double minlot=MarketInfo(sy,MODE_MINLOT);
    double maxlot=MarketInfo(sy,MODE_MAXLOT);
    if(tvol<=0||minlot<=0||maxlot<=0){GreenLight=false;Msg="Cant acquire "+sy+" data!";break;}
    if(tvol>0&&minlot>0&&maxlot>0&&maxlot>minlot)
    {
    //projected lot 
      double projlot=M_Common_Cost_Per_Point/tvol;
      if(projlot<minlot){GreenLight=false;Msg="Cant Buy With Common Cost For "+sy+" .Increase 'Common Cost Per Point'";break;}
      if(projlot>maxlot){GreenLight=false;Msg="Cant Buy With Common Cost For "+sy+" .Decrease 'Common Cost Per Point'";break;}
      if(projlot<=0){GreenLight=false;Msg="Cant Buy With 0 Lot on "+sy+" .Increase 'Common Cost Per Point'";break;}
    projlot=CheckLot(sy,projlot);
    double this_margin=AccountFreeMargin()-AccountFreeMarginCheck(sy,OP_BUY,projlot);
    margin_requirements+=this_margin;
    }
  }
//Loop into buys 
//Loop into sells
  for(int s=0;s<to_sell;s++)
  {
  //formulate symbol
    string sy=sells[s];
    //get its data 
    double tvol=MarketInfo(sy,MODE_TICKVALUE);
    double minlot=MarketInfo(sy,MODE_MINLOT);
    double maxlot=MarketInfo(sy,MODE_MAXLOT);
    if(tvol<=0||minlot<=0||maxlot<=0){GreenLight=false;Msg="Cant acquire "+sy+" data!";break;}
    if(tvol>0&&minlot>0&&maxlot>0&&maxlot>minlot)
    {
    //projected lot 
      double projlot=M_Common_Cost_Per_Point/tvol;
      if(projlot<minlot){GreenLight=false;Msg="Cant Sell With Common Cost For "+sy+" .Increase 'Common Cost Per Point'";break;}
      if(projlot>maxlot){GreenLight=false;Msg="Cant Sell With Common Cost For "+sy+" .Decrease 'Common Cost Per Point'";break;}
      if(projlot<=0){GreenLight=false;Msg="Cant Sell With 0 Lot on "+sy+" .Increase 'Common Cost Per Point'";break;}
    double this_margin=AccountFreeMargin()-AccountFreeMarginCheck(sy,OP_BUY,projlot);
    margin_requirements+=this_margin;
    }
  }
//Loop into sells
//PASS A  : ENDS HERE 
//if Green light proceed
  if(GreenLight&&margin_requirements>=AccountFreeMargin()){GreenLight=false;Msg="Margin Required Is : "+DoubleToString(margin_requirements,2)+" of "+DoubleToString(AccountFreeMargin(),2);}
  if(GreenLight)
    {
    //Loop into buys 
    for(int b=0;b<to_buy;b++)
    {
    //formulate symbol
    string sy=buys[b];
    //get its data 
    double tvol=MarketInfo(sy,MODE_TICKVALUE);
    if(tvol>0)
    {
    //projected lot 
      double projlot=M_Common_Cost_Per_Point/tvol;
      bool trade=OpenOrder(sy,OP_BUY,projlot,M_Magic,M_Comment,M_Attempts,M_Timeout,M_Slippage,clrBlue);
    }
    }
   //Loop into buys 
   //Loop into sells
   for(int s=0;s<to_sell;s++)
   {
    //formulate symbol
    string sy=sells[s];
    //get its data 
    double tvol=MarketInfo(sy,MODE_TICKVALUE);
    if(tvol>0)
    {
    //projected lot 
      double projlot=M_Common_Cost_Per_Point/tvol;
      bool trade=OpenOrder(sy,OP_SELL,projlot,M_Magic,M_Comment,M_Attempts,M_Timeout,M_Slippage,clrRed);
    }
    }
    //Loop into sells    
    }
//if Green light proceed ends here 
Print("["+IntegerToString(M_Magic)+"] "+Msg);
if(!GreenLight){ExpertRemove();Alert("["+IntegerToString(M_Magic)+"] "+Msg);}
M_Save();
M.armed=false;
M.Save(system_folder,M_Magic);
}
//Split and trade ends here 

void CloseAll()
{
int ts=TicketsTotal-1;
bool ClosedEverything=true;
  for(int t=ts;t>=0;t--)
  {
  bool isClosed=CloseOrder(Tickets[t],M_Attempts,M_Timeout,M_Slippage);
  if(isClosed){Tickets[t]=Tickets[TicketsTotal-1];TicketsTotal--;}
  if(!isClosed){ClosedEverything=false;}
  }
if(ClosedEverything)
  {
  M.which_cycle++;
  if(M.which_cycle>M.cycles_total)
    {
    if(Cycle) M.reverse=!M.reverse;
    M.which_cycle=1;
    }
  FindNextInterval(M_Restart_Minutes);
  }
}

void FindNextInterval(int mins)
{ 
  if(mins==0){ExpertRemove();Alert("["+IntegerToString(M_Magic)+"] Exit After Profit");}
  if(mins>0)
    {
    M_Save();
    int secsadd=mins*60;
    M.next_check_time=TimeLocal()+secsadd;
    M.armed=true;
    M.Save(system_folder,M_Magic);
    }
}

bool CloseOrder(int ticket,int attempts,uint timeout,int slippage)
{
bool result=false;
int atts=0;
double cp=0;
while(!result&&atts<=attempts)
{
atts++;
bool select=OrderSelect(ticket,SELECT_BY_TICKET);
if(select)
  {
  ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderType();
  string symbol=OrderSymbol();
  double lots=OrderLots();
  if(OrderCloseTime()!=0) return(true);
  //buys
    if(type==OP_BUY&&OrderCloseTime()==0)
    {
    int digs=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
    cp=(double)NormalizeDouble(SymbolInfoDouble(symbol,SYMBOL_BID),digs);
    if(cp>0&&digs>0)
      {
      result=OrderClose(ticket,lots,cp,slippage,clrBlue);
      if(!result&&atts<attempts) Sleep(timeout);
      if(result) return(true);
      }
    }
  //sells 
    if(type==OP_SELL&&OrderCloseTime()==0)
    {
    int digs=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
    cp=(double)NormalizeDouble(SymbolInfoDouble(symbol,SYMBOL_ASK),digs);
    if(cp>0&&digs>0)
      {
      result=OrderClose(ticket,lots,cp,slippage,clrBlue);
      if(!result&&atts<attempts) Sleep(timeout);
      if(result) return(true);
      }
    }  
  }
}
return(result);
}

bool OpenOrder(string symbol,ENUM_ORDER_TYPE type,double lots,int magic,string comment,int attemps,uint timeout,int slippage,color col)
{
bool result=false;
int atts=0;
lots=CheckLot(symbol,lots);
int ticket=-1;
double op=0;
while(ticket==-1&&atts<=attemps)
 {
 atts++;
 if(type==OP_BUY)
   {
   int digs=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   op=(double)NormalizeDouble(SymbolInfoDouble(symbol,SYMBOL_ASK),digs);
   if(op>0&&digs>0)
     {
     ticket=OrderSend(symbol,OP_BUY,lots,op,slippage,0,0,comment,magic,0,col);
     if(ticket==-1&&atts<attemps) Sleep(timeout);
     if(ticket!=-1){result=true;AddTicket(ticket);}
     }
   }
 if(type==OP_SELL)
   {
   int digs=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   op=(double)NormalizeDouble(SymbolInfoDouble(symbol,SYMBOL_BID),digs);
   if(op>0&&digs>0)
     {
     ticket=OrderSend(symbol,OP_SELL,lots,op,slippage,0,0,comment,magic,0,col);
     if(ticket==-1&&atts<attemps) Sleep(timeout);
     if(ticket!=-1){result=true;AddTicket(ticket);}
     }
   }   
 }
return(result);
}

//CHECK LOT 
double CheckLot(string symbol,double lot)
{
double returnio=lot;
double max_lot=MarketInfo(symbol,MODE_MAXLOT);
double min_lot=MarketInfo(symbol,MODE_MINLOT);
int lot_digits=LotDigits(min_lot);
returnio=NormalizeDouble(returnio,lot_digits);
if(returnio<=min_lot) returnio=min_lot;
if(returnio>=max_lot) returnio=max_lot;
returnio=NormalizeDouble(returnio,lot_digits);
return(returnio);
}
//CHECK LOT ENDS HERE
//Find Lot Digits 
int LotDigits(double lot)
{
int returnio=0;
double digitos=0;
double transfer=lot;
while(transfer<1)
{
digitos++;
transfer=transfer*10;
} 
returnio=(int)digitos;
//Print("Lot ("+lot+") Digits "+digitos+" Returnio "+returnio);
return(returnio);
}

bool CheckMTAllow()
{
bool result=true;
//time used is broker time 
  datetime fritime=TimeLocal();
  if(FridayTimeUsed==time_broker) fritime=TimeCurrent();
  int day=TimeDayOfWeek(fritime);
  if(day==5&&DontTradeFriday) result=false;
  if(day==6) result=false;
//if its friday and no trading is allowed on fridays 
//monday check
  if(MondayBegin)
  {
  datetime montime=TimeLocal();
  if(MondayTimeUsed==time_broker) montime=TimeCurrent();
  day=TimeDayOfWeek(montime);
  int hour=TimeHour(montime);
  //if day is sunday ,block
    if(day==0) result=false;
  //if day is monday ,and before our hour ,block
    if(day==1&&hour<MondayHour) result=false;
  }
//monday check ends here 
return(result);
}
//CREATE BTN OBJECT
  void HS_Create_Btn(long cid,
                     int subw,
                     string name,
                     int sx,
                     int sy,
                     int px,
                     int py,
                     string font,
                     int fontsize,
                     color bck_col,
                     color brd_col,
                     ENUM_BORDER_TYPE brd_type,
                     color txt_col,
                     ENUM_ALIGN_MODE align,
                     string text,
                     bool selectable,
                     bool back)  
  {
  bool obji=ObjectCreate(cid,name,OBJ_BUTTON,subw,0,0);
  if(obji)
    {
    ObjectSetString(0,name,OBJPROP_FONT,font);
    ObjectSetInteger(0,name,OBJPROP_ALIGN,align);
    ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fontsize);
    ObjectSetInteger(0,name,OBJPROP_XSIZE,sx);
    ObjectSetInteger(0,name,OBJPROP_YSIZE,sy);
    ObjectSetInteger(0,name,OBJPROP_XDISTANCE,px);
    ObjectSetInteger(0,name,OBJPROP_YDISTANCE,py);
    ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bck_col);
    ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,brd_col);
    ObjectSetInteger(0,name,OBJPROP_COLOR,txt_col);
    ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,brd_type);
    ObjectSetInteger(0,name,OBJPROP_SELECTABLE,selectable);
    ObjectSetInteger(0,name,OBJPROP_BACK,back);
    ObjectSetString(0,name,OBJPROP_TEXT,text);
    }
  }                   
//CREATE BTN OBJECT ENDS HERE   
//CREATE INPUT OBJECT
  void HS_Create_Edit(long cid,
                     int subw,
                     string name,
                     int sx,
                     int sy,
                     int px,
                     int py,
                     string font,
                     int fontsize,
                     color bck_col,
                     color brd_col,
                     ENUM_BORDER_TYPE brd_type,
                     color txt_col,
                     ENUM_ALIGN_MODE align,
                     string text,
                     bool selectable,
                     bool readonly,
                     bool back)  
  {
  bool obji=ObjectCreate(cid,name,OBJ_EDIT,subw,0,0);
  if(obji)
    {
    ObjectSetString(0,name,OBJPROP_FONT,font);
    ObjectSetInteger(0,name,OBJPROP_ALIGN,align);
    ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fontsize);
    ObjectSetInteger(0,name,OBJPROP_XSIZE,sx);
    ObjectSetInteger(0,name,OBJPROP_YSIZE,sy);
    ObjectSetInteger(0,name,OBJPROP_XDISTANCE,px);
    ObjectSetInteger(0,name,OBJPROP_YDISTANCE,py);
    ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bck_col);
    ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,brd_col);
    ObjectSetInteger(0,name,OBJPROP_COLOR,txt_col);
    ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,brd_type);
    ObjectSetInteger(0,name,OBJPROP_SELECTABLE,selectable);
    ObjectSetInteger(0,name,OBJPROP_READONLY,readonly);
    ObjectSetInteger(0,name,OBJPROP_BACK,back);
    ObjectSetString(0,name,OBJPROP_TEXT,text);
    }
  }                   
//CREATE BTN OBJECT ENDS HERE 
