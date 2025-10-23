//+------------------------------------------------------------------+
//|                                                  Crash/Boom MT5  |
//|                                   CrashBoom_ImpulseDetector.mq5  |
//|                               Copyright © 2025, OpenAI (free)    |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2
#property indicator_label1  "Boom Spike Soon"

#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrTomato
#property indicator_width2  2
#property indicator_label2  "Crash Spike Soon"

//--- входные параметры
input int              SpikeDetectionDepth     = 12;   // Глубина анализа фракталов / ZigZag
input int              MovingAveragePeriod1    = 50;   // EMA период 1
input int              MovingAveragePeriod2    = 100;  // EMA период 2
input int              MovingAveragePeriod3    = 200;  // EMA период 3
input int              RSI_Period              = 14;   // Период RSI
input int              MACD_Fast               = 12;   // MACD Fast EMA
input int              MACD_Slow               = 26;   // MACD Slow EMA
input int              MACD_Signal             = 9;    // MACD Signal
input int              ATR_Period              = 14;   // Период ATR
input bool             ShowFibonacciLevels     = true; // Показывать уровни Фибо
input bool             EnableAlerts            = true; // Включить оповещения
input int              ArrowSize               = 2;    // Размер стрелки
input int              ArrowDistance           = 6;    // Смещение стрелки в шагах цены
input double           SpikePredictionSensitivity = 1.0; // Чувствительность определения импульса (0.5..2.0)
input ENUM_TIMEFRAMES  Timeframe               = PERIOD_CURRENT; // Таймфрейм анализа

//--- буферы индикатора
double BuySignalBuffer[];   // стрелки для Boom (потенциальный рост)
double SellSignalBuffer[];  // стрелки для Crash (потенциальное падение)

//--- хэндлы встроенных индикаторов
int hEMA1 = INVALID_HANDLE;
int hEMA2 = INVALID_HANDLE;
int hEMA3 = INVALID_HANDLE;
int hRSI  = INVALID_HANDLE;
int hMACD = INVALID_HANDLE;
int hATR  = INVALID_HANDLE;
int hBandsUpper = INVALID_HANDLE; // верхняя полоса Боллинджера
int hBandsMiddle = INVALID_HANDLE;// средняя линия Боллинджера
int hBandsLower = INVALID_HANDLE; // нижняя полоса Боллинджера
int hFractals = INVALID_HANDLE;
// ZigZag опционально через iCustom
int hZigZag = INVALID_HANDLE;

//--- внутренние параметры/состояния
int    g_pointDigits = 0;
double g_point      = 0.0;
double g_tickSize   = 0.0;
string g_symbol     = "";
ENUM_TIMEFRAMES g_tf = PERIOD_CURRENT;

//--- самообучение (адаптивный порог)
string g_gvPrefix = "CBID_";   // префикс глобальных переменных
int    g_evalWindowBars = 5;    // проверка события импульса в ближайшие N свечей
int    g_minLookback = 400;     // минимум баров для анализа

//--- состояния сигналов
datetime g_lastBuySignalTime = 0;
datetime g_lastSellSignalTime = 0;

//--- панель статуса
string PANEL_NAME = "CBID_PANEL";
bool   g_panelCreated = false;

double EMPTY = EMPTY_VALUE;

//+------------------------------------------------------------------+
//| Вспомогательные функции                                          |
//+------------------------------------------------------------------+
bool IsBoomSymbol()
{
   string name = StringToLower(g_symbol);
   if(StringFind(name, "boom") >= 0) return true;
   return false;
}

bool IsCrashSymbol()
{
   string name = StringToLower(g_symbol);
   if(StringFind(name, "crash") >= 0) return true;
   return false;
}

// безопасное получение одного значения из буфера индикатора по shift таймфрейма
bool CopyOneValue(const int handle, const int bufferIndex, const int tfShift, double &out)
{
   out = 0.0;
   if(handle == INVALID_HANDLE || tfShift < 0)
      return false;
   double tmp[1];
   int copied = CopyBuffer(handle, bufferIndex, tfShift, 1, tmp);
   if(copied != 1)
      return false;
   out = tmp[0];
   return true;
}

// Получить ATR текущего бара выбранного ТФ
bool GetATR(const datetime t, double &atr)
{
   int shift = iBarShift(g_symbol, g_tf, t, true);
   return CopyOneValue(hATR, 0, shift, atr);
}

bool GetRSI(const datetime t, double &rsi)
{
   int shift = iBarShift(g_symbol, g_tf, t, true);
   return CopyOneValue(hRSI, 0, shift, rsi);
}

bool GetMACD(const datetime t, double &macdMain, double &macdSignal, double &macdHist)
{
   int shift = iBarShift(g_symbol, g_tf, t, true);
   bool ok1 = CopyOneValue(hMACD, 0, shift, macdMain);
   bool ok2 = CopyOneValue(hMACD, 1, shift, macdSignal);
   bool ok3 = CopyOneValue(hMACD, 2, shift, macdHist);
   return ok1 && ok2 && ok3;
}

bool GetEMA(const datetime t, double &ema1, double &ema2, double &ema3)
{
   int shift = iBarShift(g_symbol, g_tf, t, true);
   bool ok1 = CopyOneValue(hEMA1, 0, shift, ema1);
   bool ok2 = CopyOneValue(hEMA2, 0, shift, ema2);
   bool ok3 = CopyOneValue(hEMA3, 0, shift, ema3);
   return ok1 && ok2 && ok3;
}

bool GetBands(const datetime t, double &upper, double &middle, double &lower)
{
   int shift = iBarShift(g_symbol, g_tf, t, true);
   bool ok1 = CopyOneValue(hBandsUpper, 0, shift, upper);
   bool ok2 = CopyOneValue(hBandsMiddle, 0, shift, middle);
   bool ok3 = CopyOneValue(hBandsLower, 0, shift, lower);
   return ok1 && ok2 && ok3;
}

bool GetFractals(const datetime t, double &frUp, double &frDn)
{
   int shift = iBarShift(g_symbol, g_tf, t, true);
   bool okUp = CopyOneValue(hFractals, 0, shift, frUp);   // верхний фрактал
   bool okDn = CopyOneValue(hFractals, 1, shift, frDn);   // нижний фрактал
   if(!okUp) frUp = 0.0; // пусто
   if(!okDn) frDn = 0.0;
   return okUp || okDn;
}

// Проверка события "импульс уже случился" на баре j (для оценки качества сигналов)
bool IsSpikeBar(const double high, const double low, const double open, const double close, const double atr, const bool isBoom)
{
   // Для Boom: сильный всплеск вверх (теневая часть вверх или большой бычий диапазон)
   // Для Crash: сильный всплеск вниз
   if(atr <= 0.0) return false;
   double body = MathAbs(close - open);
   double upperWick = high - MathMax(open, close);
   double lowerWick = MathMin(open, close) - low;

   double spikeFactor = 2.2; // коэффициент чувствительности к размеру ATR

   if(isBoom)
   {
      if((upperWick >= spikeFactor * atr) || ( (close > open) && (high - low) >= (spikeFactor * atr) && (upperWick > lowerWick)))
         return true;
   }
   else
   {
      if((lowerWick >= spikeFactor * atr) || ( (close < open) && (high - low) >= (spikeFactor * atr) && (lowerWick > upperWick)))
         return true;
   }
   return false;
}

// Поиск последних двух фрактальных экстремумов по направлению (для дивергенций)
bool FindLastTwoFractalLows(const int bars, const datetime &time[], const double &low[], datetime &t1, double &p1, datetime &t2, double &p2)
{
   t1 = 0; p1 = 0; t2 = 0; p2 = 0;
   int found = 0;
   for(int i = bars - 3; i >= 2 && found < 2; --i)
   {
      // простой фрактал вниз: low[i] ниже соседей
      if(low[i] < low[i-1] && low[i] < low[i+1] && low[i] < low[i-2] && low[i] < low[i+2])
      {
         if(found == 0) { t1 = time[i]; p1 = low[i]; found = 1; }
         else if(found == 1) { t2 = time[i]; p2 = low[i]; found = 2; }
      }
   }
   return (found == 2);
}

bool FindLastTwoFractalHighs(const int bars, const datetime &time[], const double &high[], datetime &t1, double &p1, datetime &t2, double &p2)
{
   t1 = 0; p1 = 0; t2 = 0; p2 = 0;
   int found = 0;
   for(int i = bars - 3; i >= 2 && found < 2; --i)
   {
      if(high[i] > high[i-1] && high[i] > high[i+1] && high[i] > high[i-2] && high[i] > high[i+2])
      {
         if(found == 0) { t1 = time[i]; p1 = high[i]; found = 1; }
         else if(found == 1) { t2 = time[i]; p2 = high[i]; found = 2; }
      }
   }
   return (found == 2);
}

// Оценка дивергенции: бычья (цена ниже, индикатор выше) / медвежья (цена выше, индикатор ниже)
bool CheckBullishDivergence(const int bars, const datetime &time[], const double &low[], const datetime oscT1, const double oscV1, const datetime oscT2, const double oscV2)
{
   // предполагается, что oscT1 соответствует более свежему экстремуму
   datetime pT1; double pP1; datetime pT2; double pP2;
   if(!FindLastTwoFractalLows(bars, time, low, pT1, pP1, pT2, pP2))
      return false;
   // Сопоставим времена приблизительно (по близости)
   if(pP1 < pP2 && oscV1 > oscV2)
      return true;
   return false;
}

bool CheckBearishDivergence(const int bars, const datetime &time[], const double &high[], const datetime oscT1, const double oscV1, const datetime oscT2, const double oscV2)
{
   datetime pT1; double pP1; datetime pT2; double pP2;
   if(!FindLastTwoFractalHighs(bars, time, high, pT1, pP1, pT2, pP2))
      return false;
   if(pP1 > pP2 && oscV1 < oscV2)
      return true;
   return false;
}

// Создать/обновить небольшую панель статуса
void UpdatePanel(const string trendText, const double prob, const double rsi, const double atr, const double macd)
{
   if(!g_panelCreated)
   {
      if(!ObjectCreate(0, PANEL_NAME, OBJ_LABEL, 0, 0, 0))
         return;
      g_panelCreated = true;
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_YDISTANCE, 18);
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, PANEL_NAME, OBJPROP_FONT, "Segoe UI");
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_COLOR, clrGainsboro);
   }

   string s = StringFormat("%s | Prob: %.1f%% | RSI: %.1f | ATR: %.1f | MACD: %.4f", trendText, prob, rsi, atr, macd);
   ObjectSetString(0, PANEL_NAME, OBJPROP_TEXT, s);
}

// Рисование стрелок-объектов и текстовых меток
void DrawSignalObjects(const int shiftIndex, const datetime t, const double price, const bool isBoom)
{
   string dir = (isBoom ? "BUY" : "SELL");
   string arrowName = StringFormat("CBID_ARROW_%s_%I64d", dir, (long) t);
   string labelName = StringFormat("CBID_LABEL_%s_%I64d", dir, (long) t);

   color clr = isBoom ? clrDodgerBlue : clrTomato;

   // Стрелка
   if(!ObjectCreate(0, arrowName, OBJ_ARROW, 0, t, price))
   {
      // возможно уже существует
   }
   ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, isBoom ? 233 : 234);
   ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, MathMax(1, ArrowSize));

   // Подпись
   string text = isBoom ? "Boom spike soon" : "Crash spike soon";
   if(!ObjectCreate(0, labelName, OBJ_TEXT, 0, t, price))
   {
      // возможно уже существует
   }
   ObjectSetString(0, labelName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, isBoom ? ANCHOR_RIGHT_UPPER : ANCHOR_RIGHT_LOWER);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
}

// Динамическая очистка старых объектов с префиксом
void CleanupOldObjects(const int maxKeep)
{
   int total = ObjectsTotal(0, -1, -1);
   int count = 0;
   // удаляем всё, что старше maxKeep по времени сортировки (грубая стратегия)
   for(int i = total - 1; i >= 0; --i)
   {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, "CBID_") == 0)
      {
         count++;
         if(count > maxKeep)
            ObjectDelete(0, name);
      }
   }
}

// Построение базовых S/R по последним фракталам
void DrawSupportResistance(const int bars, const datetime &time[], const double &high[], const double &low[])
{
   // Найдём последние по одному фракталу вверх и вниз
   datetime tUp; double pUp; datetime tUp2; double pUp2;
   if(FindLastTwoFractalHighs(bars, time, high, tUp, pUp, tUp2, pUp2))
   {
      string hline = StringFormat("CBID_SR_H_%I64d", (long) tUp);
      ObjectCreate(0, hline, OBJ_HLINE, 0, 0, pUp);
      ObjectSetInteger(0, hline, OBJPROP_COLOR, clrSandyBrown);
      ObjectSetInteger(0, hline, OBJPROP_STYLE, STYLE_DASH);
   }
   datetime tDn; double pDn; datetime tDn2; double pDn2;
   if(FindLastTwoFractalLows(bars, time, low, tDn, pDn, tDn2, pDn2))
   {
      string lline = StringFormat("CBID_SR_L_%I64d", (long) tDn);
      ObjectCreate(0, lline, OBJ_HLINE, 0, 0, pDn);
      ObjectSetInteger(0, lline, OBJPROP_COLOR, clrLightSeaGreen);
      ObjectSetInteger(0, lline, OBJPROP_STYLE, STYLE_DASH);
   }
}

// Простая разметка последнего свинга Фибо (если включено)
void DrawFiboFromLastSwing(const int bars, const datetime &time[], const double &high[], const double &low[])
{
   if(!ShowFibonacciLevels) return;
   // Найдём локальные экстремумы по последним ~200 барам
   int look = MathMin(200, bars - 10);
   if(look < 10) return;

   int iStart = bars - look;
   double swingHigh = -DBL_MAX; int iHigh = iStart;
   double swingLow  = DBL_MAX;  int iLow  = iStart;
   for(int i = iStart; i < bars; ++i)
   {
      if(high[i] > swingHigh) { swingHigh = high[i]; iHigh = i; }
      if(low[i]  < swingLow)  { swingLow  = low[i];  iLow  = i; }
   }
   // Создадим один Фибо-объект
   string name = "CBID_FIBO";
   if(ObjectFind(0, name) == -1)
      ObjectCreate(0, name, OBJ_FIBO, 0, 0, 0);
   // направление по расположению экстремумов
   datetime t1 = time[iLow];  double p1 = low[iLow];
   datetime t2 = time[iHigh]; double p2 = high[iHigh];
   if(iHigh < iLow)
   {
      t1 = time[iHigh]; p1 = high[iHigh];
      t2 = time[iLow];  p2 = low[iLow];
   }
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, p1);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrGray);
}

// Получить/установить адаптивный порог из глобальных переменных
string ThresholdGvName()
{
   string tfName = EnumToString(g_tf);
   return g_gvPrefix + g_symbol + "_" + tfName + "_THRESH";
}

double GetAdaptiveThreshold()
{
   string name = ThresholdGvName();
   if(!GlobalVariableCheck(name))
      GlobalVariableSet(name, 50.0); // стартовое значение
   return GlobalVariableGet(name);
}

void SetAdaptiveThreshold(const double v)
{
   string name = ThresholdGvName();
   GlobalVariableSet(name, MathMax(25.0, MathMin(80.0, v)));
}

void RecordOutcome(const bool success)
{
   string base = g_gvPrefix + g_symbol + "_" + EnumToString(g_tf);
   string suc = base + "_SUC";
   string fp  = base + "_FP";
   if(!GlobalVariableCheck(suc)) GlobalVariableSet(suc, 0);
   if(!GlobalVariableCheck(fp))  GlobalVariableSet(fp, 0);

   double s = GlobalVariableGet(suc);
   double f = GlobalVariableGet(fp);
   if(success) s += 1.0; else f += 1.0;
   GlobalVariableSet(suc, s);
   GlobalVariableSet(fp, f);

   // простая адаптация: повышаем порог при ложных, снижаем при успешных
   double th = GetAdaptiveThreshold();
   if(success) th -= 1.0 * (2.0 - SpikePredictionSensitivity); // при большей чувствительности корректируем плавнее
   else        th += 1.5 * (SpikePredictionSensitivity);
   SetAdaptiveThreshold(th);
}

// Формирование вероятности импульса по набору критериев
// Возвращает 0..100
// Также возвращает текст тренда и последние значения индикаторов для панели
void ComputeSpikeProbability(
   const int i,
   const datetime &t,
   const double priceOpen,
   const double priceHigh,
   const double priceLow,
   const double priceClose,
   double &probOut,
   string &trendText,
   double &rsiOut,
   double &atrOut,
   double &macdOut,
   bool   &directionIsBoom
)
{
   probOut = 0.0; trendText = ""; rsiOut = 0.0; atrOut = 0.0; macdOut = 0.0; directionIsBoom = false;

   bool isBoom = IsBoomSymbol();
   bool isCrash = IsCrashSymbol();
   if(!isBoom && !isCrash)
   {
      // Если неизвестный символ — определим направление по контексту (ниже логика симметрична)
      isBoom = true; // по умолчанию
   }

   // Индикаторы
   double ema1=0, ema2=0, ema3=0;
   double rsi=0, atr=0, macdMain=0, macdSig=0, macdHist=0;
   GetEMA(t, ema1, ema2, ema3);
   GetRSI(t, rsi);
   GetATR(t, atr);
   GetMACD(t, macdMain, macdSig, macdHist);
   double bU=0, bM=0, bL=0;
   GetBands(t, bU, bM, bL);
   double frUp=0, frDn=0;
   GetFractals(t, frUp, frDn);

   rsiOut = rsi; atrOut = atr; macdOut = macdMain;

   // Тренд по ЕМА: 1 — бычий, -1 — медвежий
   int trend = 0;
   if(ema1>ema2 && ema2>ema3) trend = 1; else if(ema1<ema2 && ema2<ema3) trend = -1; else trend = 0;
   // наклон EMA1
   double ema1_prev=ema1;
   {
      int shPrev = iBarShift(g_symbol, g_tf, t, true) + 1;
      double tmp;
      if(CopyOneValue(hEMA1, 0, shPrev, tmp)) ema1_prev = tmp;
   }
   double slope = ema1 - ema1_prev;

   if(trend>0 && slope>0) trendText = "Trend: Bullish";
   else if(trend<0 && slope<0) trendText = "Trend: Bearish";
   else trendText = "Trend: Sideways";

   // Базовые критерии вероятности
   double prob = 0.0;

   // 1) Полосы Боллинджера и RSI
   if(atr>0.0)
   {
      if(priceClose <= bL) prob += 20.0; // у нижней границы — потенциальный отскок вверх
      if(priceClose >= bU) prob += 20.0; // у верхней границы — потенциал вниз
   }
   if(rsi>0)
   {
      if(rsi < 35.0) prob += 15.0; // перепроданность
      if(rsi > 65.0) prob += 15.0; // перекупленность
   }

   // 2) MACD разворот
   if(macdHist != 0.0)
   {
      // смена знака гистограммы усиливает сигнал
      int shPrev = iBarShift(g_symbol, g_tf, t, true) + 1;
      double macdHistPrev = macdHist;
      double tmp;
      if(CopyOneValue(hMACD, 2, shPrev, tmp)) macdHistPrev = tmp;
      if(macdHistPrev < 0 && macdHist > 0) prob += 12.0; // к росту
      if(macdHistPrev > 0 && macdHist < 0) prob += 12.0; // к снижению
   }

   // 3) Близость к фракталу поддержки/сопротивления
   double nearSRbonus = 0.0;
   double distToFrDn = (frDn>0 ? MathAbs(priceClose - frDn) : 1e9);
   double distToFrUp = (frUp>0 ? MathAbs(priceClose - frUp) : 1e9);
   double atrRef = (atr>0 ? atr : (g_point*ArrowDistance));
   if(atrRef > 0)
   {
      if(distToFrDn < 0.6 * atrRef) nearSRbonus += 10.0; // рядом с поддержкой
      if(distToFrUp < 0.6 * atrRef) nearSRbonus += 10.0; // рядом с сопротивлением
   }
   prob += nearSRbonus;

   // 4) Дивергенции (по RSI как более быстрый осциллятор)
   // Для упрощения возьмем соседние значения RSI вокруг двух последних лок. экстремумов RSI
   // Здесь используем приближенный метод: сравним значение RSI сегодня и 10 баров назад к минимумам/максимумам цены
   int bars = Bars(_Symbol, _Period);
   datetime t1RSI = t; double rsi1 = rsi;
   datetime t2RSI = t; double rsi2 = rsi;
   int shiftNow = iBarShift(_Symbol, _Period, t, true);
   int shift10  = shiftNow + 10;
   if(shift10 < rates_total) // NOTE: rates_total доступен в OnCalculate, здесь ориентируемся на локальный _Period
   {
      double tmp;
      if(CopyOneValue(hRSI, 0, iBarShift(g_symbol, g_tf, iTime(_Symbol, _Period, shift10), true), tmp))
      {
         rsi2 = tmp;
      }
   }
   // Упрощенно: если цена сделала более низкий минимум, а RSI вырос — бычья дивергенция
   // Проверяем по близким фракталам
   datetime f1; double fp1; datetime f2; double fp2;
   if(FindLastTwoFractalLows(bars, iTime(_Symbol, _Period), iLow(_Symbol, _Period), f1, fp1, f2, fp2))
   {
      if(fp1 < fp2 && rsi1 > rsi2) prob += 18.0; // бычья дивергенция
   }
   if(FindLastTwoFractalHighs(bars, iTime(_Symbol, _Period), iHigh(_Symbol, _Period), f1, fp1, f2, fp2))
   {
      if(fp1 > fp2 && rsi1 < rsi2) prob += 18.0; // медвежья дивергенция
   }

   // Направление по контексту символа и текущей перегретости
   // Boom — ищем будущие всплески вверх, Crash — вниз
   double probUp   = prob;
   double probDown = prob;

   // усилим в сторону контекста Боллинджера
   if(priceClose <= bL) probUp   += 6.0;
   if(priceClose >= bU) probDown += 6.0;
   // RSI
   if(rsi < 35) probUp += 4.0;
   if(rsi > 65) probDown += 4.0;

   // сгладим трендом: если контртренд — чуть ослабим, если по тренду — усилим
   double trendAdj = (trend==1? +5.0 : (trend==-1? -5.0 : 0.0));
   probUp   += trendAdj;   // тренд вверх поддерживает покупки
   probDown -= trendAdj;   // тренд вниз поддерживает продажи

   // чёрный список отрицательных значений
   probUp   = MathMax(0.0, MathMin(100.0, probUp));
   probDown = MathMax(0.0, MathMin(100.0, probDown));

   // Выбор направления под символ
   if(isBoom && !isCrash)
   {
      probOut = probUp;
      directionIsBoom = true;
   }
   else if(isCrash && !isBoom)
   {
      probOut = probDown;
      directionIsBoom = false;
   }
   else
   {
      // неизвестный — берем максимальную составляющую
      if(probUp >= probDown) { probOut = probUp; directionIsBoom = true; }
      else { probOut = probDown; directionIsBoom = false; }
   }
}

//+------------------------------------------------------------------+
//| Инициализация                                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   g_symbol = _Symbol;
   g_tf = (Timeframe == PERIOD_CURRENT ? (ENUM_TIMEFRAMES) _Period : Timeframe);

   g_point = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   g_pointDigits = (int) SymbolInfoInteger(g_symbol, SYMBOL_DIGITS);
   g_tickSize = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_SIZE);

   //--- буферы
   SetIndexBuffer(0, BuySignalBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SellSignalBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(1, PLOT_ARROW, 234);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY);
   PlotIndexSetString(0, PLOT_LABEL, "Boom Spike Soon");
   PlotIndexSetString(1, PLOT_LABEL, "Crash Spike Soon");

   ArrayInitialize(BuySignalBuffer, EMPTY);
   ArrayInitialize(SellSignalBuffer, EMPTY);

   //--- создаём хэндлы индикаторов (МТF)
   hEMA1 = iMA(g_symbol, g_tf, MovingAveragePeriod1, 0, MODE_EMA, PRICE_CLOSE);
   hEMA2 = iMA(g_symbol, g_tf, MovingAveragePeriod2, 0, MODE_EMA, PRICE_CLOSE);
   hEMA3 = iMA(g_symbol, g_tf, MovingAveragePeriod3, 0, MODE_EMA, PRICE_CLOSE);
   hRSI  = iRSI(g_symbol, g_tf, RSI_Period, PRICE_CLOSE);
   hMACD = iMACD(g_symbol, g_tf, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
   hATR  = iATR(g_symbol, g_tf, ATR_Period);
   // Полосы Боллинджера (обычный набор параметров: 20,2)
   int bbPeriod = 20; double bbDev = 2.0;
   hBandsUpper  = iBands(g_symbol, g_tf, bbPeriod, 0, bbDev, PRICE_CLOSE, MODE_UPPER);
   hBandsMiddle = iBands(g_symbol, g_tf, bbPeriod, 0, bbDev, PRICE_CLOSE, MODE_MAIN);
   hBandsLower  = iBands(g_symbol, g_tf, bbPeriod, 0, bbDev, PRICE_CLOSE, MODE_LOWER);
   hFractals    = iFractals(g_symbol, g_tf);

   // ZigZag — опционально
   // Примечание: в MT5 ZigZag может находиться в разных папках, используем имя по умолчанию
   // Если индикатор отсутствует, handle останется INVALID_HANDLE и будет игнорирован
   hZigZag = iCustom(g_symbol, g_tf, "ZigZag", SpikeDetectionDepth, 5, 3);

   if(hEMA1==INVALID_HANDLE || hEMA2==INVALID_HANDLE || hEMA3==INVALID_HANDLE ||
      hRSI==INVALID_HANDLE  || hMACD==INVALID_HANDLE || hATR==INVALID_HANDLE   ||
      hBandsUpper==INVALID_HANDLE || hBandsMiddle==INVALID_HANDLE || hBandsLower==INVALID_HANDLE ||
      hFractals==INVALID_HANDLE)
   {
      Print("[CBID] Ошибка создания одного из хэндлов индикаторов");
   }

   // размеры стрелок
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, MathMax(1, ArrowSize));
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, MathMax(1, ArrowSize));

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Деинициализация                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(hEMA1!=INVALID_HANDLE) IndicatorRelease(hEMA1);
   if(hEMA2!=INVALID_HANDLE) IndicatorRelease(hEMA2);
   if(hEMA3!=INVALID_HANDLE) IndicatorRelease(hEMA3);
   if(hRSI!=INVALID_HANDLE)  IndicatorRelease(hRSI);
   if(hMACD!=INVALID_HANDLE) IndicatorRelease(hMACD);
   if(hATR!=INVALID_HANDLE)  IndicatorRelease(hATR);
   if(hBandsUpper!=INVALID_HANDLE)  IndicatorRelease(hBandsUpper);
   if(hBandsMiddle!=INVALID_HANDLE) IndicatorRelease(hBandsMiddle);
   if(hBandsLower!=INVALID_HANDLE)  IndicatorRelease(hBandsLower);
   if(hFractals!=INVALID_HANDLE)    IndicatorRelease(hFractals);
   if(hZigZag!=INVALID_HANDLE)      IndicatorRelease(hZigZag);
}

//+------------------------------------------------------------------+
//| Основной расчёт                                                   |
//+------------------------------------------------------------------+
int OnCalculate(
   const int        rates_total,
   const int        prev_calculated,
   const datetime & time[],
   const double   & open[],
   const double   & high[],
   const double   & low[],
   const double   & close[],
   const long     & tick_volume[],
   const long     & volume[],
   const int      & spread[])
{
   if(rates_total < MathMax(g_minLookback, 50))
      return(prev_calculated);

   int start = prev_calculated;
   if(start > 0) start -= 1; // пересчёт последнего
   if(start < 0) start = 0;

   // Порог вероятности (адаптивный)
   double adaptiveThresh = GetAdaptiveThreshold();
   // Учёт входной чувствительности
   double threshold = MathMax(20.0, MathMin(90.0, adaptiveThresh * SpikePredictionSensitivity));

   // Очистим буферы на участке перерасчёта
   for(int i = start; i < rates_total; ++i)
   {
      BuySignalBuffer[i]  = EMPTY;
      SellSignalBuffer[i] = EMPTY;
   }

   // Основной цикл
   for(int i = start; i < rates_total; ++i)
   {
      datetime t = time[i];
      double o = open[i];
      double h = high[i];
      double l = low[i];
      double c = close[i];

      double prob=0, rsi=0, atr=0, macd=0; string trend=""; bool expectBoom=true;
      ComputeSpikeProbability(i, t, o, h, l, c, prob, trend, rsi, atr, macd, expectBoom);

      // панель обновляем только на последнем баре
      if(i == rates_total - 1)
         UpdatePanel(trend, prob, rsi, atr, macd);

      // Проверка на сигнал: задача — подать сигнал ЗАРАНЕЕ (1..5 свечей)
      // Здесь сигнал генерируется в текущей точке, предполагая событие в окне ближайших g_evalWindowBars
      if(prob >= threshold && atr > 0.0)
      {
         // размещаем стрелку на расстоянии ArrowDistance от экстремума свечи
         if(expectBoom)
         {
            double y = l - ArrowDistance * g_point;
            BuySignalBuffer[i] = y;
            // Рисуем объекты один раз на последнем баре истории и на появлении новой свечи
            if(i >= rates_total - 2)
            {
               DrawSignalObjects(i, t, y, true);
               if(EnableAlerts && t != g_lastBuySignalTime)
               {
                  string msg = StringFormat("[CBID] %s: Boom spike soon (prob=%.1f%%, TF=%s)", g_symbol, prob, EnumToString(g_tf));
                  Alert(msg);
                  Print(msg);
                  // Push/email по настройкам терминала (если разрешено)
                  SendNotification(msg);
                  //SendMail("CBID", msg);
                  g_lastBuySignalTime = t;
               }
            }
         }
         else
         {
            double y = h + ArrowDistance * g_point;
            SellSignalBuffer[i] = y;
            if(i >= rates_total - 2)
            {
               DrawSignalObjects(i, t, y, false);
               if(EnableAlerts && t != g_lastSellSignalTime)
               {
                  string msg = StringFormat("[CBID] %s: Crash spike soon (prob=%.1f%%, TF=%s)", g_symbol, prob, EnumToString(g_tf));
                  Alert(msg);
                  Print(msg);
                  SendNotification(msg);
                  //SendMail("CBID", msg);
                  g_lastSellSignalTime = t;
               }
            }
         }
      }

      // Каждые несколько баров подчищаем объекты
      if(i == rates_total - 1 && (i % 10 == 0))
      {
         CleanupOldObjects(200);
         // Обновим SR/Fibo
         DrawSupportResistance(rates_total, time, high, low);
         DrawFiboFromLastSwing(rates_total, time, high, low);
      }

      // Самообучение: если мы ставили сигнал N баров назад — проверим, возник ли импульс
      // Для стабильности проверяем только на новом баре
      if(i == rates_total - 1)
      {
         // проверим последний buy-сигнал
         if(g_lastBuySignalTime > 0)
         {
            int shiftSig = iBarShift(_Symbol, _Period, g_lastBuySignalTime, true);
            bool success = false;
            for(int j = shiftSig + 1; j <= MathMin(shiftSig + g_evalWindowBars, rates_total - 1); ++j)
            {
               double atrj = 0;
               GetATR(time[j], atrj);
               if(IsSpikeBar(high[j], low[j], open[j], close[j], atrj, true)) { success = true; break; }
            }
            RecordOutcome(success);
            // сбросим, чтобы не учитывать повторно
            g_lastBuySignalTime = 0;
         }
         if(g_lastSellSignalTime > 0)
         {
            int shiftSig = iBarShift(_Symbol, _Period, g_lastSellSignalTime, true);
            bool success = false;
            for(int j = shiftSig + 1; j <= MathMin(shiftSig + g_evalWindowBars, rates_total - 1); ++j)
            {
               double atrj = 0;
               GetATR(time[j], atrj);
               if(IsSpikeBar(high[j], low[j], open[j], close[j], atrj, false)) { success = true; break; }
            }
            RecordOutcome(success);
            g_lastSellSignalTime = 0;
         }
      }
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Примечания                                                        |
//| 1) Индикатор использует множество встроенных индикаторов MT5.     |
//| 2) Для уменьшения "шума" используются базовые фильтры тренда,     |
//|    волатильности и уровней S/R.                                   |
//| 3) Самообучение: адаптирует порог вероятности на основе качества  |
//|    последних сигналов (успех/ложный).                             |
//| 4) Для тестера стратегий уведомления Alert/Push могут срабатывать.|
//| 5) Для корректной работы Push/Email их нужно включить в терминале.|
//+------------------------------------------------------------------+
