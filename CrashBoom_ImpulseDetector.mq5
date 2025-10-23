//+------------------------------------------------------------------+
//|                                                CrashBoom_ImpulseDetector.mq5 |
//|                                               (c) 2025 Cursor AI             |
//|  Назначение: Индикатор для индексов Deriv Crash/Boom.                        |
//|  Выполняет комплексный анализ (EMA/RSI/MACD/ATR/BB/Fractals/ZigZag/Fibo),     |
//|  оценивает вероятность скорого импульса (spike) и предупреждает заранее.      |
//|  Визуализация: стрелки, подписи, информативная панель, оповещения.           |
//|  Самокоррекция чувствительности на основе точности последних сигналов.       |
//+------------------------------------------------------------------+
#property copyright "(c) 2025 Cursor AI"
#property link      "https://example.com"
#property version   "1.00"
#property description "Deriv Crash/Boom: прогноз вероятного спайка заранее"
#property strict

#property indicator_chart_window
#property indicator_plots 1
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrDodgerBlue
#property indicator_width1  1
#property indicator_label1  "SpikePrediction"

#include <Trade/Trade.mqh>

//--- Буферы
double      SignalBuffer[];          // Отрисовка стрелки в буфере (дополнительно к объектам)

//--- Префикс объектов
string      OBJ_PREFIX = "CBID_";    // CrashBoom Impulse Detector

//--- Входные параметры
input group               "Основные настройки"
input ENUM_TIMEFRAMES     InpTimeframe              = PERIOD_CURRENT; // Таймфрейм анализа
input int                 SpikeDetectionDepth       = 24;             // Глубина анализа фракталов/зигзага
input double              SpikePredictionSensitivity= 0.58;           // Базовая чувствительность вероятности [0..1]
input bool                EnableAlerts              = true;           // Включить оповещения (Alert/Push/Mail)
input bool                ShowFibonacciLevels       = true;           // Рисовать уровни Фибоначчи при сигнале
input int                 ArrowSize                 = 2;              // Размер стрелки буфера
input int                 ArrowDistance             = 8;              // Смещение стрелки от High/Low (в пунктах)

input group               "Скользящие средние (тренд)"
input int                 MovingAveragePeriod1      = 50;             // EMA 1
input int                 MovingAveragePeriod2      = 100;            // EMA 2
input int                 MovingAveragePeriod3      = 200;            // EMA 3

input group               "RSI/MACD/ATR"
input int                 RSI_Period                = 14;             // RSI период
input int                 MACD_Fast                 = 12;             // MACD fast
input int                 MACD_Slow                 = 26;             // MACD slow
input int                 MACD_Signal               = 9;              // MACD signal
input int                 ATR_Period                = 14;             // ATR период

input group               "Панель"
input bool                ShowPanel                 = true;           // Показывать панель статуса
input int                 PanelCorner               = 0;              // 0=LEFT_UPPER, 1=RIGHT_UPPER, 2=LEFT_LOWER, 3=RIGHT_LOWER
input int                 PanelX                    = 8;              // Отступ по X
input int                 PanelY                    = 24;             // Отступ по Y

//--- Хэндлы индикаторов
int hEMA1=-1, hEMA2=-1, hEMA3=-1;
int hRSI=-1, hMACD=-1, hATR=-1, hBands=-1, hFractals=-1, hZigZag=-1;

//--- Служебные
int               DigitsAdjust=0;
double            PointValue=0;
bool              IsCrash=false, IsBoom=false;
string            SymbolName;
ENUM_TIMEFRAMES   TF;

//--- Само-калибровка
double            dynSensitivity;              // динамическая чувствительность [0..1]
double            hitRateEwma = 0.5;          // экспоненциальная оценка точности
double            calibrAlpha = 0.10;         // скорость адаптации
int               evalWindowBars = 5;         // окно для оценки, через сколько баров проверять факт спайка
int               pendingMax = 16;            // макс. «ожидающих» сигналов для оценки

struct PendingSignal
{
   datetime timeSent;     // время бара (таймфрейм графика), на котором подали сигнал
   bool     isBuy;        // true для Boom прогноз (рост), false для Crash (падение)
   bool     evaluated;    // уже оценивали исход
};
CArrayObj pendingSignals; // хранение указателей на PendingSignal

//--- Ограничение засорения графика
int      MaxObjects = 200;       // максимум объектов с нашим префиксом
int      MaxAgeBars = 2000;      // удалять объекты, которые старше этого количества баров

//--- Последний сигнал, чтобы не дублировать
datetime lastSignalBarTime = 0;

//--- Прототипы
bool      CreateHandles();
void      ReleaseHandles();
bool      IsValid();
bool      DetectSymbolType();
int       ShiftOnTF(datetime t);
double    GetValueAt(const int handle, const int buffer, const int tfShift, bool &ok);

bool      ComputeTrend(double &trendScore, string &trendDir, int tfShift);
bool      ComputeDivergence(bool bullishSetup, double &divScore, int tfShift);
bool      ComputeVolatility(double &atr, double &volScore, int tfShift);
bool      ComputeFractalSR(double &srScore, double &nearestUp, double &nearestDn, int tfShift);
bool      ComputeFiboLevels(double &fiboScore, int tfShift, double &lastSwingHigh, double &lastSwingLow);

double    ComputeConfluenceProbability(bool bullishSetup, int tfShift, string &explain);
bool      PredictSpike(bool bullishSetup, int &predictWithinBars, double &prob, int tfShift, string &explain);

void      DrawSignalObjects(int chartShift, bool bullish, double price, double prob, const string &reason);
void      DrawPanel(double prob, const string &trendDir, double rsi, double atr, double macd, bool bullishSetup);
void      CleanupObjects(const datetime &barTimeNow);

bool      CheckSpikeOutcome(datetime fromBarTime, bool bullish, int windowBars, double atrCurr);
void      UpdateCalibration(const datetime &barTimeNow, double atrCurr);
void      AddPendingSignal(datetime t, bool isBuy);

string    FormatPercent(double x);
bool      TryInitZigZag();

//+------------------------------------------------------------------+
//| ИНИЦИАЛИЗАЦИЯ                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME, "CrashBoom Impulse Detector");
   // буфер для стрелок (дополнительно к объектам)
   SetIndexBuffer(0, SignalBuffer, INDICATOR_DATA);
   ArraySetAsSeries(SignalBuffer, true);
   PlotIndexSetInteger(0, PLOT_ARROW, 233); // стрелка вверх по умолчанию (для буфера)
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, ArrowSize);
   PlotIndexSetString(0, PLOT_LABEL, "SpikePrediction");

   SymbolName = _Symbol;
   TF         = InpTimeframe==PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : InpTimeframe;
   PointValue = SymbolInfoDouble(SymbolName, SYMBOL_POINT);
   DigitsAdjust = (int)SymbolInfoInteger(SymbolName, SYMBOL_DIGITS);

   DetectSymbolType();

   if(!CreateHandles())
      return(INIT_FAILED);

   // Загрузка чувствительности из глобальных переменных терминала (персистентность)
   string gKey = StringFormat("CBID_SENS_%s", SymbolName);
   double gVal;
   if(GlobalVariableCheck(gKey))
   {
      gVal = GlobalVariableGet(gKey);
      if(gVal > 0.05 && gVal < 0.95) dynSensitivity = gVal; else dynSensitivity = SpikePredictionSensitivity;
   }
   else
   {
      dynSensitivity = SpikePredictionSensitivity;
      GlobalVariableSet(gKey, dynSensitivity);
   }

   // Подготовка контейнера ожидающих сигналов
   pendingSignals.Create();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| ДЕИНИЦИАЛИЗАЦИЯ                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ReleaseHandles();
   // сохранить динамическую чувствительность
   GlobalVariableSet(StringFormat("CBID_SENS_%s", SymbolName), dynSensitivity);

   // очистка объектов с префиксом
   int total = ObjectsTotal(0, 0, -1);
   for(int i=total-1; i>=0; --i)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, OBJ_PREFIX) == 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| ОСНОВНОЙ РАСЧЁТ                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < 300 || !IsValid())
      return(prev_calculated);

   // анализируем последний закрытый бар графика
   int last = rates_total - 2;
   datetime barTime = time[last];
   int tfShift = ShiftOnTF(barTime);
   if(tfShift < 0)
      return(prev_calculated);

   // Очистка старых объектов
   CleanupObjects(barTime);

   // Обновить самокалибровку по завершившимся сигналам
   bool okATR=false; double atrCurr = GetValueAt(hATR, 0, tfShift, okATR);
   if(okATR && atrCurr>0)
      UpdateCalibration(barTime, atrCurr);

   // Вычисление вероятности
   bool bullishSetup = IsBoom; // для Boom ищем buy spike (рост), для Crash — sell spike
   string explain="";
   double prob=0.0; int withinBars=0;
   bool willSpike = PredictSpike(bullishSetup, withinBars, prob, tfShift, explain);

   // Снять предыдущую отметку в буфере
   SignalBuffer[last] = EMPTY_VALUE;

   // Данные панели
   // rsi/macd для панели
   bool okRSI=false; double rsi = GetValueAt(hRSI, 0, tfShift, okRSI);
   bool okM1=false, okM2=false; double macdMain = GetValueAt(hMACD, 0, tfShift, okM1);
   double macdSig  = GetValueAt(hMACD, 1, tfShift, okM2);
   double macdLine = (okM1 && okM2) ? (macdMain - macdSig) : 0.0;

   string trendDir="Neutral"; double trendScore=0.0; ComputeTrend(trendScore, trendDir, tfShift);
   if(ShowPanel)
      DrawPanel(prob, trendDir, okRSI?rsi:0.0, okATR?atrCurr:0.0, macdLine, bullishSetup);

   // Сигнал: рисуем и оповещаем один раз на бар
   if(willSpike && prob >= dynSensitivity)
   {
      if(lastSignalBarTime != barTime)
      {
         // Координата для стрелки
         double price = bullishSetup ? low[last] - ArrowDistance*PointValue : high[last] + ArrowDistance*PointValue;

         DrawSignalObjects(last, bullishSetup, price, prob, explain);

         // Буферная стрелка (в цвет по умолчанию; основной — объект)
         PlotIndexSetInteger(0, PLOT_ARROW, bullishSetup?233:234);
         SignalBuffer[last] = price;

         if(EnableAlerts)
         {
            string title = StringFormat("%s: %s spike soon (prob %s)", SymbolName, bullishSetup?"Boom":"Crash", FormatPercent(prob));
            Alert(title);
            Print(title+" | "+explain);
            // Push / Mail по желанию пользователя (в терминале должны быть включены настройки)
            SendNotification(title);
            // Можно указать Email получателя в настройках терминала
            SendMail("CBID alert", title);
         }

         lastSignalBarTime = barTime;
         AddPendingSignal(barTime, bullishSetup);
      }
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| СОЗДАНИЕ/ОСВОБОЖДЕНИЕ ХЭНДЛОВ                                    |
//+------------------------------------------------------------------+
bool CreateHandles()
{
   ReleaseHandles();
   // EMA
   hEMA1 = iMA(SymbolName, TF, MovingAveragePeriod1, 0, MODE_EMA, PRICE_CLOSE);
   hEMA2 = iMA(SymbolName, TF, MovingAveragePeriod2, 0, MODE_EMA, PRICE_CLOSE);
   hEMA3 = iMA(SymbolName, TF, MovingAveragePeriod3, 0, MODE_EMA, PRICE_CLOSE);
   // RSI, MACD, ATR, Bands, Fractals
   hRSI  = iRSI(SymbolName, TF, RSI_Period, PRICE_CLOSE);
   hMACD = iMACD(SymbolName, TF, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
   hATR  = iATR(SymbolName, TF, ATR_Period);
   hBands= iBands(SymbolName, TF, 20, 2.0, 0, PRICE_CLOSE);
   hFractals = iFractals(SymbolName, TF);

   // ZigZag (путь может отличаться в сборках терминала)
   if(!TryInitZigZag())
   {
      Print("[CBID] Не удалось создать ZigZag. Проверьте наличие стандартного индикатора ZigZag.");
   }

   bool ok = (hEMA1>0 && hEMA2>0 && hEMA3>0 && hRSI>0 && hMACD>0 && hATR>0 && hBands>0 && hFractals>0);
   return(ok);
}

void ReleaseHandles()
{
   int hs[8]; int idx=0;
   hs[idx++]=hEMA1; hs[idx++]=hEMA2; hs[idx++]=hEMA3; hs[idx++]=hRSI; hs[idx++]=hMACD; hs[idx++]=hATR; hs[idx++]=hBands; hs[idx++]=hFractals;
   for(int i=0;i<idx;i++)
   {
      if(hs[i]>0)
         IndicatorRelease(hs[i]);
   }
   if(hZigZag>0) IndicatorRelease(hZigZag);
   hEMA1=hEMA2=hEMA3=hRSI=hMACD=hATR=hBands=hFractals=hZigZag=-1;
}

bool TryInitZigZag()
{
   // Попытки нескольких путей (в разных терминалах может отличаться)
   hZigZag = iCustom(SymbolName, TF, "ZigZag", SpikeDetectionDepth, 5, 3);
   if(hZigZag>0) return(true);
   hZigZag = iCustom(SymbolName, TF, "Examples\\ZigZag", SpikeDetectionDepth, 5, 3);
   if(hZigZag>0) return(true);
   hZigZag = iCustom(SymbolName, TF, "\nZigZag", SpikeDetectionDepth, 5, 3);
   return(hZigZag>0);
}

//+------------------------------------------------------------------+
//| УТИЛИТЫ                                                          |
//+------------------------------------------------------------------+
bool IsValid()
{
   return(hEMA1>0 && hEMA2>0 && hEMA3>0 && hRSI>0 && hMACD>0 && hATR>0 && hBands>0 && hFractals>0);
}

bool DetectSymbolType()
{
   string s = StringToLower(SymbolName);
   IsCrash = (StringFind(s, "crash")>=0);
   IsBoom  = (StringFind(s, "boom")>=0);
   return(IsCrash || IsBoom);
}

int ShiftOnTF(datetime t)
{
   int shift = iBarShift(SymbolName, TF, t, true);
   return(shift);
}

double GetValueAt(const int handle, const int buffer, const int tfShift, bool &ok)
{
   ok=false;
   if(handle<=0 || tfShift<0) return(0.0);
   double tmp[1];
   int copied = CopyBuffer(handle, buffer, tfShift, 1, tmp);
   if(copied!=1) return(0.0);
   if(tmp[0]==EMPTY_VALUE) return(0.0);
   ok=true; return(tmp[0]);
}

//+------------------------------------------------------------------+
//| АНАЛИТИКА                                                        |
//+------------------------------------------------------------------+
bool ComputeTrend(double &trendScore, string &trendDir, int tfShift)
{
   trendScore=0.0; trendDir="Neutral";
   bool o1=false,o2=false,o3=false; double ema1=GetValueAt(hEMA1,0,tfShift,o1); double ema2=GetValueAt(hEMA2,0,tfShift,o2); double ema3=GetValueAt(hEMA3,0,tfShift,o3);
   if(!(o1&&o2&&o3)) return(false);

   // Цена
   bool oc=false; double price=0.0;
   MqlRates rt[]; ArraySetAsSeries(rt, true);
   if(CopyRates(SymbolName, TF, tfShift, 2, rt)==2) { oc=true; price=rt[0].close; }

   bool up = (ema1>ema2 && ema2>ema3);
   bool dn = (ema1<ema2 && ema2<ema3);
   if(up) trendDir="Up"; else if(dn) trendDir="Down";

   // очки тренда: 0..1
   if(up)
   {
      trendScore += 0.6;
      if(oc && price>ema1) trendScore += 0.2;
      // угол (приблизительно): сравним текущее и предыдущее
      bool p1=false,p2=false,p3=false; double ema1p=GetValueAt(hEMA1,0,tfShift+5,p1); double ema3p=GetValueAt(hEMA3,0,tfShift+5,p3);
      if(p1&&p3 && (ema1-ema1p)>(ema3-ema3p)) trendScore += 0.2;
   }
   else if(dn)
   {
      trendScore += 0.6;
      if(oc && price<ema1) trendScore += 0.2;
      bool p1=false,p3=false; double ema1p=GetValueAt(hEMA1,0,tfShift+5,p1); double ema3p=GetValueAt(hEMA3,0,tfShift+5,p3);
      if(p1&&p3 && (ema1p-ema1)>(ema3p-ema3)) trendScore += 0.2;
   }
   trendScore = MathMin(1.0, MathMax(0.0, trendScore));
   return(true);
}

// Поиск двух последних экстремумов ZigZag
int GetLastZigZagPoints(int maxScan, int &idx1, double &price1, int &idx2, double &price2)
{
   idx1=idx2=-1; price1=price2=0.0;
   if(hZigZag<=0) return(0);
   int count= MathMax(200, maxScan);
   double zz[]; ArraySetAsSeries(zz, true);
   int copied = CopyBuffer(hZigZag, 0, 0, count, zz);
   if(copied<=0) return(0);
   int found=0;
   for(int i=0;i<copied;i++)
   {
      if(zz[i]!=0.0 && zz[i]!=EMPTY_VALUE)
      {
         if(found==0){ idx1=i; price1=zz[i]; found=1; }
         else if(found==1){ idx2=i; price2=zz[i]; found=2; break; }
      }
   }
   return(found);
}

bool ComputeDivergence(bool bullishSetup, double &divScore, int tfShift)
{
   divScore=0.0;
   int i1=-1,i2=-1; double p1=0.0,p2=0.0;
   if(GetLastZigZagPoints(600, i1,p1, i2,p2)<2) return(false);

   // Возьмем значения RSI и MACD в точках i1, i2 (смещение относительно tfShift)
   bool ok1=false,ok2=false,ok3=false,ok4=false;
   double rsi1=GetValueAt(hRSI,0, tfShift + i2, ok1);
   double rsi2=GetValueAt(hRSI,0, tfShift + i1, ok2);
   double m1=GetValueAt(hMACD,0, tfShift + i2, ok3);
   double s1=GetValueAt(hMACD,1, tfShift + i2, ok4);
   double macd1=(ok3&&ok4)?(m1-s1):0.0;
   ok3=false; ok4=false;
   double m2=GetValueAt(hMACD,0, tfShift + i1, ok3);
   double s2=GetValueAt(hMACD,1, tfShift + i1, ok4);
   double macd2=(ok3&&ok4)?(m2-s2):0.0;

   if(!(ok1&&ok2)) return(false);

   // Тип дивергенции
   bool priceHigherHigh  = (p1>p2);
   bool priceLowerLow    = (p1<p2);
   bool rsiLowerHigh     = (rsi2<rsi1);
   bool rsiHigherLow     = (rsi2>rsi1);
   bool macdLowerHigh    = (macd2<macd1);
   bool macdHigherLow    = (macd2>macd1);

   bool bullishDiv = (priceLowerLow && (rsiHigherLow || macdHigherLow));
   bool bearishDiv = (priceHigherHigh && (rsiLowerHigh  || macdLowerHigh));

   if(bullishSetup && bullishDiv) divScore = 0.8; // сильная
   else if((!bullishSetup) && bearishDiv) divScore = 0.8;
   else divScore = 0.0;

   return(true);
}

bool ComputeVolatility(double &atr, double &volScore, int tfShift)
{
   bool ok=false; atr = GetValueAt(hATR, 0, tfShift, ok);
   if(!ok || atr<=0){ volScore=0.0; return(false);}  
   // Нормализация: отношение ATR к цене
   MqlRates rt[]; ArraySetAsSeries(rt,true);
   if(CopyRates(SymbolName, TF, tfShift, 2, rt)!=2){ volScore=0.0; return(false);} 
   double price = rt[0].close;
   double ratio = atr / MathMax(0.0000001, price);
   // Считаем «здоровую» волатильность в пределах 0.15%-0.6% для синтетики
   // Преобразуем в 0..1 (колокол вокруг 0.35%)
   double target=0.0035; // 0.35%
   double dev   = MathAbs(ratio-target);
   volScore = MathMax(0.0, 1.0 - (dev/0.0035));
   volScore = MathMin(1.0, volScore);
   return(true);
}

bool ComputeFractalSR(double &srScore, double &nearestUp, double &nearestDn, int tfShift)
{
   srScore=0.0; nearestUp=0.0; nearestDn=0.0;
   if(hFractals<=0) return(false);
   // скан последних 400 баров на TF
   int scan=400;
   double up[], dn[]; ArraySetAsSeries(up,true); ArraySetAsSeries(dn,true);
   int c1=CopyBuffer(hFractals, 0, tfShift, scan, up); // верх
   int c2=CopyBuffer(hFractals, 1, tfShift, scan, dn); // низ
   if(c1<=0 || c2<=0) return(false);

   // текущая цена
   MqlRates rt[]; ArraySetAsSeries(rt,true);
   if(CopyRates(SymbolName, TF, tfShift, 2, rt)!=2) return(false);
   double price = rt[0].close;

   // Ближайшие уровни
   for(int i=0;i<c1;i++)
   {
      if(up[i]!=0.0 && up[i]!=EMPTY_VALUE){ nearestUp=up[i]; break; }
   }
   for(int i=0;i<c2;i++)
   {
      if(dn[i]!=0.0 && dn[i]!=EMPTY_VALUE){ nearestDn=dn[i]; break; }
   }
   if(nearestUp==0.0 && nearestDn==0.0) return(false);

   // Счёт: ближе к одному из уровней — тем выше значимость
   double bestDist = 1e10;
   if(nearestUp>0) bestDist = MathMin(bestDist, MathAbs(nearestUp-price));
   if(nearestDn>0) bestDist = MathMin(bestDist, MathAbs(price-nearestDn));
   if(bestDist<=0) bestDist = PointValue;

   // нормализуем через ATR
   bool ok=false; double atr = GetValueAt(hATR, 0, tfShift, ok);
   if(!ok || atr<=0) return(false);
   srScore = MathMin(1.0, MathMax(0.0, 1.0 - (bestDist/(2.0*atr))));
   return(true);
}

bool ComputeFiboLevels(double &fiboScore, int tfShift, double &lastSwingHigh, double &lastSwingLow)
{
   fiboScore=0.0; lastSwingHigh=0.0; lastSwingLow=0.0;
   int i1=-1,i2=-1; double p1=0.0,p2=0.0;
   if(GetLastZigZagPoints(800, i1,p1, i2,p2)<2) return(false);
   lastSwingHigh = (p1>p2? p1:p2);
   lastSwingLow  = (p1<p2? p1:p2);
   if(lastSwingHigh<=0 || lastSwingLow<=0) return(false);

   // Текущее значение цены
   MqlRates rt[]; ArraySetAsSeries(rt,true);
   if(CopyRates(SymbolName, TF, tfShift, 2, rt)!=2) return(false);
   double price = rt[0].close;

   // Уровни 0.382 / 0.618 / 0.786
   double len = lastSwingHigh - lastSwingLow; if(len<=0) return(false);
   double f382 = lastSwingHigh - 0.382*len;
   double f618 = lastSwingHigh - 0.618*len;
   double f786 = lastSwingHigh - 0.786*len;

   double dist = MathMin(MathAbs(price-f382), MathMin(MathAbs(price-f618), MathAbs(price-f786)));

   // Нормализация через ATR
   bool ok=false; double atr = GetValueAt(hATR, 0, tfShift, ok);
   if(!ok || atr<=0) return(false);
   fiboScore = MathMin(1.0, MathMax(0.0, 1.0 - dist/(2.0*atr)));
   return(true);
}

// Композитная вероятность [0..1] + краткое объяснение
double ComputeConfluenceProbability(bool bullishSetup, int tfShift, string &explain)
{
   double trendScore=0; string tdir="Neutral"; ComputeTrend(trendScore, tdir, tfShift);
   double divScore=0;   ComputeDivergence(bullishSetup, divScore, tfShift);
   double atr=0, volScore=0; ComputeVolatility(atr, volScore, tfShift);
   double srScore=0, up=0, dn=0; ComputeFractalSR(srScore, up, dn, tfShift);
   double fiboScore=0, hi=0, lo=0; ComputeFiboLevels(fiboScore, tfShift, hi, lo);

   // веса (можно оптимизировать в тестере стратегий)
   double wTrend=0.35, wDiv=0.25, wSR=0.20, wVol=0.10, wFibo=0.10;
   double score = wTrend*trendScore + wDiv*divScore + wSR*srScore + wVol*volScore + wFibo*fiboScore;

   // логистическая нормализация вокруг dynSensitivity
   double k=6.0; double x = score - dynSensitivity; // центр на чувствительности
   double prob = 1.0/(1.0 + MathExp(-k*x));

   explain = StringFormat("trend=%.2f, div=%.2f, sr=%.2f, vol=%.2f, fibo=%.2f, score=%.2f",
                          trendScore, divScore, srScore, volScore, fiboScore, score);
   return(prob);
}

bool PredictSpike(bool bullishSetup, int &predictWithinBars, double &prob, int tfShift, string &explain)
{
   prob = ComputeConfluenceProbability(bullishSetup, tfShift, explain);
   // эвристика: чем выше prob над порогом, тем раньше ожидаем: [1..5]
   double over = MathMax(0.0, prob - dynSensitivity);
   if(over<=0){ predictWithinBars=0; return(false);}   
   if(over>0.35)      predictWithinBars = 1;
   else if(over>0.20) predictWithinBars = 2;
   else if(over>0.10) predictWithinBars = 3;
   else               predictWithinBars = 5;
   return(true);
}

//+------------------------------------------------------------------+
//| ВИЗУАЛИЗАЦИЯ И ОПОВЕЩЕНИЯ                                        |
//+------------------------------------------------------------------+
void DrawSignalObjects(int chartShift, bool bullish, double price, double prob, const string &reason)
{
   // Стрелка как объект (для цвета)
   string nameArrow = StringFormat(OBJ_PREFIX+"ARW_%s_%I64d", bullish?"BUY":"SELL", TimeCurrent());
   color clr = bullish? clrDodgerBlue : clrTomato;
   if(ObjectCreate(0, nameArrow, OBJ_ARROW, 0, 0, 0))
   {
      ObjectSetInteger(0, nameArrow, OBJPROP_TIME, iTime(SymbolName, (ENUM_TIMEFRAMES)_Period, chartShift));
      ObjectSetDouble (0, nameArrow, OBJPROP_PRICE, price);
      ObjectSetInteger(0, nameArrow, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, nameArrow, OBJPROP_WIDTH, MathMax(1, ArrowSize));
      ObjectSetInteger(0, nameArrow, OBJPROP_ARROWCODE, bullish? 233:234);
   }

   // Подпись
   string text = StringFormat("%s spike soon [%s]", bullish?"Boom":"Crash", FormatPercent(prob));
   string nameLbl = StringFormat(OBJ_PREFIX+"LBL_%I64d", TimeCurrent());
   if(ObjectCreate(0, nameLbl, OBJ_TEXT, 0, iTime(SymbolName, (ENUM_TIMEFRAMES)_Period, chartShift), price))
   {
      ObjectSetInteger(0, nameLbl, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, nameLbl, OBJPROP_FONTSIZE, 8);
      ObjectSetString (0, nameLbl, OBJPROP_TEXT, text+"\n"+reason);
   }

   // Фибо между последними свингами
   if(ShowFibonacciLevels)
   {
      double hi=0,lo=0,score=0; if(ComputeFiboLevels(score, ShiftOnTF(iTime(SymbolName,(ENUM_TIMEFRAMES)_Period, chartShift)), hi, lo))
      {
         string nameFibo = StringFormat(OBJ_PREFIX+"FIBO_%I64d", TimeCurrent());
         if(ObjectCreate(0, nameFibo, OBJ_FIBO, 0, TimeCurrent()-86400, hi, TimeCurrent(), lo))
         {
            ObjectSetInteger(0, nameFibo, OBJPROP_COLOR, clrSilver);
            ObjectSetInteger(0, nameFibo, OBJPROP_RAY_RIGHT, false);
         }
      }
   }
}

void DrawPanel(double prob, const string &trendDir, double rsi, double atr, double macd, bool bullishSetup)
{
   string name = OBJ_PREFIX+"PANEL";
   string txt = StringFormat("%s\nTrend: %s\nProb: %s\nRSI: %.1f | ATR: %.5f | MACD: %.5f",
                             bullishSetup?"Mode: Boom (Buy)":"Mode: Crash (Sell)",
                             trendDir, FormatPercent(prob), rsi, atr, macd);

   if(!ObjectFind(0, name))
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, PanelCorner);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, PanelX);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, PanelY);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   }

   ObjectSetString(0, name, OBJPROP_TEXT, txt);
}

void CleanupObjects(const datetime &barTimeNow)
{
   // Ограничиваем общее число объектов с префиксом
   int total = ObjectsTotal(0, 0, -1);
   int kept=0;
   for(int i=total-1;i>=0;i--)
   {
      string nm = ObjectName(0, i, 0, -1);
      if(StringLen(nm)==0) continue;
      if(StringFind(nm, OBJ_PREFIX)!=0) continue;
      kept++;
      // удаляем «очень старые» привязанные к времени объекты
      long type = (long)ObjectGetInteger(0, nm, OBJPROP_TYPE);
      if(type==OBJ_ARROW || type==OBJ_TEXT || type==OBJ_FIBO)
      {
         datetime t = (datetime)ObjectGetInteger(0, nm, OBJPROP_TIME);
         if(t>0)
         {
            // баров назад
            int sh = iBarShift(SymbolName, (ENUM_TIMEFRAMES)_Period, t, true);
            if(sh>MaxAgeBars)
               ObjectDelete(0, nm);
         }
      }
   }

   // если объектов слишком много — удаляем самые старые подряд
   if(kept>MaxObjects)
   {
      for(int i=0;i<(kept-MaxObjects);i++)
      {
         // удаление первого найденного объекта с префиксом
         int tot = ObjectsTotal(0, 0, -1);
         for(int j=0;j<tot;j++)
         {
            string nm = ObjectName(0, j, 0, -1);
            if(StringFind(nm, OBJ_PREFIX)==0){ ObjectDelete(0, nm); break; }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| САМОКАЛИБРОВКА                                                   |
//+------------------------------------------------------------------+
void AddPendingSignal(datetime t, bool isBuy)
{
   // ограничиваем объем
   while(pendingSignals.Total()>=pendingMax)
   {
      CObject *o = pendingSignals.At(0);
      if(o!=NULL) delete o; 
      pendingSignals.Delete(0);
   }
   PendingSignal *ps = new PendingSignal;
   ps.timeSent = t; ps.isBuy=isBuy; ps.evaluated=false;
   pendingSignals.Add(ps);
}

bool CheckSpikeOutcome(datetime fromBarTime, bool bullish, int windowBars, double atrCurr)
{
   // Проверяем в окне следующих N баров наличие движения > k*ATR в нужную сторону
   int startShift = iBarShift(SymbolName, (ENUM_TIMEFRAMES)_Period, fromBarTime, true);
   if(startShift<0) return(false);
   int endShift = MathMax(0, startShift - windowBars);

   for(int sh=startShift-1; sh>=endShift; --sh)
   {
      datetime t = iTime(SymbolName, (ENUM_TIMEFRAMES)_Period, sh);
      if(t<=0) continue;
      double h = iHigh(SymbolName, (ENUM_TIMEFRAMES)_Period, sh);
      double l = iLow(SymbolName,  (ENUM_TIMEFRAMES)_Period, sh);
      double o = iOpen(SymbolName, (ENUM_TIMEFRAMES)_Period, sh);
      if(bullish)
      {
         if((h - o) >= 2.5*atrCurr) return(true); // мощный вверх
      }
      else
      {
         if((o - l) >= 2.5*atrCurr) return(true); // мощный вниз
      }
   }
   return(false);
}

void UpdateCalibration(const datetime &barTimeNow, double atrCurr)
{
   // Оценим все отложенные сигналы, чьё окно N баров уже закрылось
   for(int i=pendingSignals.Total()-1; i>=0; --i)
   {
      PendingSignal *ps = (PendingSignal*)pendingSignals.At(i);
      if(ps==NULL) continue;
      if(ps.evaluated) continue;

      int shStart = iBarShift(SymbolName, (ENUM_TIMEFRAMES)_Period, ps.timeSent, true);
      int shNow   = iBarShift(SymbolName, (ENUM_TIMEFRAMES)_Period, barTimeNow, true);
      if(shStart<0 || shNow<0) continue;
      if((shStart - shNow) >= evalWindowBars)
      {
         // окно завершилось — проверяем исход
         bool success = CheckSpikeOutcome(ps.timeSent, ps.isBuy, evalWindowBars, atrCurr);
         // EWMA
         hitRateEwma = (1.0 - calibrAlpha)*hitRateEwma + calibrAlpha*(success?1.0:0.0);
         // Подстройка чувствительности: если точность низкая — повышаем порог, иначе — понижаем
         if(hitRateEwma < 0.45) dynSensitivity = MathMin(0.90, dynSensitivity + 0.03);
         else if(hitRateEwma > 0.60) dynSensitivity = MathMax(0.20, dynSensitivity - 0.02);

         ps.evaluated = true;
      }
   }
}

//+------------------------------------------------------------------+
//| ВСПОМОГАТЕЛЬНОЕ                                                  |
//+------------------------------------------------------------------+
string FormatPercent(double x)
{
   double v = MathMax(0.0, MathMin(1.0, x))*100.0;
   return(StringFormat("%.1f%%", v));
}

//+------------------------------------------------------------------+
//| КОНЕЦ ФАЙЛА                                                      |
//+------------------------------------------------------------------+
