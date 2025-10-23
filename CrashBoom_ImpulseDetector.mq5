#property copyright "Crash/Boom Impulse Detector (c) 2025"
#property version   "1.0"
#property description "Индикатор прогнозирования импульсов (spikes) для индексов Deriv Crash/Boom"
#property description "Комплексный анализ: EMA, RSI, MACD, ATR, Bollinger, Fractals, ADX, SAR, ZigZag(опц.)"
#property indicator_chart_window
#property indicator_plots 2
#property indicator_buffers 2
#property strict

// ---- Параметры входа ----
input int      SpikeDetectionDepth       = 12;      // Глубина анализа фракталов / ZigZag
input int      MovingAveragePeriod1      = 50;      // EMA #1
input int      MovingAveragePeriod2      = 100;     // EMA #2
input int      MovingAveragePeriod3      = 200;     // EMA #3
input int      RSI_Period                = 14;      // Период RSI
input int      MACD_Fast                 = 12;      // MACD fast
input int      MACD_Slow                 = 26;      // MACD slow
input int      MACD_Signal               = 9;       // MACD signal
input int      ATR_Period                = 14;      // ATR
input bool     ShowFibonacciLevels       = true;    // Показывать Фибо-уровни
input bool     EnableAlerts              = true;    // Включить оповещения
input bool     EnablePush                = false;   // Включить Push уведомления (если настроено в терминале)
input bool     EnableEmail               = false;   // Включить Email уведомления (если настроено в терминале)
input int      ArrowSize                 = 2;       // Размер стрелки
input int      ArrowDistance             = 8;       // Смещение стрелки (в пунктах)
input double   SpikePredictionSensitivity= 0.6;     // Чувствительность 0.1..1.5 (чем выше, тем больше сигналов)
input int      SignalLookaheadBars       = 3;       // Горизонт прогноза (кол-во свечей вперёд)
input ENUM_TIMEFRAMES Timeframe          = PERIOD_CURRENT; // Таймфрейм анализа

// ---- Буферы отрисовки ----
double BuyBuffer[];   // стрелки на покупку (Boom)
double SellBuffer[];  // стрелки на продажу (Crash)

// ---- Константы/настройки ----
#define EMPTY 0x7FF8000000000000
#define OBJ_PREFIX "CBID_"
#define MAX_OBJECTS_KEEP 60
#define FILE_WEIGHTS "CrashBoom_ImpulseDetector.weights.csv"

// Стрелки Wingdings: 233 - стрелка вверх, 234 - стрелка вниз
int ArrowUpCode   = 233;
int ArrowDownCode = 234;

// ---- Хэндлы индикаторов ----
int hEMA1 = INVALID_HANDLE;
int hEMA2 = INVALID_HANDLE;
int hEMA3 = INVALID_HANDLE;
int hRSI  = INVALID_HANDLE;
int hMACD = INVALID_HANDLE; // 0-main,1-signal,2-hist
int hATR  = INVALID_HANDLE;
int hBands= INVALID_HANDLE; // 0-upper,1-middle,2-lower
int hSAR  = INVALID_HANDLE; // 0-sar
int hFrUp = INVALID_HANDLE; // 0-up fractal
int hFrDn = INVALID_HANDLE; // 1-down fractal (в MQL5 iFractals: буферы 0 и 1)
int hADX  = INVALID_HANDLE; // 0-main,1+ DI

// ---- Переменные состояния ----
string   g_symbol;
ENUM_TIMEFRAMES g_tf;
datetime g_lastBarTime = 0;
datetime g_lastAlertTime = 0;
int      g_lastAlertDirection = 0; // 1=buy, -1=sell, 0=none

// ---- Простое самообучение (логистическая регрессия) ----
// Вектор признаков: [trendAlign, rsi, macdHist, bbPos, sarDir, adxNorm, atrNorm, div, srProximity, wickScore, bias(=1)]
const int FEATURES = 11;
double   g_weights_boom[FEATURES];
double   g_weights_crash[FEATURES];
double   g_lr = 0.02; // скорость обучения

// ---- Структура для отложенной оценки качества прогноза ----
struct Prediction {
  datetime timeBar;    // время бара, на котором был подан сигнал
  bool     isBoom;     // направление предполагаемого импульса
  int      horizon;    // сколько баров вперёд проверяем
  double   prob;       // вероятность по модели
  bool     processed;  // обработан ли результат
};

Prediction g_preds[]; // кольцевая история прогнозов (последние ~100)

// ---- Прототипы ----
bool   InitIndicators();
void   ReleaseIndicators();
bool   IsBoomSymbol(const string sym);
bool   IsCrashSymbol(const string sym);
void   CleanupOldObjects();
void   DrawFiboIfNeeded();
void   DrawTextLabel(const string id, datetime t, double price, const string text, color clr);
void   PushPrediction(bool isBoom, double prob);
void   EvaluatePredictions(const MqlRates &lastClosed, const double atr_points);
bool   IsSpikeBar(const MqlRates &bar, bool boom, double atr_points);
double Sigmoid(const double x);

double GetFeatureVector(const int barShift,
                        double &trendAlign,
                        double &rsiNorm,
                        double &macdHist,
                        double &bbPos,
                        double &sarDir,
                        double &adxNorm,
                        double &atrNorm,
                        double &divScore,
                        double &srProx,
                        double &wickScore);

double PredictSpikeProb(bool boom, const int barShift,
                        double &trendAlign,
                        double &rsiNorm,
                        double &macdHist,
                        double &bbPos,
                        double &sarDir,
                        double &adxNorm,
                        double &atrNorm,
                        double &divScore,
                        double &srProx,
                        double &wickScore);

void   UpdatePanel(const double prob, const string trendText,
                   const double rsiVal, const double atrPts, const double macdH);
void   LoadWeights();
void   SaveWeights();
void   OnlineLearn(bool boom, const double features[FEATURES], double target);

// ---- Служебные массивы цен ----
MqlRates g_rates[]; // для быстрого доступа к OHLC и времени (текущий ТФ графика)

// ---- Инициализация индикатора ----
int OnInit()
{
  g_symbol = _Symbol;
  g_tf     = (Timeframe==PERIOD_CURRENT ? (ENUM_TIMEFRAMES)Period() : Timeframe);

  // Буферы
  SetIndexBuffer(0, BuyBuffer, INDICATOR_DATA);
  SetIndexBuffer(1, SellBuffer, INDICATOR_DATA);
  PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_ARROW);
  PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_ARROW);
  SetIndexArrow(0, ArrowUpCode);
  SetIndexArrow(1, ArrowDownCode);
  PlotIndexSetInteger(0, PLOT_LINE_COLOR, clrDodgerBlue);
  PlotIndexSetInteger(1, PLOT_LINE_COLOR, clrTomato);
  PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, 0);
  PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, 0);
  PlotIndexSetInteger(0, PLOT_LINE_WIDTH, ArrowSize);
  PlotIndexSetInteger(1, PLOT_LINE_WIDTH, ArrowSize);

  // Значения по умолчанию
  ArrayInitialize(BuyBuffer, EMPTY_VALUE);
  ArrayInitialize(SellBuffer, EMPTY_VALUE);

  // Инициализация индикаторов
  if(!InitIndicators())
  {
    Print("[CBID] Ошибка инициализации индикаторов");
    return(INIT_FAILED);
  }

  // Загружаем веса (если есть), иначе ставим разумные стартовые
  LoadWeights();

  // История прогнозов
  ArrayResize(g_preds, 0);

  return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
  ReleaseIndicators();
  SaveWeights();
  // Очистка объектов, созданных индикатором
  CleanupOldObjects();
  Comment("");
}

// ---- Основной расчёт ----
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
  // Минимально достаточная история
  if(rates_total < MathMax(300, MovingAveragePeriod3+50))
    return(0);

  // Копируем последнюю закрытую свечу графика
  int copied = CopyRates(g_symbol, PERIOD_CURRENT, 0, 300, g_rates);
  if(copied <= 0)
    return(prev_calculated);

  // Определяем событие: новый бар
  datetime currBarTime = time[0];
  bool isNewBar = (g_lastBarTime != currBarTime);
  if(isNewBar)
    g_lastBarTime = currBarTime;

  // Берём значения индикаторов в используемом ТФ
  // Получим ATR (в пунктах графика) на последней закрытой свече этого ТФ
  double atrArr[4];
  ArrayInitialize(atrArr, 0.0);
  if(CopyBuffer(hATR, 0, 0, 2, atrArr) < 2)
    return(prev_calculated);
  double atr_val = atrArr[1]; // последняя закрытая
  double atr_points = atr_val / _Point;

  // Рассчитываем вероятность на последней закрытой свече (shift=1)
  double trendAlign, rsiNorm, macdHist, bbPos, sarDir, adxNorm, atrNorm, divScore, srProx, wickScore;
  double prob = PredictSpikeProb(IsBoomSymbol(g_symbol), 1,
                                 trendAlign, rsiNorm, macdHist, bbPos, sarDir, adxNorm, atrNorm, divScore, srProx, wickScore);

  // Определяем тип инструмента
  bool isBoom = IsBoomSymbol(g_symbol);
  bool isCrash= IsCrashSymbol(g_symbol);

  // Порог вероятности в зависимости от чувствительности
  double baseThr = 0.58; // базовый
  double thr = MathMax(0.50, MathMin(0.80, baseThr - 0.20*(SpikePredictionSensitivity-0.6))); // 0.5..0.8

  // Трендовая подпись для панели
  string trendText = (trendAlign>0.3 ? "Uptrend" : (trendAlign<-0.3 ? "Downtrend" : "Flat"));

  // Обновление панели
  UpdatePanel(prob, trendText, (rsiNorm*50.0+50.0), atr_points, macdHist);

  // Очистка старых объектов не чаще, чем на новом баре
  if(isNewBar)
    CleanupOldObjects();

  // Рисуем Фибо только на новом баре (во избежание мусора)
  if(isNewBar && ShowFibonacciLevels)
    DrawFiboIfNeeded();

  // Сигнал и отрисовка стрелок/подписей на предыдущей свече
  int signalBar = 1; // заранее, до начала импульса
  ArrayInitialize(BuyBuffer, EMPTY_VALUE);
  ArrayInitialize(SellBuffer, EMPTY_VALUE);

  // Для Boom ожидаем рост, для Crash — падение
  if((isBoom || isCrash) && prob >= thr)
  {
    double priceY;
    string labelText;
    color  clr;

    if(isBoom)
    {
      priceY = low[signalBar] - ArrowDistance*_Point;
      BuyBuffer[signalBar] = priceY;
      labelText = "Boom spike soon";
      clr = clrDodgerBlue;
      if(isNewBar) PushPrediction(true, prob);
      if(EnableAlerts && isNewBar)
      {
        if(g_lastAlertTime != time[signalBar] || g_lastAlertDirection != 1)
        {
          Alert(StringFormat("[CBID] %s: вероятен BOOM spike в ближайшие %d свечи (p=%.1f%%)", g_symbol, SignalLookaheadBars, prob*100.0));
          Print(StringFormat("[CBID] %s BOOM spike soon. Prob=%.3f", g_symbol, prob));
          if(EnablePush && (bool)TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED))
            SendNotification(StringFormat("%s: BOOM spike soon (p=%.0f%%)", g_symbol, prob*100.0));
          if(EnableEmail && (bool)TerminalInfoInteger(TERMINAL_EMAIL_ENABLED))
            SendMail("CBID Alert", StringFormat("%s: BOOM spike soon (p=%.0f%%)", g_symbol, prob*100.0));
          g_lastAlertTime = time[signalBar];
          g_lastAlertDirection = 1;
        }
      }
    }
    else if(isCrash)
    {
      priceY = high[signalBar] + ArrowDistance*_Point;
      SellBuffer[signalBar] = priceY;
      labelText = "Crash spike soon";
      clr = clrTomato;
      if(isNewBar) PushPrediction(false, prob);
      if(EnableAlerts && isNewBar)
      {
        if(g_lastAlertTime != time[signalBar] || g_lastAlertDirection != -1)
        {
          Alert(StringFormat("[CBID] %s: вероятен CRASH spike в ближайшие %d свечи (p=%.1f%%)", g_symbol, SignalLookaheadBars, prob*100.0));
          Print(StringFormat("[CBID] %s CRASH spike soon. Prob=%.3f", g_symbol, prob));
          if(EnablePush && (bool)TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED))
            SendNotification(StringFormat("%s: CRASH spike soon (p=%.0f%%)", g_symbol, prob*100.0));
          if(EnableEmail && (bool)TerminalInfoInteger(TERMINAL_EMAIL_ENABLED))
            SendMail("CBID Alert", StringFormat("%s: CRASH spike soon (p=%.0f%%)", g_symbol, prob*100.0));
          g_lastAlertTime = time[signalBar];
          g_lastAlertDirection = -1;
        }
      }
    }

    // Подпись на графике
    string objId = OBJ_PREFIX + "LBL_" + IntegerToString((int)time[signalBar]);
    DrawTextLabel(objId, time[signalBar], priceY, labelText, clr);
  }

  // Оценка ранее сделанных прогнозов на закрытии новой свечи
  if(isNewBar && copied>=SignalLookaheadBars+2)
  {
    // Последняя закрытая свеча = g_rates[1]
    EvaluatePredictions(g_rates[1], atr_points);
  }

  return(rates_total);
}

// ---- ЛОГИКА АНАЛИЗА И ПРОГНОЗИРОВАНИЯ ----

double PredictSpikeProb(bool boom, const int barShift,
                        double &trendAlign,
                        double &rsiNorm,
                        double &macdHist,
                        double &bbPos,
                        double &sarDir,
                        double &adxNorm,
                        double &atrNorm,
                        double &divScore,
                        double &srProx,
                        double &wickScore)
{
  double fTrend, fRSI, fMACD, fBB, fSAR, fADX, fATR, fDIV, fSR, fWick;
  double sum = GetFeatureVector(barShift, fTrend, fRSI, fMACD, fBB, fSAR, fADX, fATR, fDIV, fSR, fWick);
  trendAlign = fTrend; rsiNorm=fRSI; macdHist=fMACD; bbPos=fBB; sarDir=fSAR; adxNorm=fADX; atrNorm=fATR; divScore=fDIV; srProx=fSR; wickScore=fWick;

  // Составляем вектор признаков
  double x[FEATURES];
  x[0]=fTrend; x[1]=fRSI; x[2]=fMACD; x[3]=fBB; x[4]=fSAR; x[5]=fADX; x[6]=fATR; x[7]=fDIV; x[8]=fSR; x[9]=fWick; x[10]=1.0; // bias

  // Вычисляем вероятность через логистическую функцию
  double wsum = 0.0;
  for(int i=0;i<FEATURES;i++)
    wsum += (boom ? g_weights_boom[i] : g_weights_crash[i]) * x[i];
  double p = Sigmoid(wsum);
  return p;
}

// Возвращает сумму признаков (для возможной отладки), а также через ссылки заполняет сами признаки
// barShift: 1 - последняя закрытая, 0 - текущая; используем 1
// Все признаки стараемся нормировать к диапазону [-1..+1]
double GetFeatureVector(const int barShift,
                        double &trendAlign,
                        double &rsiNorm,
                        double &macdHist,
                        double &bbPos,
                        double &sarDir,
                        double &adxNorm,
                        double &atrNorm,
                        double &divScore,
                        double &srProx,
                        double &wickScore)
{
  // EMA блок
  double ema1[4], ema2[4], ema3[4];
  ArrayInitialize(ema1,0.0); ArrayInitialize(ema2,0.0); ArrayInitialize(ema3,0.0);
  CopyBuffer(hEMA1, 0, 0, 3, ema1);
  CopyBuffer(hEMA2, 0, 0, 3, ema2);
  CopyBuffer(hEMA3, 0, 0, 3, ema3);
  double e1 = ema1[barShift];
  double e2 = ema2[barShift];
  double e3 = ema3[barShift];
  // Выравнивание тренда: +1 если e1>e2>e3; -1 если e1<e2<e3
  trendAlign = 0.0;
  if(e1>e2 && e2>e3) trendAlign = 1.0;
  else if(e1<e2 && e2<e3) trendAlign = -1.0;

  // RSI
  double rsiArr[4]; ArrayInitialize(rsiArr,0.0);
  CopyBuffer(hRSI, 0, 0, 3, rsiArr);
  double rsiVal = rsiArr[barShift];
  rsiNorm = (rsiVal-50.0)/50.0; // [-1..+1]

  // MACD histogram
  double macdH[4]; ArrayInitialize(macdH,0.0);
  CopyBuffer(hMACD, 2, 0, 3, macdH);
  macdHist = macdH[barShift];
  // Нормируем MACD через ATR (приближённо в пунктах)
  double atrArr[4]; ArrayInitialize(atrArr,0.0);
  CopyBuffer(hATR, 0, 0, 3, atrArr);
  double atrPts = atrArr[barShift]/_Point;
  if(atrPts>0.0) macdHist = MathMax(-3.0, MathMin(3.0, macdHist/(_Point*atrPts)));

  // Bollinger: позиция цены относительно среднего/стд
  double bbU[4], bbM[4], bbL[4]; ArrayInitialize(bbU,0.0);ArrayInitialize(bbM,0.0);ArrayInitialize(bbL,0.0);
  CopyBuffer(hBands, 0, 0, 3, bbU);
  CopyBuffer(hBands, 1, 0, 3, bbM);
  CopyBuffer(hBands, 2, 0, 3, bbL);
  double closeArr[2]; closeArr[0]=0; closeArr[1]=0; // возьмём Close соответствующего ТФ через iClose
  double lastClose = iClose(g_symbol, g_tf, barShift);
  double stdev = (bbU[barShift]-bbM[barShift]);
  if(stdev>_Point)
    bbPos = MathMax(-2.0, MathMin(2.0, (lastClose - bbM[barShift]) / stdev));
  else bbPos = 0.0;

  // SAR направление: выше цены — медвежий, ниже — бычий
  double sarArr[4]; ArrayInitialize(sarArr,0.0);
  CopyBuffer(hSAR, 0, 0, 3, sarArr);
  double price = lastClose;
  sarDir = (sarArr[barShift] < price ? 1.0 : -1.0);

  // ADX: нормируем 0..1.5 приблизительно
  double adxA[4]; ArrayInitialize(adxA,0.0);
  CopyBuffer(hADX, 0, 0, 3, adxA);
  adxNorm = MathMin(1.5, adxA[barShift]/25.0); // ~>25 тренд

  // ATR нормировка волатильности: (ATR/Point) ~ 0..N, приведём к 0..1.5 через тангенту
  atrNorm = MathMin(1.5, (atrArr[barShift]/_Point)/100.0);

  // Дивергенция (простая) по RSI и MACD на последних 2 фракталах
  // Находим последние два High-фрактала и Low-фрактала
  int lastUpIdx=-1, prevUpIdx=-1, lastDnIdx=-1, prevDnIdx=-1;
  // Фракталы читаем из iFractals: буфер 0 — вверх, буфер 1 — вниз
  double frUp[50], frDn[50]; ArrayInitialize(frUp,EMPTY_VALUE); ArrayInitialize(frDn,EMPTY_VALUE);
  int gotUp = CopyBuffer(hFrUp, 0, 0, 50, frUp);
  int gotDn = CopyBuffer(hFrDn, 1, 0, 50, frDn);
  // Поиск последних индексов
  for(int i=1;i<50;i++){
    if(lastUpIdx==-1 && frUp[i]!=EMPTY_VALUE){ lastUpIdx=i; continue; }
    if(lastUpIdx!=-1 && prevUpIdx==-1 && frUp[i]!=EMPTY_VALUE){ prevUpIdx=i; break; }
  }
  for(int i=1;i<50;i++){
    if(lastDnIdx==-1 && frDn[i]!=EMPTY_VALUE){ lastDnIdx=i; continue; }
    if(lastDnIdx!=-1 && prevDnIdx==-1 && frDn[i]!=EMPTY_VALUE){ prevDnIdx=i; break; }
  }
  double divBull=0.0, divBear=0.0;
  if(lastUpIdx>0 && prevUpIdx>0){
    double ph1 = iHigh(g_symbol, g_tf, lastUpIdx);
    double ph2 = iHigh(g_symbol, g_tf, prevUpIdx);
    double r1  = iRSI(g_symbol, g_tf, RSI_Period, PRICE_CLOSE);
    // Получаем RSI значением по shift (приближенно через iRSI+CopyBuffer)
    double rbuf[60]; ArrayInitialize(rbuf,0.0);
    int h = iRSI(g_symbol, g_tf, RSI_Period, PRICE_CLOSE);
    CopyBuffer(h, 0, 0, MathMax(lastUpIdx,prevUpIdx)+2, rbuf);
    double rsi1=rbuf[lastUpIdx]; double rsi2=rbuf[prevUpIdx];
    if(ph1>ph2 && rsi1<rsi2) divBear=1.0; // медвежья дивергенция
  }
  if(lastDnIdx>0 && prevDnIdx>0){
    double pl1 = iLow(g_symbol, g_tf, lastDnIdx);
    double pl2 = iLow(g_symbol, g_tf, prevDnIdx);
    double rbuf2[60]; ArrayInitialize(rbuf2,0.0);
    int h2 = iRSI(g_symbol, g_tf, RSI_Period, PRICE_CLOSE);
    CopyBuffer(h2, 0, 0, MathMax(lastDnIdx,prevDnIdx)+2, rbuf2);
    double rsi1=rbuf2[lastDnIdx]; double rsi2=rbuf2[prevDnIdx];
    if(pl1<pl2 && rsi1>rsi2) divBull=1.0; // бычья дивергенция
  }
  // Объединим: бычья +1, медвежья -1
  divScore = divBull - divBear; // -1..+1

  // Близость к S/R: расстояние до ближайшего фрактала в ATR
  double currClose = iClose(g_symbol, g_tf, barShift);
  double nearFr = 0.0; double best = 1e9;
  for(int i=1;i<50;i++){
    if(frUp[i]!=EMPTY_VALUE){ double d = MathAbs(frUp[i]-currClose); if(d<best){best=d; nearFr=frUp[i];} }
    if(frDn[i]!=EMPTY_VALUE){ double d = MathAbs(frDn[i]-currClose); if(d<best){best=d; nearFr=frDn[i];} }
  }
  if(atrArr[barShift]>_Point)
    srProx = 1.0 - MathMin(1.0, (best/atrArr[barShift])); // ближе — больше
  else srProx = 0.0;

  // Свечной признак: длинная тень в сторону вероятного импульса
  // Возьмём бар текущего ТФ
  MqlRates r[]; ArraySetAsSeries(r,true);
  int got = CopyRates(g_symbol, g_tf, 0, 5, r);
  double wickUp=0.0, wickDn=0.0;
  if(got>=barShift+2){
    double H = r[barShift].high; double L = r[barShift].low;
    double O = r[barShift].open; double C = r[barShift].close;
    double body = MathAbs(C-O); double range = H-L;
    double upW = H - MathMax(C,O);
    double dnW = MathMin(C,O) - L;
    wickUp = (range>0? upW/range : 0.0);
    wickDn = (range>0? dnW/range : 0.0);
  }
  // Максимальная из двух теней со знаком: если нижняя больше — +, если верхняя — -
  wickScore = (wickDn>=wickUp? +wickDn : -wickUp); // [-1..+1]

  // Суммарная величина (не используется напрямую, но оставим для отладки)
  double sum = trendAlign + rsiNorm + macdHist + bbPos + sarDir + adxNorm + atrNorm + divScore + srProx + wickScore;
  return sum;
}

// ---- Панель ----
void UpdatePanel(const double prob, const string trendText,
                 const double rsiVal, const double atrPts, const double macdH)
{
  string s = StringFormat("%s  |  Trend: %s  |  Prob: %.1f%%  |  RSI: %.1f  |  ATR: %.0f pts  |  MACD(H): %.3f",
                          g_symbol, trendText, prob*100.0, rsiVal, atrPts, macdH);
  Comment(s);
}

// ---- Работа с объектами ----
void DrawTextLabel(const string id, datetime t, double price, const string text, color clr)
{
  if(ObjectFind(0,id)>=0)
  {
    ObjectSetInteger(0,id,OBJPROP_TIME, t);
    ObjectSetDouble(0,id,OBJPROP_PRICE, price);
    ObjectSetString(0,id,OBJPROP_TEXT, text);
    ObjectSetInteger(0,id,OBJPROP_COLOR, clr);
    return;
  }
  ObjectCreate(0,id,OBJ_TEXT,0,t,price);
  ObjectSetString(0,id,OBJPROP_TEXT, text);
  ObjectSetInteger(0,id,OBJPROP_COLOR, clr);
  ObjectSetInteger(0,id,OBJPROP_FONTSIZE, 10);
  ObjectSetString(0,id,OBJPROP_FONT, "Arial");
  ObjectSetInteger(0,id,OBJPROP_BACK, false);
}

void CleanupOldObjects()
{
  // Удаляем старые наши объекты, сохраняя последние MAX_OBJECTS_KEEP
  int total = ObjectsTotal(0,-1,-1);
  int kept = 0;
  for(int i=total-1; i>=0; --i)
  {
    string name = ObjectName(0,i,-1,-1);
    if(StringFind(name, OBJ_PREFIX)==0)
    {
      kept++;
      if(kept>MAX_OBJECTS_KEEP)
        ObjectDelete(0,name);
    }
  }
}

void DrawFiboIfNeeded()
{
  // Строим Фибо по последнему значимому свингу (по двум фракталам)
  double frUp[100], frDn[100]; ArrayInitialize(frUp,EMPTY_VALUE); ArrayInitialize(frDn,EMPTY_VALUE);
  CopyBuffer(hFrUp, 0, 0, 100, frUp);
  CopyBuffer(hFrDn, 1, 0, 100, frDn);
  int upIdx=-1, dnIdx=-1;
  for(int i=1;i<100;i++){ if(frUp[i]!=EMPTY_VALUE){ upIdx=i; break; } }
  for(int i=1;i<100;i++){ if(frDn[i]!=EMPTY_VALUE){ dnIdx=i; break; } }
  if(upIdx==-1 || dnIdx==-1) return;
  datetime tUp = iTime(g_symbol,g_tf, upIdx);
  datetime tDn = iTime(g_symbol,g_tf, dnIdx);
  double   pUp = frUp[upIdx];
  double   pDn = frDn[dnIdx];

  // Удалим предыдущий Фибо
  string fiboName = OBJ_PREFIX+"FIBO";
  if(ObjectFind(0,fiboName)>=0)
    ObjectDelete(0,fiboName);

  // Рисуем от более ранней к более поздней точки
  datetime t1 = (tDn < tUp ? tDn : tUp);
  double   p1 = (tDn < tUp ? pDn : pUp);
  datetime t2 = (tDn < tUp ? tUp : tDn);
  double   p2 = (tDn < tUp ? pUp : pDn);

  ObjectCreate(0,fiboName,OBJ_FIBO,0,t1,p1,t2,p2);
  ObjectSetInteger(0,fiboName,OBJPROP_COLOR, clrSilver);
  ObjectSetInteger(0,fiboName,OBJPROP_BACK, true);
  ObjectSetInteger(0,fiboName,OBJPROP_RAY_RIGHT, false);
}

// ---- Прогнозы и обучение ----
void PushPrediction(bool isBoom, double prob)
{
  Prediction p; p.timeBar=g_lastBarTime; p.isBoom=isBoom; p.horizon=SignalLookaheadBars; p.prob=prob; p.processed=false;
  int n = ArraySize(g_preds);
  if(n>200){
    // сдвигаем, чтобы не расти бесконечно
    for(int i=1;i<n;i++) g_preds[i-1]=g_preds[i];
    ArrayResize(g_preds, n-1);
  }
  ArrayResize(g_preds, ArraySize(g_preds)+1);
  g_preds[ArraySize(g_preds)-1] = p;
}

void EvaluatePredictions(const MqlRates &lastClosed, const double atr_points)
{
  // Проверяем все не обработанные прогнозы, у которых окно завершилось
  datetime nowT = lastClosed.time;
  for(int i=0;i<ArraySize(g_preds);i++)
  {
    if(g_preds[i].processed) continue;
    // Начиная с бара прогноза + 1 до + horizon ищем импульс
    int passedBars = (int)SeriesInfoInteger(g_symbol, PERIOD_CURRENT, SERIES_BARS_COUNT); // не совсем точно, но ориентир
    // Считаем по времени: если текущая закрытая свеча старше или равна t_pred + horizon*bar_period, оцениваем
    int secPerBar = (int)PeriodSeconds((int)g_tf);
    if(secPerBar<=0) secPerBar = (int)PeriodSeconds();
    if(nowT >= (g_preds[i].timeBar + (g_preds[i].horizon)*secPerBar))
    {
      // Получаем бары в окне
      bool success=false;
      for(int k=1;k<=g_preds[i].horizon;k++){
        int idx = k; // бар k после прогноза (если сравнивать с последовательностью timeseries)
        MqlRates r[]; ArraySetAsSeries(r,true);
        if(CopyRates(g_symbol, PERIOD_CURRENT, 0, g_preds[i].horizon+5, r)>idx){
          double atr_val;
          double a[4]; if(CopyBuffer(hATR,0,idx,2,a)>=1) atr_val=a[0]; else atr_val = atr_points*_Point;
          success = IsSpikeBar(r[idx], g_preds[i].isBoom, atr_val/_Point);
          if(success) break;
        }
      }
      // Обучаем веса
      double trendAlign, rsiNorm, macdHist, bbPos, sarDir, adxNorm, atrNorm, divScore, srProx, wickScore;
      PredictSpikeProb(g_preds[i].isBoom, 1, trendAlign,rsiNorm,macdHist,bbPos,sarDir,adxNorm,atrNorm,divScore,srProx,wickScore);
      double feats[FEATURES];
      feats[0]=trendAlign; feats[1]=rsiNorm; feats[2]=macdHist; feats[3]=bbPos; feats[4]=sarDir; feats[5]=adxNorm; feats[6]=atrNorm; feats[7]=divScore; feats[8]=srProx; feats[9]=wickScore; feats[10]=1.0;
      OnlineLearn(g_preds[i].isBoom, feats, (success?1.0:0.0));

      g_preds[i].processed = true;
    }
  }
}

bool IsSpikeBar(const MqlRates &bar, bool boom, double atr_points)
{
  // Эвристика импульса: размер свечи (High-Low) >= 3.5*ATR и направление
  double rangePts = (bar.high - bar.low)/_Point;
  if(rangePts < 3.5*atr_points) return false;
  if(boom)
  {
    // бычий импульс: сильный рост
    return (bar.close > bar.open && (bar.high - MathMax(bar.open,bar.close))/_Point < 0.25*atr_points);
  }
  else
  {
    // медвежий импульс: сильное падение
    return (bar.close < bar.open && (MathMin(bar.open,bar.close) - bar.low)/_Point < 0.25*atr_points);
  }
}

void OnlineLearn(bool boom, const double features[FEATURES], double target)
{
  // Логистическая регрессия: w := w + lr*(target - p)*x
  double wsum=0.0;
  for(int i=0;i<FEATURES;i++)
    wsum += (boom?g_weights_boom[i]:g_weights_crash[i])*features[i];
  double p = Sigmoid(wsum);
  double error = (target - p);
  for(int i=0;i<FEATURES;i++)
  {
    if(boom) g_weights_boom[i] += g_lr * error * features[i];
    else     g_weights_crash[i]+= g_lr * error * features[i];
  }
}

// ---- Индикаторы ----
bool InitIndicators()
{
  // EMA
  hEMA1 = iMA(g_symbol, g_tf, MovingAveragePeriod1, 0, MODE_EMA, PRICE_CLOSE);
  hEMA2 = iMA(g_symbol, g_tf, MovingAveragePeriod2, 0, MODE_EMA, PRICE_CLOSE);
  hEMA3 = iMA(g_symbol, g_tf, MovingAveragePeriod3, 0, MODE_EMA, PRICE_CLOSE);
  if(hEMA1==INVALID_HANDLE || hEMA2==INVALID_HANDLE || hEMA3==INVALID_HANDLE) return false;

  // RSI
  hRSI  = iRSI(g_symbol, g_tf, RSI_Period, PRICE_CLOSE);
  if(hRSI==INVALID_HANDLE) return false;

  // MACD
  hMACD = iMACD(g_symbol, g_tf, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
  if(hMACD==INVALID_HANDLE) return false;

  // ATR
  hATR  = iATR(g_symbol, g_tf, ATR_Period);
  if(hATR==INVALID_HANDLE) return false;

  // Bollinger (параметры возьмём близкие к стандарту)
  hBands= iBands(g_symbol, g_tf, 20, 2.0, 0, PRICE_CLOSE);
  if(hBands==INVALID_HANDLE) return false;

  // SAR
  hSAR  = iSAR(g_symbol, g_tf, 0.02, 0.2);
  if(hSAR==INVALID_HANDLE) return false;

  // Fractals (в MQL5 iFractals создаёт один хэндл с 2 буферами; для удобства оставим два alias)
  hFrUp = iFractals(g_symbol, g_tf);
  hFrDn = hFrUp;
  if(hFrUp==INVALID_HANDLE) return false;

  // ADX
  hADX  = iADX(g_symbol, g_tf, 14);
  if(hADX==INVALID_HANDLE) return false;

  return true;
}

void ReleaseIndicators()
{
  if(hEMA1!=INVALID_HANDLE) IndicatorRelease(hEMA1);
  if(hEMA2!=INVALID_HANDLE) IndicatorRelease(hEMA2);
  if(hEMA3!=INVALID_HANDLE) IndicatorRelease(hEMA3);
  if(hRSI !=INVALID_HANDLE) IndicatorRelease(hRSI);
  if(hMACD!=INVALID_HANDLE) IndicatorRelease(hMACD);
  if(hATR !=INVALID_HANDLE) IndicatorRelease(hATR);
  if(hBands!=INVALID_HANDLE) IndicatorRelease(hBands);
  if(hSAR !=INVALID_HANDLE) IndicatorRelease(hSAR);
  if(hFrUp!=INVALID_HANDLE) IndicatorRelease(hFrUp);
  if(hADX !=INVALID_HANDLE) IndicatorRelease(hADX);
}

// ---- Вспомогательные ----
bool IsBoomSymbol(const string sym)
{
  string s = StringToLower(sym);
  return (StringFind(s, "boom")>=0);
}

bool IsCrashSymbol(const string sym)
{
  string s = StringToLower(sym);
  return (StringFind(s, "crash")>=0);
}

double Sigmoid(const double x)
{
  if(x>35.0) return 1.0;
  if(x<-35.0) return 0.0;
  return 1.0/(1.0+MathExp(-x));
}

void LoadWeights()
{
  // Попытка загрузить веса из файла (по символу и ТФ)
  for(int i=0;i<FEATURES;i++){ g_weights_boom[i]=0.0; g_weights_crash[i]=0.0; }
  // Разумные стартовые значения (эвристики)
  // trend, rsi, macd, bb, sar, adx, atr, div, sr, wick, bias
  double wb[FEATURES] = { 0.9, 0.6, 0.8, 0.4, 0.4, 0.5, -0.2, 0.7, 0.5, 0.4, -0.5 };
  double wc[FEATURES] = { -0.9,-0.6,-0.8,-0.4,-0.4,-0.5, -0.2,-0.7,-0.5,-0.4, -0.5 };
  ArrayCopy(g_weights_boom, wb);
  ArrayCopy(g_weights_crash,wc);

  int h = FileOpen(FILE_WEIGHTS, FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON, ';');
  if(h==INVALID_HANDLE) return;
  while(!FileIsEnding(h))
  {
    string sym = FileReadString(h);
    int    tf  = (int)FileReadInteger(h);
    string kind= FileReadString(h); // "boom"/"crash"
    if(sym==g_symbol && tf==(int)g_tf)
    {
      for(int i=0;i<FEATURES;i++)
      {
        double v = FileReadNumber(h);
        if(kind=="boom") g_weights_boom[i]=v; else g_weights_crash[i]=v;
      }
    }
    else
    {
      // пропустить числа
      for(int i=0;i<FEATURES;i++) (void)FileReadNumber(h);
    }
  }
  FileClose(h);
}

void SaveWeights()
{
  // Перезаписываем файл. В реальном использовании стоило бы сливать/сохранять все символы, но здесь — только текущие
  int h = FileOpen(FILE_WEIGHTS, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ';');
  if(h==INVALID_HANDLE) return;
  FileWriteString(h, g_symbol); FileWriteString(h, ";"); FileWriteInteger(h, (int)g_tf); FileWriteString(h, ";boom");
  for(int i=0;i<FEATURES;i++){ FileWriteString(h, ";"); FileWriteNumber(h, g_weights_boom[i]); }
  FileWriteString(h, "\n");
  FileWriteString(h, g_symbol); FileWriteString(h, ";"); FileWriteInteger(h, (int)g_tf); FileWriteString(h, ";crash");
  for(int i=0;i<FEATURES;i++){ FileWriteString(h, ";"); FileWriteNumber(h, g_weights_crash[i]); }
  FileWriteString(h, "\n");
  FileClose(h);
}
