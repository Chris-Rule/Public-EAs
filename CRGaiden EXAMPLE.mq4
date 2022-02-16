//+------------------------------------------------------------------+
//|                                                     CRGaiden.mq4 |
//|                                              Christopher R. Rule |
//|                                     christopher.rule@outlook.com |
//+------------------------------------------------------------------+
#property copyright "Christopher R. Rule"
#property link      "Christopher.Rule@outlook.com"
#property version   "1.00"
#property strict


//+------------------------------------------------------------------+   
//--- Create Internal Parameters
//+------------------------------------------------------------------+

//General Parameters
   static datetime   ExpiryDate           = 0;
   static int        ExpiryCheckCount     = 0;
   static int        ExpiredAccount       = 0;
   static string     Reason               = "Manual close";
   static string     BotName              = "Gaiden";
   static string     BotVersion           = "1.00";

//Strategy logic parameters
   static bool       IsNewCandle          = false;
   static bool       IsNewExpiryCheck     = false;
   static int        SavedCandleTime;
   static int        SavedExpiryCheckTime; 
   static int        DailyMinuteOffset    = 5;
   static int        OrderNumber          = 0;
   static bool       FirstCandle          = true;
   static bool       TradedThisCandle     = false;
   static double     Saved_Upper_Bound    = 0;
   static double     Saved_Lower_Bound    = 0;
      
//Set up labels
   static double     Running_K_Result     = 50;
   static double     Running_D_Result     = 50;
   
//+------------------------------------------------------------------+
//--- Create External Parameters
//+------------------------------------------------------------------+
   

//Lot size controls
   extern bool       ClearChartData       = False;
   extern double     StartingLotSize      = 0.1;
   extern double     Starting_Upper_Bound = 0;
   extern double     Starting_Lower_Bound = 0;
   extern int        Slippage             = 50;
   extern int        MagicNumber          = 1;

//Stochastic Controls
   extern int        New_Buy_Level        = 14;
   extern int        New_Sell_Level       = 86;
   extern int        K_Period             = 25;
   extern int        D_Period             = 3;
   extern int        S_Period             = 3;
   
   
//+------------------------------------------------------------------+
//| Text Label Function
//    Function for implementing chart labels.
//+------------------------------------------------------------------+
void LabelFunction(const string CheckName,const string CheckText,const int VerticalOffset)
   {
      ObjectDelete   (CheckName);
      ObjectCreate   (ChartID(),CheckName,OBJ_LABEL,0,0,0);
      ObjectSetText  (CheckName,CheckName + " = " + (string)CheckText,10,"Verdana",White);
      ObjectSet      (CheckName,OBJPROP_CORNER,0);
      ObjectSet      (CheckName,OBJPROP_XDISTANCE,10);
      ObjectSet      (CheckName,OBJPROP_YDISTANCE,VerticalOffset);
   }
   
//+------------------------------------------------------------------+
//| Account Verification Function
//+------------------------------------------------------------------+
string AV_Function()
  {
   //Reset account verified status
   string AccVerified = "Unverified";
   
   //Account List : Account Number | Account Server | Broker | Expiry date.
   string Account_List[5][4] = {
      {(string)12345678,"Server01","Broker01",(string)D'2022.03.01 04:00'}, //01 CR PC Account
      {(string)12345678,"Server01","Broker01",(string)D'2022.03.01 04:00'}, //02 CR Demo 01
      {(string)12345678,"Server01","Broker01",(string)D'2022.03.01 04:00'}, //02 CR Demo 02
      {(string)12345678,"Server01","Broker01",(string)D'2022.03.01 04:00'}, //02 CR Demo 03
      {(string)12345678,"Server01","Broker01",(string)D'2022.03.01 04:00'}  //03 CR Demo 04
   };
   
   //Loop settings
   int    TotalAccounts = ArrayRange(Account_List,0); //Count number of accounts
   
   
   //Loop through accounts to check if account details can be verified.
   for(int x=0;x <= (TotalAccounts-1);x=x+1)
   {
      //Check account details
      if(AccountNumber() == (int)Account_List[x][0] && AccountServer() == (string)Account_List[x][1] && AccountCompany() == (string)Account_List[x][2])
      {
         //Check account has NOT expired
         if(TimeCurrent() < (datetime)Account_List[x][3])
         {
            AccVerified = "Verified";
            ExpiryDate     = (datetime)Account_List[x][3];
            break;
         }
         //Report expired account
         else
         {
            AccVerified    = "Expired";
            ExpiryDate     = (datetime)Account_List[x][3];
            ExpiredAccount = (int)Account_List[x][0];
            break;    
         }
      }    
   }
  
   //return result
   return AccVerified;

  }
  
//+------------------------------------------------------------------+
//| Log Creation                                                     |
//+------------------------------------------------------------------+  
void Log_Creation_Function()
  {
   ResetLastError();
   int filehandle=FileOpen("Sidewinder Bravo.csv",FILE_WRITE|FILE_CSV);
   if(filehandle!=INVALID_HANDLE)
     {
      FileWrite(filehandle,TimeCurrent(),Symbol(), EnumToString(ENUM_TIMEFRAMES(_Period)));
      FileClose(filehandle);
      Print("FileOpen OK");
     }
   else Print("Operation FileOpen failed, error ",GetLastError()); 
  }



//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   Alert(BotName," ",BotVersion," attempting to start");
   Log_Creation_Function();
   
   //Clear Chart
   if(ClearChartData == True)
   {
      ObjectsDeleteAll();
      Alert("Chart data cleared");
   }
   
   //Run account verification & check for expiry
   if(AV_Function() == "Verified")
   {
         Alert("Account details fully verified. ",BotName," ",BotVersion," has started succesfully with expiry date ",ExpiryDate);
         Print("Account details fully verified. ",BotName," ",BotVersion," has started succesfully with expiry date ",ExpiryDate);
   }
   else if(AV_Function() == "Expired")
   {
      Alert("This EA has expired after date ",ExpiryDate," on account ",ExpiredAccount,". Please contact your vendor.");
      ExpertRemove();
   } 
   else
   {
      Alert("Account number ", AccountNumber()," on account server ",AccountServer()," with broker ",AccountCompany()," is unverified. Please contact your vendor.");
      ExpertRemove();
   }
   
   //Set upper bounds
   Saved_Upper_Bound = Starting_Upper_Bound;
   Saved_Lower_Bound = Starting_Lower_Bound;
//---
   return(INIT_SUCCEEDED);
  }
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   Alert(BotName," ",BotVersion," has closed due to ",reason);
  }
  
  
   
//+------------------------------------------------------------------+
//| Open  new trades function                                        |
//+------------------------------------------------------------------+
void New_Trade_Function()
  {
  
   //Store Parameters
   double New_Trade_K_Result   = iStochastic(Symbol(),Period(),K_Period,D_Period,S_Period,MODE_SMA,0,MODE_MAIN,0);
   double New_Trade_D_Result   = iStochastic(Symbol(),Period(),K_Period,D_Period,S_Period,MODE_SMA,0,MODE_SIGNAL,0);
     
   //BUY TRADE CHECK
   
   //Determine BUY lot size
   double Buy_Lot_Size = StartingLotSize;
   
   //Prime buy position
   if(New_Trade_K_Result <= New_Buy_Level) //Check %K is below buy level
   {
      Saved_Lower_Bound = Ask;
      LabelFunction("Lower_Bound = ",(string)Saved_Lower_Bound,40);
      
      if(TradedThisCandle == false && Saved_Lower_Bound != 0)
      {
         //Traded this candle
         TradedThisCandle = true;
         
         //Set buy marker      
         if(!ObjectCreate(ChartID(),"Buy Marker " + (string)OrderNumber,OBJ_ARROW_BUY,0,TimeCurrent(),Ask))
         {
            Print("Error: can't create label. | code #",GetLastError());
         }
         ObjectSetInteger(ChartID(),"Buy Marker " + (string)OrderNumber,OBJPROP_COLOR,clrBlue);
      
         //Set buy order
         int buyticket = OrderSend(Symbol(),
                                     OP_BUY,
                                     Buy_Lot_Size,
                                     Ask,
                                     Slippage,
                                     Ask - ((Saved_Upper_Bound - Ask)/2),
                                     Ask + ((Saved_Upper_Bound - Ask)/2),
                                     "Opened by "+BotName,
                                     MagicNumber);
       
         if(buyticket < 0)
         {
            Alert(Symbol()," Error Sending Buy Order. | Code #",GetLastError());
            Print(Symbol()," Error Sending Buy Order. | Code #",GetLastError());
         }
         else
         {
            //Alert("Buy Trade Placed - K_Result = ",K_Result," | Buy level = ",New_Buy_Level);
            OrderNumber = OrderNumber +1;   
         }
      }  
   }
      
   
   //SELL TRADE CHECK
   
   //Determine SELL lot size
   double Sell_Lot_Size = StartingLotSize;
   
   //Check K position is above sell level
   if(New_Trade_K_Result >= New_Sell_Level)
   {
      //Update upper bound
      Saved_Upper_Bound = Bid;
      LabelFunction("Upper_Bound = ",(string)Saved_Upper_Bound,20); 
      
         //Check if K result is less than new sell level
      if(TradedThisCandle == false && Saved_Upper_Bound != 0)
      {
      
         //Traded this candle
         TradedThisCandle = true;
      
         //Set sell marker
         if(!ObjectCreate(ChartID(),"Sell Marker " + (string)OrderNumber,OBJ_ARROW_SELL,0,TimeCurrent(),Bid))
         {
            Print("Error: can't create label. | code #",GetLastError());
         }
         ObjectSetInteger(ChartID(),"Sell Marker " + (string)OrderNumber,OBJPROP_COLOR,clrRed);
      
         //Set sell order
         int sellticket = OrderSend(Symbol(),
                                     OP_SELL,
                                     Sell_Lot_Size,
                                     Bid,
                                     Slippage,
                                     Bid + ((Bid - Saved_Lower_Bound)/2),
                                     Bid - ((Bid - Saved_Lower_Bound)/2),
                                     "Opened by "+BotName,
                                     MagicNumber);
       
         if(sellticket < 0)
         {
            Alert(Symbol()," Error Sending Sell Order. | Code #",GetLastError());
            Print(Symbol()," Error Sending Sell Order. | Code #",GetLastError());
         }
         else
         {
            //Alert("Sell Trade Placed - K_Result = ",K_Result," | Sell level = ",New_Sell_Level);
            OrderNumber = OrderNumber +1;   
         }    
      }  
   } 
  } 

  
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---

//Store Time
   datetime CurrentTime = TimeCurrent(); 
   
//Report Time
   MqlDateTime    CTStr;
   TimeToStruct   (CurrentTime,CTStr);
   
//M5 Time Conditions
   if(Period() == PERIOD_M5)
   {
      if(CTStr.min == SavedCandleTime)
      {
         IsNewCandle = false;
      }
      else if(CTStr.min % 5 == 0)
      {
         SavedCandleTime = CTStr.min;
         IsNewCandle = true;
      }
      else
      {
         SavedCandleTime = CTStr.min;
      }
    }     
    
//Check for new candle 
   if(IsNewCandle == true)
   {
      //avoid erroneous trades from first time load
      if(FirstCandle == true)
      {
         FirstCandle = false;
      }
      else
      {
         //Refresh Rates & execute indicator functions
         RefreshRates();
         TradedThisCandle = false;
         
         //Test for traded this candle
         if(TradedThisCandle == false)
         {
            New_Trade_Function(); 
         } 
      }      
   } 
  }
//+------------------------------------------------------------------+
