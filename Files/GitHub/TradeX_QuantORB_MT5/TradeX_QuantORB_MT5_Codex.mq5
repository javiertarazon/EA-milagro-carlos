//+------------------------------------------------------------------+
//|                                       TradeX_QuantORB_MT5.mq5    |
//|              Opening Range Breakout (ORB) - Prop Firm EA         |
//|              Filtros: ATR + RVOL | Gestión de Riesgo Auto        |
//+------------------------------------------------------------------+
#property copyright "QuantORB"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>

//--- GRUPO: HORARIO DEL RANGO DE APERTURA (ORB)
input group "=== RANGO DE APERTURA (ORB) ==="
input int      InpORBStartHour = 16;        // Hora inicio ORB (hora del broker)
input int      InpORBStartMin  = 30;       // Minuto inicio ORB
input int      InpORBEndHour   = 16;        // Hora fin ORB (hora del broker)
input int      InpORBEndMin    = 45;       // Minuto fin ORB
input bool     InpUseEODClose  = true;     // Cerrar posiciones al final del día
input int      InpCloseHour    = 23;       // Hora cierre EOD (broker)
input int      InpCloseMin     = 55;        // Minuto cierre EOD

//--- GRUPO: FILTROS CUALITATIVOS (ATR + RVOL)
input group "=== FILTROS ATR Y RVOL ==="
input bool     InpUseATRFilter  = false;   // ¿Usar filtro ATR?
input ENUM_TIMEFRAMES InpATRTimeframe = PERIOD_H1; // Timeframe del ATR
input int      InpATRPeriod     = 14;      // Período ATR
input double   InpATRMultiplier = 1.0;     // Multiplicador vs media ATR (1.0 = igual)

input bool     InpUseRVOLFilter = false;   // ¿Usar filtro RVOL?
input int      InpRVOLPeriod    = 20;      // Período media de volumen
input double   InpRVOLMultiplier= 1.5;     // Volumen actual >= X veces la media

//--- GRUPO: GESTIÓN DE RIESGO Y LÍMITES
input group "=== GESTIÓN DE RIESGO ==="
input double   InpRiskPercent   = 1.0;     // Riesgo por operación (% del balance)
input double   InpSLBufferPoints  = 2.0;     // Buffer extra para SL (en puntos)
input double   InpTPRatio       = 2.0;     // Ratio Take Profit / Stop Loss
input double   InpMinSLPoints   = 10.0;    // Distancia mínima del SL (puntos) | evita lotes enormes al entrar pegado al rango
input double   InpMaxMarginPct  = 40.0;    // Máx. % de margen libre usado por posición (carga de margen en el gráfico)
input int      InpMaxTradesDay  = 2;       // Máximo operaciones por día
input double   InpMaxDailyLoss  = -500;    // Pérdida máxima diaria ($) | 0 = desactivado
input bool     InpCloseOnDailyLoss = true; // ¿Cerrar posiciones al tocar pérdida diaria?

//--- GRUPO: CONFIGURACIÓN GENERAL
input group "=== GENERAL ==="
input ulong    InpMagicNumber   = 178558;  // Magic Number
input int      InpSlippage      = 50;      // Slippage máximo (puntos)
input string   InpTradeComment  = "ORB";   // Comentario en órdenes
input bool     InpShowORBPanel  = false;   // ¿Dibujar niveles ORB en el gráfico?
input int      InpRetryAttempts = 3;       // Reintentos de envío de orden (mínimo 1)
input int      InpRetryDelayMs  = 250;     // Pausa entre reintentos (ms)
input int      InpRetryCooldownSec = 60;   // Enfriamiento tras orden fallida (seg)

//--- GRUPO: BREAKEVEN Y TRAILING STOP
input group "=== BREAKEVEN Y TRAILING ==="
input bool     InpUseBreakEven    = true;    // ¿Mover SL a la entrada al estar en ganancia?
input double   InpBEActivatePoints  = 8;       // Tope activación BE (puntos); máx. 50% del camino al TP
input double   InpBEPlusPoints      = 2;       // Buffer del BE sobre la entrada (puntos)
input bool     InpUseTrailing     = true;    // ¿Usar Trailing Stop?
input double   InpTrailStartPoints  = 12;      // Tope inicio trailing (puntos); máx. 75% del camino al TP
input double   InpTrailDistPoints   = 6;       // Distancia del SL al precio al trailear (puntos)
input double   InpTrailStepPoints   = 3;       // Paso mínimo para mover el SL (puntos)
input int      InpTrailCooldownSec = 10;     // Espera mínima entre modificaciones de SL (seg)

//--- GRUPO: SEÑALES Y VISUALES
input group "=== SEÑALES Y VISUALES ==="
input bool     InpDrawSignals   = false;   // ¿Dibujar flechas en entradas?
input color    InpColorBuy      = clrLime; // Color flecha COMPRA
input color    InpColorSell     = clrRed;  // Color flecha VENTA
input bool     InpShowEMAs      = false;   // ¿Dibujar EMAs en el gráfico?
input int      InpEMAFast       = 9;       // EMA rápida
input int      InpEMAMedium     = 21;      // EMA media
input int      InpEMASlow       = 50;      // EMA lenta
input color    InpColorEMAFast  = clrDodgerBlue; // Color EMA rápida
input color    InpColorEMAMedium= clrOrange;      // Color EMA media
input color    InpColorEMASlow  = clrMagenta;     // Color EMA lenta

//--- Variables Globales
CTrade         m_trade;
datetime       g_orb_start = 0;
datetime       g_orb_end = 0;
double         g_orb_high = 0;
double         g_orb_low = 0;
bool           g_orb_formed = false;
bool           g_long_taken = false;
bool           g_short_taken = false;
int            g_daily_trades = 0;
datetime       g_today_date = 0;
double         g_point = 0;
int            g_digits = 0;

int            g_atr_handle = INVALID_HANDLE;
bool           g_daily_loss_hit = false;
datetime       g_last_fail_time = 0;
datetime       g_last_sl_modify = 0;

int            g_ema_f = INVALID_HANDLE;
int            g_ema_m = INVALID_HANDLE;
int            g_ema_s = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetDeviationInPoints(InpSlippage);
   m_trade.SetAsyncMode(false);

   // Detectar el modo de ejecución permitido por el broker
   uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      m_trade.SetTypeFilling(ORDER_FILLING_IOC);
   else
      m_trade.SetTypeFilling(ORDER_FILLING_RETURN);

   g_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(g_point == 0)
   {
      Alert("Error: No se pudo obtener el POINT del símbolo");
      return INIT_FAILED;
   }

   // Validación básica de inputs
   if(InpORBEndHour * 60 + InpORBEndMin <= InpORBStartHour * 60 + InpORBStartMin)
   {
      Alert("Error: El fin del rango ORB debe ser posterior al inicio.");
      return INIT_FAILED;
   }
   if(InpRiskPercent <= 0)
   {
      Alert("Error: InpRiskPercent debe ser mayor que 0.");
      return INIT_FAILED;
   }

   // Handle del ATR para el filtro de volatilidad
   if(InpUseATRFilter)
   {
      g_atr_handle = iATR(_Symbol, InpATRTimeframe, InpATRPeriod);
      if(g_atr_handle == INVALID_HANDLE)
      {
         Alert("Advertencia: No se pudo crear el indicador ATR. Filtro ATR desactivado.");
         g_atr_handle = INVALID_HANDLE;
      }
   }

   // Handles EMA para visualización
   if(InpShowEMAs)
   {
      g_ema_f = iMA(_Symbol, PERIOD_M1, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
      g_ema_m = iMA(_Symbol, PERIOD_M1, InpEMAMedium, 0, MODE_EMA, PRICE_CLOSE);
      g_ema_s = iMA(_Symbol, PERIOD_M1, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   }

   g_orb_start = TimeFromHMS(InpORBStartHour, InpORBStartMin);
   g_orb_end   = TimeFromHMS(InpORBEndHour, InpORBEndMin);
   UpdateEMAObjects();
   ChartRedraw(0);
   Print("=== QuantORB EA Iniciado en ", _Symbol, " | Magic ", InpMagicNumber, " ===");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_atr_handle != INVALID_HANDLE)
      IndicatorRelease(g_atr_handle);
   DeleteORBObjects();
   DeleteEMAObjects();
   Print("=== QuantORB EA Detenido (razón ", reason, ") ===");
}

//+------------------------------------------------------------------+
//| Puntos de activación BE: fijo pero nunca más del 50% del camino  |
//| hacia el TP (se adapta al tamaño real de cada operación)         |
//+------------------------------------------------------------------+
double GetBETriggerPips(double entry, double tp)
{
   if(tp <= 0 || g_point <= 0)
      return(0);
   double tpDistPips = MathAbs(tp - entry) / g_point;
   double autoPips   = tpDistPips * 0.50;
   return(MathMin(InpBEActivatePoints, autoPips));
}

//+------------------------------------------------------------------+
//| Puntos de inicio del trailing: fijo pero nunca más del 75% del   |
//| camino hacia el TP                                               |
//+------------------------------------------------------------------+
double GetTrailTriggerPips(double entry, double tp)
{
   if(tp <= 0 || g_point <= 0)
      return(0);
   double tpDistPips = MathAbs(tp - entry) / g_point;
   double autoPips   = tpDistPips * 0.75;
   return(MathMin(InpTrailStartPoints, autoPips));
}

//+------------------------------------------------------------------+
//| Breakeven + Trailing Stop: asegura ganancia y arrastra el SL     |
//+------------------------------------------------------------------+
void ManageBreakEvenAndTrailing()
{
   if(!InpUseBreakEven && !InpUseTrailing)
      return;

   // Cooldown entre modificaciones (evita spam de peticiones de SL al servidor y "Invalid stops")
   if(g_last_sl_modify > 0 && TimeCurrent() - g_last_sl_modify < InpTrailCooldownSec)
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double minStop = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * g_point;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;

      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL = PositionGetDouble(POSITION_SL);
      double curTP = PositionGetDouble(POSITION_TP);
      long   type  = PositionGetInteger(POSITION_TYPE);
      double newSL = 0;
      bool   move  = false;

      if(type == POSITION_TYPE_BUY)
      {
         double profitPips = (bid - entry) / g_point;

         // 1) Breakeven: SL a la entrada (+buffer) una vez hay ganancia suficiente
         if(InpUseBreakEven && profitPips >= GetBETriggerPips(entry, curTP))
         {
            double beSL = entry + InpBEPlusPoints * g_point;
            if(curSL < beSL)
            {
               newSL = beSL;
               move  = true;
            }
         }

         // 2) Trailing: arrastrar el SL detrás del precio, solo si mejora
         if(InpUseTrailing && profitPips >= GetTrailTriggerPips(entry, curTP))
         {
            double trailSL = bid - InpTrailDistPoints * g_point;
            if(trailSL > curSL + InpTrailStepPoints * g_point)
            {
               newSL = trailSL;
               move  = true;
            }
         }

         // Validar distancia mínima al mercado antes de modificar
         if(move && newSL > curSL && newSL <= bid - minStop)
         {
            if(m_trade.PositionModify(ticket, NormalizeDouble(newSL, g_digits), curTP))
            {
               g_last_sl_modify = TimeCurrent();
               PrintFormat("BUY #%I64u: SL movido a %.5f (BE/Trailing)", ticket, newSL);
            }
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double profitPips = (entry - ask) / g_point;

         // 1) Breakeven
         if(InpUseBreakEven && profitPips >= GetBETriggerPips(entry, curTP))
         {
            double beSL = entry - InpBEPlusPoints * g_point;
            if(curSL > beSL || curSL == 0)
            {
               newSL = beSL;
               move  = true;
            }
         }

         // 2) Trailing
         if(InpUseTrailing && profitPips >= GetTrailTriggerPips(entry, curTP))
         {
            double trailSL = ask + InpTrailDistPoints * g_point;
            if(trailSL < curSL - InpTrailStepPoints * g_point)
            {
               newSL = trailSL;
               move  = true;
            }
         }

         // Validar distancia mínima al mercado antes de modificar
         if(move && (curSL == 0 || newSL < curSL) && newSL >= ask + minStop)
         {
            if(m_trade.PositionModify(ticket, NormalizeDouble(newSL, g_digits), curTP))
            {
               g_last_sl_modify = TimeCurrent();
               PrintFormat("SELL #%I64u: SL movido a %.5f (BE/Trailing)", ticket, newSL);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Dibuja flecha verde (compra) o roja (venta) en cada entrada      |
//+------------------------------------------------------------------+
void DrawSignalArrow(ENUM_ORDER_TYPE type, long ticket)
{
   if(!InpDrawSignals)
      return;
   double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   string nm = StringFormat("QB_%s_%I64d", (type == ORDER_TYPE_BUY ? "B" : "S"), ticket);
   if(ObjectFind(0, nm) < 0)
   {
      ObjectCreate(0, nm, OBJ_ARROW, 0, TimeCurrent(), price);
      ObjectSetInteger(0, nm, OBJPROP_ARROWCODE, (type == ORDER_TYPE_BUY) ? 233 : 234);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, (type == ORDER_TYPE_BUY) ? InpColorBuy : InpColorSell);
      ObjectSetInteger(0, nm, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
   }
}

//+------------------------------------------------------------------+
//| Actualiza las líneas EMA (9/21/50) con colores en el gráfico     |
//+------------------------------------------------------------------+
void UpdateEMAObjects()
{
   if(!InpShowEMAs || g_orb_start <= 0)
      return;
   UpdateEMALine("QB_EMAF", g_ema_f, InpColorEMAFast);
   UpdateEMALine("QB_EMAM", g_ema_m, InpColorEMAMedium);
   UpdateEMALine("QB_EMAS", g_ema_s, InpColorEMASlow);
}

void UpdateEMALine(string name, int handle, color clr)
{
   if(handle == INVALID_HANDLE)
      return;
   int shift0 = iBarShift(_Symbol, PERIOD_M1, g_orb_start, false);
   if(shift0 < 0 || iTime(_Symbol, PERIOD_M1, shift0) > TimeCurrent())
      shift0 = iBarShift(_Symbol, PERIOD_M1, g_orb_start - 86400, false);
   if(shift0 < 0)
      return;
   double ema[2];
   double e0[], e1[];
   if(CopyBuffer(handle, 0, shift0, 1, e0) < 1)
      return;
   if(CopyBuffer(handle, 0, 0, 1, e1) < 1)
      return;
   ema[0] = e0[0]; ema[1] = e1[0];
   datetime t0 = iTime(_Symbol, PERIOD_M1, shift0);
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_TREND, 0, 0, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t0);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, ema[0]);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, TimeCurrent());
   ObjectSetDouble(0, name, OBJPROP_PRICE, 1, ema[1]);
}

void DeleteEMAObjects()
{
   if(g_ema_f != INVALID_HANDLE)
   {
      IndicatorRelease(g_ema_f);
      g_ema_f = INVALID_HANDLE;
   }
   if(g_ema_m != INVALID_HANDLE)
   {
      IndicatorRelease(g_ema_m);
      g_ema_m = INVALID_HANDLE;
   }
   if(g_ema_s != INVALID_HANDLE)
   {
      IndicatorRelease(g_ema_s);
      g_ema_s = INVALID_HANDLE;
   }
   ObjectDelete(0, "QB_EMAF");
   ObjectDelete(0, "QB_EMAM");
   ObjectDelete(0, "QB_EMAS");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   datetime now = TimeCurrent();

   // --- Reset del estado diario ---
   ResetDailyIfNeeded(now);

   // --- Actualizar el rango de apertura si estamos dentro de la ventana ---
   if(!g_orb_formed && now >= g_orb_start && now < g_orb_end)
      UpdateORBRange();

   // --- Cerrar el rango al terminar la ventana ---
   if(!g_orb_formed && now >= g_orb_end)
   {
      g_orb_formed = true;
      PrintFormat("ORB formado: High=%.5f Low=%.5f", g_orb_high, g_orb_low);
   }

   // --- Cierre EOD (fin de día) ---
   if(InpUseEODClose && now >= TimeFromHMS(InpCloseHour, InpCloseMin) && CountPositions() > 0)
      CloseAllPositions();

   // --- Verificación de pérdida máxima diaria ---
   if(!g_daily_loss_hit && InpMaxDailyLoss != 0 && GetDailyLoss() <= InpMaxDailyLoss)
   {
      g_daily_loss_hit = true;
      if(InpCloseOnDailyLoss)
         CloseAllPositions();
      PrintFormat("Límite de pérdida diaria alcanzado (%.2f). %s",
                  GetDailyLoss(),
                  InpCloseOnDailyLoss ? "Posiciones cerradas. No se abrirán más operaciones hoy."
                                      : "No se abrirán más operaciones hoy.");
   }

   // --- Breakeven + Trailing Stop (asegurar ganancia) ---
   // --- Flechas y EMAs visuales ---
   ManageBreakEvenAndTrailing();
   UpdateEMAObjects();

   // --- Lógica de breakout (solo después de formado el rango) ---
   if(g_orb_formed && !g_daily_loss_hit && g_daily_trades < InpMaxTradesDay)
      CheckBreakout();
}

//+------------------------------------------------------------------+
//| Convierte hora/minuto de HOY (hora broker) a datetime            |
//+------------------------------------------------------------------+
datetime TimeFromHMS(int hour, int min)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = hour;
   dt.min  = min;
   dt.sec  = 0;
   return(StructToTime(dt));
}

//+------------------------------------------------------------------+
//| Reset del estado diario (nuevo día de trading)                   |
//+------------------------------------------------------------------+
void ResetDailyIfNeeded(datetime now)
{
   MqlDateTime dt;
   TimeToStruct(now, dt);
   datetime dayStart = now - (dt.hour * 3600 + dt.min * 60 + dt.sec);

   if(dayStart != g_today_date)
   {
      g_today_date     = dayStart;
      g_orb_start      = TimeFromHMS(InpORBStartHour, InpORBStartMin);
      g_orb_end        = TimeFromHMS(InpORBEndHour, InpORBEndMin);
      g_orb_high       = 0;
      g_orb_low        = 0;
      g_orb_formed     = false;
      g_long_taken     = false;
      g_short_taken    = false;
      g_daily_trades   = 0;
      g_daily_loss_hit = false;
   }
}

//+------------------------------------------------------------------+
//| Actualiza el High/Low del rango ORB (precio + vela M1)           |
//+------------------------------------------------------------------+
void UpdateORBRange()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double h = MathMax(bid, ask);
   double l = MathMin(bid, ask);

   // Refuerzo con la vela M1 actual (más estable en backtest)
   MqlRates rates[];
   if(CopyRates(_Symbol, PERIOD_M1, 0, 1, rates) == 1)
   {
      h = MathMax(h, rates[0].high);
      l = MathMin(l, rates[0].low);
   }

   if(g_orb_high == 0 || h > g_orb_high)
      g_orb_high = h;
   if(g_orb_low == 0 || l < g_orb_low)
      g_orb_low = l;

   if(InpShowORBPanel)
      DrawORBRange();
}

//+------------------------------------------------------------------+
//| Dibuja el rango ORB en el gráfico (rectángulo + líneas)          |
//+------------------------------------------------------------------+
void DrawORBRange()
{
   if(g_orb_start <= 0 || g_orb_end <= 0)
      return;
   if(g_orb_high <= 0 || g_orb_low <= 0)
      return;

   const string prefix = "QuantORB_";

   // Rectángulo del rango (fondo semitransparente)
   if(ObjectFind(0, prefix + "Range") < 0)
   {
      ObjectCreate(0, prefix + "Range", OBJ_RECTANGLE, 0, 0, 0, 0, 0);
      ObjectSetInteger(0, prefix + "Range", OBJPROP_BACK, true);
      ObjectSetInteger(0, prefix + "Range", OBJPROP_FILL, true);
      ObjectSetInteger(0, prefix + "Range", OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, prefix + "Range", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, prefix + "Range", OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, prefix + "Range", OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, prefix + "Range", OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, prefix + "Range", OBJPROP_TIME, 0, g_orb_start);
   ObjectSetInteger(0, prefix + "Range", OBJPROP_TIME, 1, g_orb_end);
   ObjectSetDouble(0, prefix + "Range", OBJPROP_PRICE, 0, g_orb_high);
   ObjectSetDouble(0, prefix + "Range", OBJPROP_PRICE, 1, g_orb_low);

   // Línea del máximo (verde, proyectada a la derecha)
   if(ObjectFind(0, prefix + "High") < 0)
   {
      ObjectCreate(0, prefix + "High", OBJ_TREND, 0, 0, 0, 0, 0);
      ObjectSetInteger(0, prefix + "High", OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, prefix + "High", OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, prefix + "High", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, prefix + "High", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, prefix + "High", OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, prefix + "High", OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, prefix + "High", OBJPROP_TIME, 0, g_orb_start);
   ObjectSetDouble(0, prefix + "High", OBJPROP_PRICE, 0, g_orb_high);
   ObjectSetInteger(0, prefix + "High", OBJPROP_TIME, 1, g_orb_end);
   ObjectSetDouble(0, prefix + "High", OBJPROP_PRICE, 1, g_orb_high);

   // Línea del mínimo (roja, proyectada a la derecha)
   if(ObjectFind(0, prefix + "Low") < 0)
   {
      ObjectCreate(0, prefix + "Low", OBJ_TREND, 0, 0, 0, 0, 0);
      ObjectSetInteger(0, prefix + "Low", OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, prefix + "Low", OBJPROP_COLOR, clrOrangeRed);
      ObjectSetInteger(0, prefix + "Low", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, prefix + "Low", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, prefix + "Low", OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, prefix + "Low", OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, prefix + "Low", OBJPROP_TIME, 0, g_orb_start);
   ObjectSetDouble(0, prefix + "Low", OBJPROP_PRICE, 0, g_orb_low);
   ObjectSetInteger(0, prefix + "Low", OBJPROP_TIME, 1, g_orb_end);
   ObjectSetDouble(0, prefix + "Low", OBJPROP_PRICE, 1, g_orb_low);
}

//+------------------------------------------------------------------+
//| Elimina los objetos gráficos del ORB                              |
//+------------------------------------------------------------------+
void DeleteORBObjects()
{
   const string prefix = "QuantORB_";
   ObjectDelete(0, prefix + "Range");
   ObjectDelete(0, prefix + "High");
   ObjectDelete(0, prefix + "Low");
}

//+------------------------------------------------------------------+
//| Detecta el breakout del rango y lanza la operación               |
//+------------------------------------------------------------------+
void CheckBreakout()
{
   if(g_orb_high <= 0 || g_orb_low <= 0)
      return; // rango inválido (no hubo ticks en la ventana)

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // --- Entrada LONG: precio rompe el máximo del rango ---
   if(!g_long_taken && bid > g_orb_high)
   {
      if(ATRFilterPassed() && RVOLFilterPassed())
         OpenTrade(ORDER_TYPE_BUY, bid, ask);
   }
   // --- Entrada SHORT: precio rompe el mínimo del rango ---
   else if(!g_short_taken && ask < g_orb_low)
   {
      if(ATRFilterPassed() && RVOLFilterPassed())
         OpenTrade(ORDER_TYPE_SELL, bid, ask);
   }
}

//+------------------------------------------------------------------+
//| Filtro ATR: volatilidad actual >= media * multiplicador          |
//+------------------------------------------------------------------+
bool ATRFilterPassed()
{
   if(!InpUseATRFilter || g_atr_handle == INVALID_HANDLE)
      return(true);

   double atr[];
   if(CopyBuffer(g_atr_handle, 0, 0, InpATRPeriod + 1, atr) < InpATRPeriod + 1)
      return(true); // datos insuficientes: no bloquear la operación

   double current = atr[0];
   double sum = 0;
   for(int i = 1; i <= InpATRPeriod; i++)
      sum += atr[i];
   double avg = sum / InpATRPeriod;

   if(avg <= 0)
      return(true);
   return(current >= avg * InpATRMultiplier);
}

//+------------------------------------------------------------------+
//| Filtro RVOL: volumen actual >= media * multiplicador             |
//+------------------------------------------------------------------+
bool RVOLFilterPassed()
{
   if(!InpUseRVOLFilter)
      return(true);

   double currentVol = (double)iVolume(_Symbol, PERIOD_M1, 0);

   long vols[];
   if(CopyTickVolume(_Symbol, PERIOD_M1, 1, InpRVOLPeriod, vols) < InpRVOLPeriod)
      return(true);

   double sum = 0;
   for(int i = 0; i < InpRVOLPeriod; i++)
      sum += (double)vols[i];
   double avg = sum / InpRVOLPeriod;

   if(avg <= 0)
      return(true);
   return(currentVol >= avg * InpRVOLMultiplier);
}

//+------------------------------------------------------------------+
//| Abre la operación con SL/TP y lote calculado por riesgo          |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE type, double bid, double ask)
{
   double entry = (type == ORDER_TYPE_BUY) ? ask : bid;
   double sl;

   // SL base: al otro lado del nivel de breakout, con buffer extra
   double slBase = (type == ORDER_TYPE_BUY) ? (g_orb_high - InpSLBufferPoints * g_point)
                                            : (g_orb_low  + InpSLBufferPoints * g_point);

   // Distancia efectiva del SL: nunca menor que la mínima del broker ni que la configurada.
   // Evita que al romper el rango con la entrada pegada al nivel ORB el lote se dispare
   // (distancia ínfima -> lote enorme -> "not enough money").
   double minStop = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * g_point;
   double slDist  = MathMax(MathAbs(entry - slBase), MathMax(minStop, InpMinSLPoints * g_point));

   // El SL se coloca a la distancia efectiva hacia el lado perdedor
   if(type == ORDER_TYPE_BUY)
      sl = entry - slDist;
   else
      sl = entry + slDist;

   // TP con el ratio configurado sobre la misma distancia de SL
   double tp = (type == ORDER_TYPE_BUY) ? entry + slDist * InpTPRatio
                                        : entry - slDist * InpTPRatio;

   // Lote basado en el riesgo configurado
   double lot = CalcLot(entry, sl);
   if(lot <= 0)
   {
      Print("Lote calculado = 0 (riesgo insuficiente o no se alcanza el lote mínimo). Operación omitida.");
      return;
   }

   sl = NormalizeDouble(sl, g_digits);
   tp = NormalizeDouble(tp, g_digits);

   // --- Enfriamiento tras un fallo reciente (evita reintentar en cada tick) ---
   if(g_last_fail_time > 0 && TimeCurrent() - g_last_fail_time < InpRetryCooldownSec)
   {
      // Enfriamiento activo: no se reintenta en este tick (silencioso)
      return;
   }

   // --- Envío de la orden con reintentos ---
   bool ok = false;
   int attempts = MathMax(1, InpRetryAttempts);
   for(int attempt = 1; attempt <= attempts && !ok; attempt++)
   {
      if(type == ORDER_TYPE_BUY)
         ok = m_trade.Buy(lot, _Symbol, 0, sl, tp, InpTradeComment);
      else
         ok = m_trade.Sell(lot, _Symbol, 0, sl, tp, InpTradeComment);

      if(!ok && attempt < attempts)
      {
         int err = GetLastError();
         // Solo reintentar errores transitorios (requote, precio cambiado, sin cotización, timeout, demasiadas peticiones)
         if(err != 10004 && err != 10006 && err != 10007 && err != 10009 && err != 10019)
         {
            PrintFormat("Error %d (%s) no es reintentable. Abortando reintentos.",
                        err, m_trade.ResultRetcodeDescription());
            break;
         }
         PrintFormat("Intento %d/%d falló (error %d: %s). Reintentando...",
                     attempt, attempts, err,
                     m_trade.ResultRetcodeDescription());
         if(InpRetryDelayMs > 0)
            Sleep(InpRetryDelayMs);
      }
   }

   if(ok)
   {
      if(type == ORDER_TYPE_BUY)
         g_long_taken = true;
      else
         g_short_taken = true;
      g_daily_trades++;
      PrintFormat("Orden %s ejecutada: lot=%.2f SL=%.5f TP=%.5f",
                  (type == ORDER_TYPE_BUY ? "BUY" : "SELL"), lot, sl, tp);
   DrawSignalArrow(type, (long)m_trade.ResultOrder());
   }
   else
   {
      g_last_fail_time = TimeCurrent();
      PrintFormat("Error al enviar orden: %d - %s",
                  GetLastError(), m_trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Calcula el lote para arriesgar InpRiskPercent del balance        |
//+------------------------------------------------------------------+
double CalcLot(double entry, double sl)
{
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * InpRiskPercent / 100.0;
   double slDist    = MathAbs(entry - sl);

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0 || slDist <= 0)
      return(0);

   double moneyPerLot = 0.0;
   double lossAtOneLot = 0.0;
   ENUM_ORDER_TYPE calcType = (sl < entry) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(OrderCalcProfit(calcType, _Symbol, 1.0, entry, sl, lossAtOneLot))
      moneyPerLot = MathAbs(lossAtOneLot);
   if(moneyPerLot <= 0.0)
      moneyPerLot = (slDist / tickSize) * tickValue;
   if(moneyPerLot <= 0.0)
      return(0);

   double lot = riskMoney / moneyPerLot;

   // Ajustar al paso de volumen del símbolo
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double lotMin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotMax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(lotStep <= 0)
      lotStep = 0.01;

   lot = MathFloor(lot / lotStep) * lotStep;
   if(lot < lotMin)
      return(0);
   if(lot > lotMax)
      lot = lotMax;

   // Límite por margen disponible (evita "not enough money" y lotes imposibles).
   // Nota: SYMBOL_MARGIN_INITIAL no es fiable en todos los brokers/tester, por lo que
   // el margen también se calcula desde contrato*precio/apalancamiento y se usa el
   // valor más conservador de los dos.
   double freeMargin   = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double leverage     = (double)AccountInfoInteger(ACCOUNT_LEVERAGE);
   double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double marginByContract = 0;
   if(leverage > 0 && contractSize > 0)
      marginByContract = (contractSize * SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / leverage;
   double marginPerLot = SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL);
   if(marginByContract > 0 && (marginPerLot <= 0 || marginPerLot < marginByContract * 0.5))
      marginPerLot = marginByContract;
   if(marginPerLot > 0 && freeMargin > 0)
   {
      double maxLotByMargin = MathFloor((freeMargin * InpMaxMarginPct / 100.0) / marginPerLot / lotStep) * lotStep;
      if(maxLotByMargin <= 0)
         return(0);
      if(lot > maxLotByMargin)
         lot = maxLotByMargin;
      if(lot < lotMin)
         return(0);
   }

   return(NormalizeDouble(lot, 2));
}

//+------------------------------------------------------------------+
//| Cuenta posiciones abiertas de este EA (símbolo + magic)          |
//+------------------------------------------------------------------+
int CountPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == (long)InpMagicNumber)
         count++;
   }
   return(count);
}

//+------------------------------------------------------------------+
//| Cierra todas las posiciones de este EA                           |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;
      m_trade.PositionClose(ticket);
   }
}

//+------------------------------------------------------------------+
//| P/L de hoy (realizado + flotante) de este EA                     |
//+------------------------------------------------------------------+
double GetDailyLoss()
{
   double result = 0;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime from = TimeCurrent() - (dt.hour * 3600 + dt.min * 60 + dt.sec);

   // Resultado realizado de hoy
   if(HistorySelect(from, TimeCurrent()))
   {
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0)
            continue;
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != (long)InpMagicNumber)
            continue;
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
            continue;
         result += HistoryDealGetDouble(ticket, DEAL_PROFIT);
         result += HistoryDealGetDouble(ticket, DEAL_SWAP);
         result += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      }
   }

   // Flotante actual
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;
      result += PositionGetDouble(POSITION_PROFIT);
   }

   return(result);
}
//+------------------------------------------------------------------+