//+------------------------------------------------------------------+
//|                                               mql5-connector.mq5 |
//|                             			 Copyright 2019, Imshar. |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, Imshar."
#property version   "1.00"

//inputs
input string Protocol = "tcp";       //Socket Protocol
input string Hostname = "127.0.0.1"; // Ip or Hostname
input uint   Port1    = 3033;        // Port 1
input uint   Port2    = 3034;        // Port 2
input uint   Port3    = 3035;        // Port 3

// Includes
#include <Zmq\Zmq.mqh>
#include <JAson.mqh>
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\DealInfo.mqh>

//Defines
#define forEach(index, array) for(int index=0; index<ArraySize(array); index++)

//vars
ZmqMsg request;
CJAVal json;
CTrade _trade;
CPositionInfo _posInfo;
COrderInfo _orderInfo;
CDealInfo _dealInfo;
int OnInit(){
   SocketServer::getInstance(Protocol, Hostname, Port1, Port2, Port3).connect();
   EventSetMillisecondTimer(1);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
   SocketServer::getInstance().destroy();
   BarEventStore::getInstance().destroy();
   TickEventStore::getInstance().destroy();
   EventKillTimer();
}

void OnTimer(){
   uint startTime = GetTickCount();
   SocketServer::getInstance().receive(request);
   if(request.size() > 0){
      json.Clear();
      bool deserialized = json.Deserialize(request.getData());
      if(deserialized){
         string result = handleEvents();
         SocketServer::getInstance().send(result);
      }
      uint endTime = GetTickCount();
      Print("executed in total time : ", (endTime - startTime), "'ms");
   }
   BarEventStore::getInstance().update();
   TickEventStore::getInstance().update();
}

string handleEvents(){
   string ename= json["event"].ToStr(); //event name
   CJAVal result;
   if(ename == "login_id"){ // account info category
      result[ename] = AccountInfoInteger(ACCOUNT_LOGIN);
      return result.Serialize();
   }else if(ename == "trade_mode"){
      ENUM_ACCOUNT_TRADE_MODE tradeMode = AccountInfoInteger(ACCOUNT_TRADE_MODE);
      string res;
      if(tradeMode == ACCOUNT_TRADE_MODE_DEMO){
         res = "DEMO";
      }else if(tradeMode == ACCOUNT_TRADE_MODE_REAL){
         res = "REAL";
      }else{
         res = "CONTEST";
      }
      result[ename] = res;
      return result.Serialize();
   }else if(ename == "leverage"){
      result[ename] = AccountInfoInteger(ACCOUNT_LEVERAGE);
      return result.Serialize();
   }else if(ename == "limit_orders"){
      result[ename] = AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);
      return result.Serialize();
   }else if(ename == "stopout_mode"){
      ENUM_ACCOUNT_STOPOUT_MODE so_mode = AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE);
      result[ename] = so_mode==ACCOUNT_STOPOUT_MODE_MONEY?"MONEY":"PERCENT";
      return result.Serialize();
   }else if(ename == "is_trade_allowed"){
      result[ename] = AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)?true:false;
      return result.Serialize();
   }else if(ename == "can_expert_trade"){
      result[ename] = AccountInfoInteger(ACCOUNT_TRADE_EXPERT)?true:false;
      return result.Serialize();
   }else if(ename == "margin_mode"){
      ENUM_ACCOUNT_MARGIN_MODE mm = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
      string res;
      if(mm == ACCOUNT_MARGIN_MODE_RETAIL_NETTING){
         res = "RETAIL_NETTING";
      }else if(mm == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING){
         res = "RETAIL_HEDGING";
      }else{
         res = "EXCHANGE";
      }
      result[ename] = res;
      return result.Serialize();
   }else if(ename == "account_currency_digit"){
      result[ename] = AccountInfoInteger(ACCOUNT_CURRENCY_DIGITS);
      return result.Serialize();
   }else if(ename == "balance"){
      result[ename] = AccountInfoDouble(ACCOUNT_BALANCE);
      return result.Serialize();
   }else if(ename == "credit"){
      result[ename] = AccountInfoDouble(ACCOUNT_CREDIT);
      return result.Serialize();
   }else if(ename == "profit"){
      result[ename] = AccountInfoDouble(ACCOUNT_PROFIT);
      return result.Serialize();
   }else if(ename == "equity"){
      result[ename] = AccountInfoDouble(ACCOUNT_EQUITY);
      return result.Serialize();
   }else if(ename == "margin"){
      result[ename] = AccountInfoDouble(ACCOUNT_MARGIN);
      return result.Serialize();
   }else if(ename == "margin_free"){
      result[ename] = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      return result.Serialize();
   }else if(ename == "margin_level"){
      result[ename] = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
      return result.Serialize();
   }else if(ename == "margin_so_call"){
      result[ename] = AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL);
      return result.Serialize();
   }else if(ename == "margin_so_so"){
      result[ename] = AccountInfoDouble(ACCOUNT_MARGIN_SO_SO);
      return result.Serialize();
   }else if(ename == "margin_maintenance"){
      result[ename] = AccountInfoDouble(ACCOUNT_MARGIN_MAINTENANCE);
      return result.Serialize();
   }else if(ename == "assets"){
      result[ename] = AccountInfoDouble(ACCOUNT_ASSETS);
      return result.Serialize();
   }else if(ename == "liabilities"){
      result[ename] = AccountInfoDouble(ACCOUNT_LIABILITIES);
      return result.Serialize();
   }else if(ename == "commision_blocked"){
      result[ename] = AccountInfoDouble(ACCOUNT_COMMISSION_BLOCKED);
      return result.Serialize();
   }else if(ename == "account_name"){
      result[ename] = AccountInfoString(ACCOUNT_NAME);
      return result.Serialize();
   }else if(ename == "account_server"){
      result[ename] = AccountInfoString(ACCOUNT_SERVER);
      return result.Serialize();
   }else if(ename == "account_currency"){
      result[ename] = AccountInfoString(ACCOUNT_CURRENCY);
      return result.Serialize();
   }else if(ename == "account_company"){
      result[ename] = AccountInfoString(ACCOUNT_COMPANY);
      return result.Serialize(); //end of account_info
   }else if(ename == "symbol_list"){
      for(int i=0; i<SymbolsTotal(false); i++){
         result[ename].Add(SymbolName(i, false));
      }
      return result.Serialize();
   }else if(ename == "sess_deals"){
      result[ename] = SymbolInfoInteger(json["symbol_name"].ToStr(), SYMBOL_SESSION_DEALS);
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "sess_buy_orders"){
      result[ename] = SymbolInfoInteger(json["symbol_name"].ToStr(), SYMBOL_SESSION_BUY_ORDERS);
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "sess_sell_orders"){
      result[ename] = SymbolInfoInteger(json["symbol_name"].ToStr(), SYMBOL_SESSION_SELL_ORDERS);
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "volume"){
      result[ename] = SymbolInfoInteger(json["symbol_name"].ToStr(), SYMBOL_VOLUME);
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "volume_high"){
      result[ename] = SymbolInfoInteger(json["symbol_name"].ToStr(), SYMBOL_VOLUMEHIGH);
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "volume_low"){
      result[ename] = SymbolInfoInteger(json["symbol_name"].ToStr(), SYMBOL_VOLUMELOW);
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "time"){
      result[ename] = SymbolInfoInteger(json["symbol_name"].ToStr(), SYMBOL_TIME);
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "digits"){
      result[ename] = SymbolInfoInteger(json["symbol_name"].ToStr(), SYMBOL_DIGITS);
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "is_spread_float"){
      result[ename] = SymbolInfoInteger(json["symbol_name"].ToStr(), SYMBOL_SPREAD_FLOAT)?true:false;
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "spread"){
      result[ename] = SymbolInfoInteger(json["symbol_name"].ToStr(), SYMBOL_SPREAD);
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "ticks_bookdepth"){
      result[ename] = SymbolInfoInteger(json["symbol_name"].ToStr(), SYMBOL_TICKS_BOOKDEPTH);
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "symbol_trade_mode"){
      string mode;
      ENUM_SYMBOL_TRADE_MODE tm = SymbolInfoInteger(json["symbol_name"].ToStr(), SYMBOL_TRADE_MODE);
      if(tm == SYMBOL_TRADE_MODE_FULL){
         mode = "FULL";
      }else if(tm == SYMBOL_TRADE_MODE_LONGONLY){
         mode = "LONG_ONLY";
      }else if(tm == SYMBOL_TRADE_MODE_SHORTONLY){
         mode = "SHORT_ONLY";
      }else if(tm == SYMBOL_TRADE_MODE_CLOSEONLY){
         mode = "CLOSE_ONLY";
      }else{
         mode = "DISABLED";
      }
      result[ename] = mode;
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "trade_stops_level"){
      result[ename] = SymbolInfoInteger(json["symbol_name"].ToStr(), SYMBOL_TRADE_STOPS_LEVEL);
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "trade_freeze_level"){
      result[ename] = SymbolInfoInteger(json["symbol_name"].ToStr(), SYMBOL_TRADE_FREEZE_LEVEL);
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "trade_exec_mode"){
      string mode;
      ENUM_SYMBOL_TRADE_EXECUTION tem = SymbolInfoInteger(json["symbol_name"].ToStr(), SYMBOL_TRADE_EXEMODE);
      if(tem == SYMBOL_TRADE_EXECUTION_REQUEST){
         mode = "REQUEST";
      }else if(tem == SYMBOL_TRADE_EXECUTION_INSTANT){
         mode = "INSTANT";
      }else if(tem == SYMBOL_TRADE_EXECUTION_MARKET){
         mode = "MARKET";
      }else{
         mode = "EXCHANGE";
      }
      result[ename] = mode;
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "swap_mode"){
      string mode;
      ENUM_SYMBOL_SWAP_MODE sm = SymbolInfoInteger(json["symbol_name"].ToStr(), SYMBOL_SWAP_MODE);
      if(sm == SYMBOL_SWAP_MODE_CURRENCY_DEPOSIT){
         mode = "CURRENCY_DEPOSIT";
      }else if(sm == SYMBOL_SWAP_MODE_CURRENCY_MARGIN){
         mode = "CURRENCY_MARGIN";
      }else if(sm == SYMBOL_SWAP_MODE_CURRENCY_SYMBOL){
         mode = "CURRENCY_SYMBOL";
      }else if(sm == SYMBOL_SWAP_MODE_INTEREST_CURRENT){
         mode = "INTEREST_CURRENT";
      }else if(sm == SYMBOL_SWAP_MODE_INTEREST_OPEN){
         mode = "INTEREST_OPEN";
      }else if(sm == SYMBOL_SWAP_MODE_POINTS){
         mode = "POINTS";
      }else if(sm == SYMBOL_SWAP_MODE_REOPEN_BID){
         mode = "REOPEN_BID";
      }else if(sm == SYMBOL_SWAP_MODE_REOPEN_CURRENT){
         mode = "REOPEN_CURRENT";
      }else{
         mode = "DISABLED";
      }
      result[ename] = mode;
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "ask"){
      result[ename] = SymbolInfoDouble(json["symbol_name"].ToStr(), SYMBOL_ASK);
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "bid"){
      result[ename] = SymbolInfoDouble(json["symbol_name"].ToStr(), SYMBOL_BID);
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "point"){
      result[ename] = SymbolInfoDouble(json["symbol_name"].ToStr(), SYMBOL_POINT);
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "vol_max"){
      result[ename] = SymbolInfoDouble(json["symbol_name"].ToStr(), SYMBOL_VOLUME_MAX);
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "vol_min"){
      result[ename] = SymbolInfoDouble(json["symbol_name"].ToStr(), SYMBOL_VOLUME_MIN);
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "vol_step"){
      result[ename] = SymbolInfoDouble(json["symbol_name"].ToStr(), SYMBOL_VOLUME_STEP);
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "swap_long"){
      result[ename] = SymbolInfoDouble(json["symbol_name"].ToStr(), SYMBOL_SWAP_LONG);
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "swap_short"){
      result[ename] = SymbolInfoDouble(json["symbol_name"].ToStr(), SYMBOL_SWAP_SHORT);
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "currency_base"){
      result[ename] = SymbolInfoString(json["symbol_name"].ToStr(), SYMBOL_CURRENCY_BASE);
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "currency_quote"){
      result[ename] = SymbolInfoString(json["symbol_name"].ToStr(), SYMBOL_CURRENCY_PROFIT);
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "currency_margin"){
      result[ename] = SymbolInfoString(json["symbol_name"].ToStr(), SYMBOL_CURRENCY_MARGIN);
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "broker"){
      result[ename] = SymbolInfoString(json["symbol_name"].ToStr(), SYMBOL_BANK);
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();
   }else if(ename == "description"){
      result[ename] = SymbolInfoString(json["symbol_name"].ToStr(), SYMBOL_DESCRIPTION);
      result["symbol_name"] = json["symbol_name"].ToStr();
      return result.Serialize();//end of symbol_info
   }else if(ename == "buy"){
      uint magic_number = json["magic"].ToInt(); // absolute integer value
      uint slippage = json["slippage"].ToInt(); // in points
      double vol = json["lot_size"].ToDbl();
      string symbol = json["symbol_name"].ToStr();
      double ask = json["price"].ToStr() == "latest" ? SymbolInfoDouble(symbol, SYMBOL_ASK) : json["price"].ToDbl();
      double tp = json["tp"].ToDbl() ; // in price
      double sl = json["sl"].ToDbl(); // in price
      string comment = json["comment"].ToStr();
      _trade.SetDeviationInPoints(slippage);
      _trade.SetExpertMagicNumber(magic_number);
      bool res = _trade.Buy(vol, symbol, ask, sl, tp, comment);
      if(res){
         result[ename] = getLastPositionTicket(magic_number, symbol, POSITION_TYPE_BUY);
         result["symbol_name"] = symbol;
         return result.Serialize();
      }else{
         result[ename] = "error";
         result["symbol_name"] = symbol;
         return result.Serialize();
      }
   }else if(ename == "buy_stop"){
      uint magic_number = json["magic"].ToInt(); // absolute integer value
      uint slippage = json["slippage"].ToInt(); // in points
      double vol = json["lot_size"].ToDbl();
      string symbol = json["symbol_name"].ToStr();
      double price = json["price"].ToDbl();
      double tp = json["tp"].ToDbl() ; // in price
      double sl = json["sl"].ToDbl(); // in price
      string comment = json["comment"].ToStr();
      _trade.SetDeviationInPoints(slippage);
      _trade.SetExpertMagicNumber(magic_number);
      bool res = _trade.BuyStop(vol, price, symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
      if(res){
         result[ename] = getLastOrderTicket(magic_number, symbol, ORDER_TYPE_BUY_STOP);
         result["symbol_name"] = symbol;
         return result.Serialize();
      }else{
         result[ename] = "error";
         result["symbol_name"] = symbol;
         return result.Serialize();
      }
   }else if(ename == "buy_limit"){
      uint magic_number = json["magic"].ToInt(); // absolute integer value
      uint slippage = json["slippage"].ToInt(); // in points
      double vol = json["lot_size"].ToDbl();
      string symbol = json["symbol_name"].ToStr();
      double price = json["price"].ToDbl();
      double tp = json["tp"].ToDbl() ; // in price
      double sl = json["sl"].ToDbl(); // in price
      string comment = json["comment"].ToStr();
      _trade.SetDeviationInPoints(slippage);
      _trade.SetExpertMagicNumber(magic_number);
      bool res = _trade.BuyLimit(vol, price, symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
      if(res){
         result[ename] = getLastOrderTicket(magic_number, symbol, ORDER_TYPE_BUY_LIMIT);
         result["symbol_name"] = symbol;
         return result.Serialize();
      }else{
         result[ename] = "error";
         result["symbol_name"] = symbol;
         return result.Serialize();
      }
   }else if(ename == "sell"){
      uint magic_number = json["magic"].ToInt(); // absolute integer value
      uint slippage = json["slippage"].ToInt(); // in points
      double vol = json["lot_size"].ToDbl();
      string symbol = json["symbol_name"].ToStr();
      double bid = json["price"].ToStr() == "latest" ? SymbolInfoDouble(symbol, SYMBOL_BID) : json["price"].ToDbl();
      double tp = json["tp"].ToDbl() ; // in price
      double sl = json["sl"].ToDbl(); // in price
      string comment = json["comment"].ToStr();
      _trade.SetDeviationInPoints(slippage);
      _trade.SetExpertMagicNumber(magic_number);
      bool res = _trade.Sell(vol, symbol, bid, sl, tp, comment);
      if(res){
         result[ename] = getLastPositionTicket(magic_number, symbol, POSITION_TYPE_SELL);
         result["symbol_name"] = symbol;
         return result.Serialize();
      }else{
         result[ename] = "error";
         result["symbol_name"] = symbol;
         return result.Serialize();
      }
   }else if(ename == "sell_stop"){
      uint magic_number = json["magic"].ToInt(); // absolute integer value
      uint slippage = json["slippage"].ToInt(); // in points
      double vol = json["lot_size"].ToDbl();
      string symbol = json["symbol_name"].ToStr();
      double price = json["price"].ToDbl();
      double tp = json["tp"].ToDbl() ; // in price
      double sl = json["sl"].ToDbl(); // in price
      string comment = json["comment"].ToStr();
      _trade.SetDeviationInPoints(slippage);
      _trade.SetExpertMagicNumber(magic_number);
      bool res = _trade.SellStop(vol, price, symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
      if(res){
         result[ename] = getLastOrderTicket(magic_number, symbol, ORDER_TYPE_SELL_STOP);
         result["symbol_name"] = symbol;
         return result.Serialize();
      }else{
         result[ename] = "error";
         result["symbol_name"] = symbol;
         return result.Serialize();
      }
   }else if(ename == "sell_limit"){
      uint magic_number = json["magic"].ToInt(); // absolute integer value
      uint slippage = json["slippage"].ToInt(); // in points
      double vol = json["lot_size"].ToDbl();
      string symbol = json["symbol_name"].ToStr();
      double price = json["price"].ToDbl();
      double tp = json["tp"].ToDbl() ; // in price
      double sl = json["sl"].ToDbl(); // in price
      string comment = json["comment"].ToStr();
      _trade.SetDeviationInPoints(slippage);
      _trade.SetExpertMagicNumber(magic_number);
      bool res = _trade.SellLimit(vol, price, symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
      if(res){
         result[ename] = getLastOrderTicket(magic_number, symbol, ORDER_TYPE_SELL_LIMIT);
         result["symbol_name"] = symbol;
         return result.Serialize();
      }else{
         result[ename] = "error";
         result["symbol_name"] = symbol;
         return result.Serialize();
      }
   }else if(ename == "modify_position"){
      ulong ticket = json["ticket"].ToInt();
      double sl = json["sl"].ToDbl();
      double tp = json["tp"].ToDbl();
      bool res = _trade.PositionModify(ticket, sl, tp);
      result[ename] = res;
      return result.Serialize();
   }else if(ename == "modify_order"){
      ulong ticket = json["ticket"].ToInt();
      double price = json["price"].ToDbl();
      double sl = json["sl"].ToDbl();
      double tp = json["tp"].ToDbl();
      bool res = _trade.OrderModify(ticket, price, sl, tp, ORDER_TIME_GTC, 0);
      result[ename] = res;
      return result.Serialize();
   }else if(ename == "delete_position"){
      ulong ticket = json["ticket"].ToInt();
      bool res = _trade.PositionClose(ticket);
      result[ename] = res;
      return result.Serialize();
   }else if(ename == "delete_order"){
      ulong ticket = json["ticket"].ToInt();
      bool res = _trade.OrderDelete(ticket);
      result[ename] = res;
      return result.Serialize();
   }else if(ename == "total_pos_info"){
      for(int i=0; i<PositionsTotal(); i++){
         result[ename].Add(getPosTicketInfo(i));
      }
      return result.Serialize();
   }else if(ename == "total_order_info"){
      for(int i=0; i<OrdersTotal(); i++){
         result[ename].Add(getOrderTicketInfo(i));
      }
      return result.Serialize();
   }else if(ename == "total_history_info"){
      HistorySelect(0, TimeCurrent());
      for(int i=0; i<HistoryDealsTotal(); i++){
         result[ename].Add(getHistoryTicketInfo(i));
      }
      return result.Serialize();
   }else if(ename == "bar_history"){
      string symbol = json["symbol_name"].ToStr();
      string timeframe = json["timeframe"].ToStr();
      datetime fromDate = StringToTime(json["from_date"].ToStr());
      datetime toDate = StringToTime(json["to_date"].ToStr());
      MqlRates rates[];
      int copied = CopyRates(symbol, toTimeframeEnum(timeframe), fromDate, toDate, rates);
      if(copied){
         result["symbol_name"] = symbol;
         result["timeframe"] = timeframe;
         forEach(i, rates){
            CJAVal js;
            js["time"] = TimeToString(rates[i].time);
            js["open"] = rates[i].open;
            js["high"] = rates[i].high;
            js["low"] = rates[i].low;
            js["close"] = rates[i].close;
            js["volume"] = rates[i].tick_volume;
            js["spread"] = rates[i].spread;
            result[ename].Add(js);
         }
         return result.Serialize();
      }else{
         result[ename] = "";
         return result.Serialize();
      }
   }else if(ename == "bar_event_sub"){ // subscribe to on bars event
      string symbol = json["symbol_name"].ToStr();
      string timeframe = json["timeframe"].ToStr();
      int historyCount = json["history_count"].ToInt();
      BarEventStore::getInstance().subscribeEvent(symbol, timeframe, historyCount);
      result[ename] = true;
      return result.Serialize();
   }else if(ename == "bar_event_unsub"){
      string symbol = json["symbol_name"].ToStr();
      string timeframe = json["timeframe"].ToStr();
      int historyCount = json["history_count"].ToInt();
      BarEventStore::getInstance().unsubscribeEvent(symbol, timeframe, historyCount);
      result[ename] = true;
      return result.Serialize();
   }else if(ename == "tick_event_sub"){
      string symbol = json["symbol_name"].ToStr();
      int historyCount = json["history_count"].ToInt();
      TickEventStore::getInstance().subscribeEvent(symbol, historyCount);
   }else if(ename == "ticket_event_unsub"){
      string symbol = json["symbol_name"].ToStr();
      int historyCount = json["history_count"].ToInt();
      TickEventStore::getInstance().unsubscribeEvent(symbol, historyCount);
   }
   return "{}";
}



CJAVal getPosTicketInfo(int index){
   CJAVal js;
   _posInfo.SelectByIndex(index);
   js["ticket"] = (long) _posInfo.Ticket();
   js["time"] = TimeToString(_posInfo.Time());
   js["update_time"] = TimeToString(_posInfo.TimeUpdate());
   js["pos_type"] = _posInfo.TypeDescription();
   js["magic"] = _posInfo.Magic();
   js["pos_id"] = _posInfo.Identifier();
   js["lot_size"] = _posInfo.Volume();
   js["open_price"] = _posInfo.PriceOpen();
   js["sl"] = _posInfo.StopLoss();
   js["tp"] = _posInfo.TakeProfit();
   js["current_price"] = _posInfo.PriceCurrent();
   js["commission"] = _posInfo.Commission();
   js["swap"] = _posInfo.Swap();
   js["profit"] = _posInfo.Profit();
   js["symbol"] = _posInfo.Symbol();
   js["comment"] = _posInfo.Comment();
   return js;
}

CJAVal getOrderTicketInfo(int index){
   CJAVal js;
   _orderInfo.SelectByIndex(index);
   js["ticket"] = (long)_orderInfo.Ticket();
   js["time_setup"] = TimeToString(_orderInfo.TimeSetup());
   js["order_type"] = _orderInfo.TypeDescription();
   js["state"] = _orderInfo.StateDescription();
   js["time_done"] = TimeToString(_orderInfo.TimeDone());
   js["type_filling"] = _orderInfo.TypeFillingDescription();
   js["type_time"] = _orderInfo.TypeTimeDescription();
   js["magic"] = _orderInfo.Magic();
   js["pos_id"] = _orderInfo.PositionId();
   js["initial_volume"] = _orderInfo.VolumeInitial();
   js["current_volume"] = _orderInfo.VolumeCurrent();
   js["open_price"] = _orderInfo.PriceOpen();
   js["sl"] = _orderInfo.StopLoss();
   js["tp"] = _orderInfo.TakeProfit();
   js["current_price"] = _orderInfo.PriceCurrent();
   js["symbol"] = _orderInfo.Symbol();
   js["comment"] = _orderInfo.Comment();
   return js;
}

CJAVal getHistoryTicketInfo(int index){
   CJAVal js;
   _dealInfo.SelectByIndex(index);
   js["ticket"] = (long) _dealInfo.Ticket();
   js["time"] = TimeToString(_dealInfo.Time());
   js["deal_type"] = _dealInfo.TypeDescription();
   js["magic"] = _dealInfo.Magic();
   js["pos_id"] = _dealInfo.PositionId();
   js["volume"] = _dealInfo.Volume();
   js["entry_type"] = _dealInfo.EntryDescription();
   js["symbol"] = _dealInfo.Symbol();
   js["comment"] = _dealInfo.Comment();
   js["swap"] = _dealInfo.Swap();
   js["commission"] = _dealInfo.Commission();
   js["price"] = _dealInfo.Price();
   js["profit"] = _dealInfo.Profit();
   return js;
}

long getLastPositionTicket(long magic, string symbol, ENUM_POSITION_TYPE posType){
   for(int i=PositionsTotal() - 1 ; i >= 0; i--){
      _posInfo.SelectByIndex(i);
      if(magic == _posInfo.Magic() && symbol == _posInfo.Symbol() && posType == _posInfo.PositionType()){
         return _posInfo.Ticket();
      }
   }
   return -1;
}

long getLastOrderTicket(long magic, string symbol, ENUM_ORDER_TYPE orderType){
   for(int i=OrdersTotal()-1; i>=0; i--){
      _orderInfo.SelectByIndex(i);
      if(magic == _orderInfo.Magic() && symbol == _orderInfo.Symbol() && orderType == _orderInfo.OrderType()){
         return _orderInfo.Ticket();
      }
   }
   return -1;
}

ENUM_TIMEFRAMES toTimeframeEnum(string timeframeStr){
   if(timeframeStr == "M1"){
      return PERIOD_M1;
   }else if(timeframeStr == "M2"){
      return PERIOD_M2;
   }else if(timeframeStr == "M3"){
      return PERIOD_M3;
   }else if(timeframeStr == "M4"){
      return PERIOD_M4;
   }else if(timeframeStr == "M5"){
      return PERIOD_M5;
   }else if(timeframeStr == "M6"){
      return PERIOD_M6;
   }else if(timeframeStr == "M10"){
      return PERIOD_M10;
   }else if(timeframeStr == "M12"){
      return PERIOD_M12;
   }else if(timeframeStr == "M15"){
      return PERIOD_M15;
   }else if(timeframeStr == "M20"){
      return PERIOD_M20;
   }else if(timeframeStr == "M30"){
      return PERIOD_M30;
   }else if(timeframeStr == "H1"){
      return PERIOD_H1;
   }else if(timeframeStr == "H2"){
      return PERIOD_H2;
   }else if(timeframeStr == "H3"){
      return PERIOD_H3;
   }else if(timeframeStr == "H4"){
      return PERIOD_H4;
   }else if(timeframeStr == "H6"){
      return PERIOD_H6;
   }else if(timeframeStr == "H8"){
      return PERIOD_H8;
   }else if(timeframeStr == "H12"){
      return PERIOD_H12;
   }else if(timeframeStr == "D1"){
      return PERIOD_D1;
   }else if(timeframeStr == "W1"){
      return PERIOD_W1;
   }else if(timeframeStr == "MN1"){
      return PERIOD_MN1;
   }else{
      return Period();
   }
}

class SocketServer{
   private:
   static SocketServer *_instance;
   string pushAddress, pullAddress, pubAddress;
   Context *_context;
   Socket *_pushSocket, *_pullSocket, *_pubSocket;
   private:
   SocketServer(const SocketServer &socketServer){}
   SocketServer(){}
   SocketServer(string protcol, string hostname, uint push_port, uint pull_port, uint pub_port){
      pushAddress = StringFormat("%s://%s:%d", protcol, hostname, pull_port);
      pullAddress = StringFormat("%s://%s:%d", protcol, hostname, push_port);
      pubAddress  = StringFormat("%s://%s:%d", protcol, hostname, pub_port);
   }
   
   public:
   static SocketServer *getInstance(string protcol="tcp", string hostname="127.0.0.1", uint push_port=3033, uint pull_port=3034, uint pub_port=3035){
      if(_instance == NULL){
         _instance = new SocketServer(protcol, hostname, push_port, pull_port, pub_port);
      }
      return _instance;
   }
   
   SocketServer connect(){
      _context    = new Context("mql_connector");
      _pushSocket = new Socket(_context, ZMQ_PUSH);
      _pullSocket = new Socket(_context, ZMQ_PULL);
      _pubSocket  = new Socket(_context, ZMQ_PUB);
      if(_pushSocket.bind(pushAddress)){
         Print("Push Server running successfully");
      }else{
         Print("Push Server error, check your input address");
      }
      if(_pullSocket.bind(pullAddress)){
         Print("Pull Server running successfully");
      }else{
         Print("Pull Server error, check your input address");
      }
      if(_pubSocket.bind(pubAddress)){
         Print("Pub Server running successfully");
      }else{
         Print("Pub Server error, check your input address");
      }
      int hwm = 1;
      _pushSocket.setSendHighWaterMark(hwm);
      _pushSocket.setLinger(hwm);
      _pullSocket.getReceiveHighWaterMark(hwm);
      _pullSocket.getLinger(hwm);
      _pubSocket.setSendHighWaterMark(hwm);
      _pubSocket.setLinger(hwm);
      return _instance;
   }
   
   void send(string event, string msg){
      string data = event + " " + msg;
      _pubSocket.send(data, true);
   }
   
   void send(string msg){
      _pushSocket.send(msg, true);
   }
   
   void receive(ZmqMsg &msg){
      _pullSocket.recv(msg, true);
   }
   
   void destroy(){
      _pushSocket.unbind(pushAddress);
      _pullSocket.unbind(pullAddress);
      _pubSocket.unbind(pubAddress);
      _context.shutdown();
      _context.destroy(0);
      if(_pushSocket){
         delete _pushSocket;
      }
      if(_pullSocket){
         delete _pullSocket;
      }
      if(_pubSocket){
         delete _pubSocket;
      }
      if(_instance){
         delete _instance;
      }
   }
   
};
SocketServer *SocketServer::_instance = NULL;

template<typename T>
class List{
   private:
   T _array[];
   int _size;
   
   public:
   List(int initialSize = 5){
      ArrayResize(_array, initialSize);
      _size = 0;
   }
   
   ~List(){
      _size = 0;
      ArrayFree(_array);
   }
   
   void add(T value){
      expandCapacity();
      _array[_size] = value;
      _size++;
   }
   
   void addAll(T &values[]){
      for(int i=0; i<ArraySize(values); i++){
         add(values[i]);
      }
   }
   
   T get(int index){
      return _array[index];
   }
   
   void set(int index, T &value){
      _array[index] = value;
   }
   
   void remove(int index){
      shiftValues(index);
      _size--;
   }
   
   int capacity(){
      return ArraySize(_array);
   }
   
   int size(){
      return _size;
   }
   
   string toString(){
      string str = "[";
      for(int i=0; i<_size; i++){
         str += _array[i];
         if(i < _size - 1){
            str += ", ";
         }
      }
      str += "]";
      return str;
   }
   
   private:
   void expandCapacity(){
      if(_size >= ArraySize(_array)){
         int newSize = ArraySize(_array) + MathCeil(ArraySize(_array) * 0.5);
         ArrayResize(_array, newSize);
      }
   }
   
   void shiftValues(int fromIndex){
      for(int i=fromIndex; i<_size; i++){
         _array[i] = _array[i+1];
      }
   }
};

class BarEventStore{
   private:
   static BarEventStore *_instance;
   List<string> *symbolList;
   List<string> *periodList;
   List<int> *barCountList;
   List<datetime> *oldDateList;
   
   BarEventStore(){
      symbolList = new List<string>();
      periodList = new List<string>();
      barCountList = new List<int>();
      oldDateList = new List<datetime>();
   }
   
   public:
   static BarEventStore *getInstance(){
      if(_instance == NULL){
         _instance = new BarEventStore();
      }
      return _instance;
   }
   
   void subscribeEvent(string symbol, string timeframe, int historyCount){
      bool isFound = false;
      for(int i=0; i<symbolList.size(); i++){
         if(symbolList.get(i) == symbol && periodList.get(i) == timeframe && barCountList.get(i) == historyCount){
            isFound = true;
         }
      }
      if(isFound){
         return;
      }
      symbolList.add(symbol);
      periodList.add(timeframe);
      barCountList.add(historyCount);
      oldDateList.add(NULL);
   }
   
   void unsubscribeEvent(string symbol, string timeframe, int historyCount){
      for(int i=0; i < symbolList.size(); i++){
         if(symbolList.get(i) == symbol && periodList.get(i) == timeframe && barCountList.get(i) == historyCount){
            symbolList.remove(i);
            periodList.remove(i);
            barCountList.remove(i);
            oldDateList.remove(i);
         }
      }
   }
   
   void update(){
      for(int i=0; i < symbolList.size(); i++){
         if(isNewBar(i)){
            SocketServer::getInstance().send(getEventName(i), getHistoryData(i));
         }
      }
   }
   
   string getEventName(int index){
      return symbolList.get(index) + "_" + periodList.get(index) + "_" + barCountList.get(index);
   }
   
   string getSymbol(int index){
      return symbolList.get(index);
   }
   
   ENUM_TIMEFRAMES getTimeframe(int index){
      return toTimeframeEnum(periodList.get(index));
   }
   
   int getBarCount(int index){
      return barCountList.get(index);
   }
   
   int size(){
      return symbolList.size();
   }
   
   void destroy(){
      if(_instance){
         delete _instance;
      }
      if(symbolList){
         delete symbolList;
      }
      if(periodList){
         delete periodList;
      }
      if(barCountList){
         delete barCountList;
      }
      if(oldDateList){
         delete oldDateList;
      }
   }
   
   private:
   bool isNewBar(int index){
      datetime new_time[];
      int copied = CopyTime(symbolList.get(index), toTimeframeEnum(periodList.get(index)), 0, 1, new_time);
      if(copied){
         if(oldDateList.get(index) != new_time[0]){
            oldDateList.set(index, new_time[0]);
            return true;
         }
      }
      return false;
   }
   
   string getHistoryData(int index){
      MqlRates rates[];
      int copied = CopyRates(symbolList.get(index), toTimeframeEnum(periodList.get(index)), 0, barCountList.get(index), rates);
      if(copied){
         CJAVal result;
         string eventName = getEventName(index);
         forEach(i, rates){
            CJAVal js;
            js["time"] = TimeToString(rates[i].time);
            js["open"] = rates[i].open;
            js["high"] = rates[i].high;
            js["low"] = rates[i].low;
            js["close"] = rates[i].close;
            js["volume"] = rates[i].tick_volume;
            js["spread"] = rates[i].spread;
            result[eventName].Add(js);
         }
         return result.Serialize();
      }
      return "{}";
   }
};
BarEventStore *BarEventStore::_instance = NULL;

class TickEventStore{
   private:
   static TickEventStore *_instance;
   List<string> *symbolList;
   List<int> *tickCountList;
   List<long> *oldTimeList;
   
   TickEventStore(){
      symbolList = new List<string>();
      tickCountList = new List<int>();
      oldTimeList = new List<long>();
   }
   
   public:
   static TickEventStore *getInstance(){
      if(_instance == NULL){
         _instance = new TickEventStore();
      }
      return _instance;
   }
   
   void subscribeEvent(string symbol, int historyCount){
      symbolList.add(symbol);
      tickCountList.add(historyCount);
      oldTimeList.add(0);
   }
   
   void unsubscribeEvent(string symbol, int historyCount){
      for(int i=0; i<symbolList.size(); i++){
         if(symbolList.get(i) == symbol && tickCountList.get(i) == historyCount){
            symbolList.remove(i);
            tickCountList.remove(i);
            oldTimeList.remove(i);
         }
      }
   }
   
   void update(){
      for(int i=0; i<symbolList.size(); i++){
         if(isNewTick(i)){
            SocketServer::getInstance().send(getEventName(i), getTickHistory(i));
         }
      }
   }
   
   string getEventName(int index){
      return symbolList.get(index) + "_" + tickCountList.get(index);
   }
   
   string getSymbol(int index){
      return symbolList.get(index);
   }
   
   int getTickCount(int index){
      return tickCountList.get(index);
   }
   
   int size(){
      return symbolList.size();
   }
   
   void destroy(){
      if(_instance){
         delete _instance;
      }
      if(symbolList){
         delete symbolList;
      }
      if(tickCountList){
         delete tickCountList;
      }
      if(oldTimeList){
         delete oldTimeList;
      }
   }
   
   private:
   bool isNewTick(int index){
      MqlTick new_tick[];
      int copied = CopyTicks(symbolList.get(index), new_tick, COPY_TICKS_ALL, 0, 1);
      if(copied){
         if(oldTimeList.get(index) != new_tick[0].time_msc){
            oldTimeList.set(index, new_tick[0].time_msc);
            return true;
         }
      }
      return false;
   }
   
   string getTickHistory(int index){
      MqlTick ticks[];
      int copied = CopyTicks(symbolList.get(index), ticks, COPY_TICKS_ALL, 0, tickCountList.get(index));
      if(copied){
         CJAVal result;
         string event_name = getEventName(index);
         forEach(i, ticks){
            CJAVal js;
            js["ask"] = ticks[i].ask;
            js["bid"] = ticks[i].bid;
            js["flags"] = tickFlagToString(ticks[i].flags);
            js["last"] = ticks[i].last;
            js["time"] = TimeToString(ticks[i].time);
            js["time_msc"] = ticks[i].time_msc;
            js["volume"] = (long)ticks[i].volume;
            result[event_name].Add(js);
         }
         return result.Serialize();
      }
      return "{}";
   }
   
   string tickFlagToString(uint flags){
      switch(flags){
         case TICK_FLAG_ASK:
         return "ASK";
         case TICK_FLAG_BID:
         return "BID";
         case TICK_FLAG_BUY:
         return "BUY";
         case TICK_FLAG_SELL:
         return "SELL";
         case TICK_FLAG_LAST:
         return "LAST";
         case TICK_FLAG_VOLUME:
         return "VOLUME";
         default:
         return "NONE";
      }
   }
};
TickEventStore *TickEventStore::_instance = NULL;