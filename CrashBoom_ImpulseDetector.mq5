//+------------------------------------------------------------------+
//|                                                  CrashBoom_ImpulseDetector.mq5 |
//|  Назначение: Индикатор прогнозирования импульсов (spikes) для   |
//|  Deriv Crash/Boom индексов на MetaTrader 5                      |
//|                                                                  |
//|  Внимание: Торговля связана с рисками. Данный индикатор         |
//|  предоставляется "как есть" без гарантий.                       |
//+------------------------------------------------------------------+
#property copyright   "OpenAI / Cursor"
#property link        "https://openai.com"
#property version     "1.0.0"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   2

//--- Параметры графики для стрелок
#property indicator_label1  "Boom Spike"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "Crash Spike"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrTomato
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Входные параметры
input group               "Общие настройки"
input ENUM_TIMEFRAMES     InpTimeframe = PERIOD_CURRENT;  // Таймфрейм анализа
input bool                InpEnableAlerts = true;         // Включить оповещения
input bool                InpShowFibonacciLevels = true;  // Показывать Фибо
input int                 InpArrowSize = 2;               // Размер стрелки
input int                 InpArrowDistancePoints = 50;    // Смещение стрелки (в поинтах)
input double              InpSpikePredictionSensitivity = 0.60; // Чувствительность (0..1)

input group               "Параметры детектора"
input int                 InpSpikeDetectionDepth = 12;    // Глубина анализа фракталов
input int                 InpLeadBarsMin = 1;             // Минимум свечей до импульса
input int                 InpLeadBarsMax = 3;             // Максимум свечей до импульса

input group               "EMA (глобальный тренд)"
input int                 InpMAPeriod1 = 50;              // EMA1
input int                 InpMAPeriod2 = 100;             // EMA2
input int                 InpMAPeriod3 = 200;             // EMA3

input group               "RSI / MACD / ATR"
input int                 InpRSIPeriod = 14;              // RSI период
input int                 InpMACDFast = 12;               // MACD Fast
input int                 InpMACDSlow = 26;               // MACD Slow
input int                 InpMACDSignal = 9;              // MACD Signal
input int                 InpATRPeriod = 14;              // ATR период

//--- Константы
#define CB_PREFIX         "CBID_"
#define CB_OBJ_ARROW_BUY  (CB_PREFIX"Arrow_Buy_")
#define CB_OBJ_ARROW_SELL (CB_PREFIX"Arrow_Sell_")
#define CB_OBJ_LABEL      (CB_PREFIX"Panel_Text")
#define CB_OBJ_BG         (CB_PREFIX"Panel_BG")
#define CB_OBJ_FIBO       (CB_PREFIX"Fibo")
#define CB_STATS_PREFIX   (CB_PREFIX"STATS_")

//--- Буферы индикатора
double gBuyArrowBuffer[];          // Буфер стрелок (Boom / Buy)
double gSellArrowBuffer[];         // Буфер стрелок (Crash / Sell)
double gProbabilityBuffer[];       // Буфер вероятности (для DataWindow), не рисуется

//--- Хэндлы встроенных индикаторов
int hEMA1 = INVALID_HANDLE;
int hEMA2 = INVALID_HANDLE;
int hEMA3 = INVALID_HANDLE;
int hRSI  = INVALID_HANDLE;
int hMACD = INVALID_HANDLE;
int hATR  = INVALID_HANDLE;
int hFractals = INVALID_HANDLE;
int hBands = INVALID_HANDLE;

//--- Служебные переменные
bool gIsBoomSymbol = false;
bool gIsCrashSymbol = false;
datetime gLastAlertBarTime = 0;
double gAdaptiveThreshold = 0.0; // адаптивная чувствительность (0..1)

//--- Статистика для простого самообучения
ulong  gTotalSignals = 0;         // всего сигналов
ulong  gSuccessfulSignals = 0;    // успешных сигналов

//--- Настройки самооценки сигналов
int    gValidationBars = 8;       // окно проверок, за сколько баров ищем spike после сигнала
double gSpikeSizeATR  = 3.0;      // какой размер (в ATR) считаем "импульсом"

//--- Структура для трекинга активных прогнозов
struct Prediction
{
  datetime time;   // время бара прогноза
  int      dir;    // +1 Boom/buy, -1 Crash/sell
  bool     validated; // обработан ли прогноз (успех/провал)
};

Prediction gPredictions[]; // динамический массив прогнозов (скользящее окно)

//--- Вспомогательные функции -------------------------------------------------

// Определить тип символа по имени
void DetectSymbolType()
{
  string s = StringToLower(_Symbol);
  gIsBoomSymbol  = (StringFind(s, "boom")  != -1);
  gIsCrashSymbol = (StringFind(s, "crash") != -1);
}

// Получить смещение бара для выбранного таймфрейма
int TfShiftByTime(datetime t)
{
  return iBarShift(_Symbol, (InpTimeframe==PERIOD_CURRENT ? _Period : InpTimeframe), t, false);
}

// Безопасное чтение одного значения из индикатора по индексу бара ТФ
bool GetValue(int handle, int buffer_num, int tf_index, double &out)
{
  out = 0.0;
  if(handle == INVALID_HANDLE || tf_index < 0)
    return false;
  double tmp[1];
  if(CopyBuffer(handle, buffer_num, tf_index, 1, tmp) != 1)
    return false;
  out = tmp[0];
  return (out==out); // not NaN
}

// Получить два значения (текущий и предыдущий) для оценки динамики
bool GetTwoValues(int handle, int buffer_num, int tf_index, double &v0, double &v1)
{
  v0 = v1 = 0.0;
  if(handle == INVALID_HANDLE || tf_index < 1)
    return false;
  double tmp[2];
  if(CopyBuffer(handle, buffer_num, tf_index-1, 2, tmp) != 2)
    return false;
  // tmp[0] -> предыдущий бар, tmp[1] -> текущий бар (tf_index)
  v1 = tmp[1];
  v0 = tmp[0];
  return (v0==v0 && v1==v1);
}

// Поиск последних двух фракталов (верхних или нижних) на выбранном ТФ
bool FindLastTwoFractals(bool upper, int &bar1, double &price1, int &bar2, double &price2)
{
  bar1 = bar2 = -1;
  price1 = price2 = 0.0;
  if(hFractals == INVALID_HANDLE)
    return false;

  // Считаем разумный диапазон
  int tfBars = (int)SeriesInfoInteger(_Symbol, (InpTimeframe==PERIOD_CURRENT ? _Period : InpTimeframe), SERIES_BARS_COUNT);
  if(tfBars <= 0) tfBars = 3000;
  // Используем глубину анализа из входного параметра, чтобы избежать предупреждения об неиспользуемой переменной
  int cnt = MathMin(4000, MathMax(100, InpSpikeDetectionDepth * 100));
  cnt = MathMin(cnt, tfBars);

  double buff[];
  int bufferIndex = (upper ? 0 : 1);
  if(CopyBuffer(hFractals, bufferIndex, 0, cnt, buff) <= 0)
    return false;

  ArraySetAsSeries(buff, true);

  for(int i=0; i<cnt; ++i)
  {
    if(buff[i] == 0.0 || buff[i] != buff[i])
      continue;
    if(bar1 == -1)
    {
      bar1 = i;
      price1 = buff[i];
    }
    else if(bar2 == -1)
    {
      bar2 = i;
      price2 = buff[i];
      break;
    }
  }
  return (bar1!=-1 && bar2!=-1);
}

// Оценка дивергенции по RSI и MACD между двумя экстремумами цены
// dir: +1 ожидаем Boom (бычья дивергенция), -1 ожидаем Crash (медвежья)
bool DetectDivergence(int dir, int tf_barA, double priceA, int tf_barB, double priceB, double &score)
{
  score = 0.0;
  if(hRSI==INVALID_HANDLE || hMACD==INVALID_HANDLE)
    return false;

  // Читаем RSI на двух барах
  double rsiA, rsiB;
  if(!GetValue(hRSI, 0, tf_barA, rsiA)) return false;
  if(!GetValue(hRSI, 0, tf_barB, rsiB)) return false;

  // Читаем MACD main на двух барах
  double macdMainA, macdMainB;
  if(!GetValue(hMACD, 0, tf_barA, macdMainA)) return false;
  if(!GetValue(hMACD, 0, tf_barB, macdMainB)) return false;

  bool priceLL = (priceB < priceA);
  bool priceHH = (priceB > priceA);
  bool rsiHL = (rsiB > rsiA);
  bool rsiLH = (rsiB < rsiA);
  bool macdHL = (macdMainB > macdMainA);
  bool macdLH = (macdMainB < macdMainA);

  if(dir > 0)
  {
    // Бычья дивергенция: цена делает более низкий минимум, осцилляторы — более высокий минимум
    if(priceLL && rsiHL) score += 0.6;
    if(priceLL && macdHL) score += 0.6;
  }
  else
  {
    // Медвежья дивергенция: цена делает более высокий максимум, осцилляторы — более низкий максимум
    if(priceHH && rsiLH) score += 0.6;
    if(priceHH && macdLH) score += 0.6;
  }

  score = MathMin(score, 1.2); // ограничим вклад
  return (score > 0.0);
}

// Расчет вероятности импульса и прогноз направления для конкретного бара графика
// Возвращает вероятность (0..1), dir (+1 Boom/buy, -1 Crash/sell) и рекомендуемое leadBars (1..5)
bool ComputeSpikeForecastForBar(int chart_bar_index, double &probability, int &dir, int &leadBars)
{
  probability = 0.0;
  dir = 0;
  leadBars = InpLeadBarsMin;

  datetime t = iTime(_Symbol, _Period, chart_bar_index);
  int tfIndex = TfShiftByTime(t);
  if(tfIndex < 2) return false; // недостаточно баров на ТФ анализа

  //--- Определяем целевое направление по типу символа (Boom => вверх, Crash => вниз)
  dir = (gIsBoomSymbol ? +1 : (gIsCrashSymbol ? -1 : 0));
  if(dir == 0)
  {
    // Если символ не Boom/Crash, попробуем определить по преобладающему тренду
    double ema1, ema2, ema3;
    if(!GetValue(hEMA1, 0, tfIndex, ema1) || !GetValue(hEMA2, 0, tfIndex, ema2) || !GetValue(hEMA3, 0, tfIndex, ema3))
      return false;
    dir = (ema1>ema2 && ema2>ema3) ? +1 : -1;
  }

  //--- Получаем основные индикаторы на текущем и предыдущем баре ТФ анализа
  double ema1, ema2, ema3;
  if(!GetValue(hEMA1, 0, tfIndex, ema1) || !GetValue(hEMA2, 0, tfIndex, ema2) || !GetValue(hEMA3, 0, tfIndex, ema3)) return false;

  double rsi0, rsi1;
  if(!GetTwoValues(hRSI, 0, tfIndex, rsi1, rsi0)) return false; // rsi1=prev, rsi0=current

  double macdMain0, macdMain1, macdSignal0, macdSignal1;
  if(!GetTwoValues(hMACD, 0, tfIndex, macdMain1, macdMain0)) return false;
  if(!GetTwoValues(hMACD, 1, tfIndex, macdSignal1, macdSignal0)) return false;
  double macdHist0 = macdMain0 - macdSignal0;
  double macdHist1 = macdMain1 - macdSignal1;

  double atr0;
  if(!GetValue(hATR, 0, tfIndex, atr0)) return false;

  double bbUpper0, bbLower0;
  if(!GetValue(hBands, 0, tfIndex, bbUpper0)) return false; // верхняя
  if(!GetValue(hBands, 2, tfIndex, bbLower0)) return false; // нижняя
  double bbWidthRel = 0.0;
  double c = iClose(_Symbol, (InpTimeframe==PERIOD_CURRENT ? _Period : InpTimeframe), tfIndex);
  if(c>0.0) bbWidthRel = (bbUpper0 - bbLower0) / c; // ширина Боллинджера относительно цены

  //--- Оценка тренда EMA
  double trendScore = 0.0;
  if(dir > 0)
  {
    if(ema1 > ema2 && ema2 > ema3) trendScore = 0.8; // сильный бычий тренд
    else if(ema1 > ema2) trendScore = 0.4;
  }
  else
  {
    if(ema1 < ema2 && ema2 < ema3) trendScore = 0.8; // сильный медвежий тренд
    else if(ema1 < ema2) trendScore = 0.4;
  }

  //--- RSI экстремумы
  double rsiScore = 0.0;
  if(dir > 0)
  {
    // Boom: ищем перепроданность
    if(rsi0 <= 30) rsiScore = 0.8;
    else if(rsi0 <= 35) rsiScore = 0.5;
  }
  else
  {
    // Crash: ищем перекупленность
    if(rsi0 >= 70) rsiScore = 0.8;
    else if(rsi0 >= 65) rsiScore = 0.5;
  }

  //--- MACD: растущая/падающая гистограмма
  double macdScore = 0.0;
  if(dir > 0)
  {
    if(macdHist0 > macdHist1) macdScore += 0.4; // ускорение вверх
    if(macdMain0 > macdSignal0) macdScore += 0.4; // бычье пересечение
  }
  else
  {
    if(macdHist0 < macdHist1) macdScore += 0.4; // ускорение вниз
    if(macdMain0 < macdSignal0) macdScore += 0.4; // медвежье пересечение
  }

  //--- Боллинджер: сужение (squeeze) даёт предпосылки импульса
  double bbScore = 0.0;
  if(bbWidthRel < 0.01) bbScore = 0.5; // узкие полосы
  else if(bbWidthRel < 0.015) bbScore = 0.3;

  //--- Близость к фракталу (поддержка/сопротивление)
  double fractScore = 0.0;
  int f1, f2; double p1, p2;
  if(dir > 0)
  {
    // ищем два последних нижних фрактала
    if(FindLastTwoFractals(false, f1, p1, f2, p2))
    {
      double dist = MathAbs(c - p1);
      if(atr0 > 0.0 && (dist/atr0) < 0.5) fractScore = 0.5;
    }
  }
  else
  {
    // ищем два последних верхних фрактала
    if(FindLastTwoFractals(true, f1, p1, f2, p2))
    {
      double dist = MathAbs(c - p1);
      if(atr0 > 0.0 && (dist/atr0) < 0.5) fractScore = 0.5;
    }
  }

  //--- Дивергенция по RSI/MACD относительно 2-х крайних фракталов
  double divScore = 0.0;
  if(f1!=-1 && f2!=-1)
  {
    // Преобразуем индексы фракталов (на ТФ анализа) в цены (у нас уже цены p1/p2)
    DetectDivergence(dir, f2, p2, f1, p1, divScore);
  }

  //--- Сжатие свечей (серия маленьких баров относительно ATR)
  double compressScore = 0.0;
  int smallCount = 0;
  int N = 5;
  for(int k=0; k<N; ++k)
  {
    int idx = tfIndex + k;
    double hi = iHigh(_Symbol, (InpTimeframe==PERIOD_CURRENT ? _Period : InpTimeframe), idx);
    double lo = iLow(_Symbol,  (InpTimeframe==PERIOD_CURRENT ? _Period : InpTimeframe), idx);
    if(hi==0.0 || lo==0.0) break;
    double range = (hi - lo);
    if(atr0>0.0 && range < 0.6*atr0) smallCount++;
  }
  if(smallCount >= 3) compressScore = 0.4;

  //--- Итоговая вероятность (веса можно подстраивать)
  double rawScore = 0.0;
  rawScore += trendScore * 0.25;
  rawScore += rsiScore   * 0.25;
  rawScore += macdScore  * 0.20;
  rawScore += divScore   * 0.15;
  rawScore += fractScore * 0.10;
  rawScore += bbScore    * 0.03;
  rawScore += compressScore * 0.02;

  // нормируем в 0..1 и чуть сгладим сигмоидой
  double x = MathMin(1.0, MathMax(0.0, rawScore));
  double prob = 1.0/(1.0 + MathExp(-6.0*(x - 0.5))); // сигмоида вокруг 0.5

  probability = prob;

  // рекомендованный lead (больше при низкой волатильности)
  leadBars = MathMax(InpLeadBarsMin, MathMin(InpLeadBarsMax, (int)MathRound( (bbWidthRel<0.01 ? 3 : 2) )));

  return true;
}

// Добавить запись о прогнозе для последующей валидации
void TrackPrediction(datetime t, int dir)
{
  Prediction p; p.time = t; p.dir = dir; p.validated = false;
  int n = ArraySize(gPredictions);
  ArrayResize(gPredictions, n+1);
  gPredictions[n] = p;
}

// Проверить, произошел ли импульс в нужном направлении после прогноза
void ValidatePredictionsOnHistory()
{
  if(ArraySize(gPredictions) == 0)
    return;

  int tf = (InpTimeframe==PERIOD_CURRENT ? _Period : InpTimeframe);

  for(int i=0; i<ArraySize(gPredictions); ++i)
  {
    if(gPredictions[i].validated)
      continue;

    // Найдем индекс бара прогноза в ТФ анализа
    int startIndex = iBarShift(_Symbol, tf, gPredictions[i].time, false);
    if(startIndex < 0)
      continue;

    // Смотрим окно после прогноза
    int count = gValidationBars;
    if(count <= 0) count = 6;

    // Получаем High/Low будущих баров
    double highs[], lows[];
    int copiedH = CopyHigh(_Symbol, tf, startIndex - (count-1), count, highs);
    int copiedL = CopyLow(_Symbol, tf, startIndex - (count-1), count, lows);
    if(copiedH <= 0 || copiedL <= 0)
      continue;

    ArraySetAsSeries(highs, true);
    ArraySetAsSeries(lows,  true);

    // Текущий ATR для масштаба
    double atr = 0.0;
    GetValue(hATR, 0, startIndex, atr);
    if(atr <= 0.0) atr = (_Point * 100);

    bool success = false;
    if(gPredictions[i].dir > 0)
    {
      // Boom: ищем рост >= gSpikeSizeATR*ATR
      double startPrice = iClose(_Symbol, tf, startIndex);
      for(int k=1; k<count; ++k)
      {
        double move = highs[k] - startPrice;
        if(move >= gSpikeSizeATR * atr) { success = true; break; }
      }
    }
    else if(gPredictions[i].dir < 0)
    {
      // Crash: ищем падение >= gSpikeSizeATR*ATR
      double startPrice = iClose(_Symbol, tf, startIndex);
      for(int k=1; k<count; ++k)
      {
        double move = startPrice - lows[k];
        if(move >= gSpikeSizeATR * atr) { success = true; break; }
      }
    }

    if(success)
    {
      gSuccessfulSignals++;
      gPredictions[i].validated = true;
    }
    else
    {
      // Если прошли все бары окна — считаем прогноз неуспешным
      // Проверяем по времени последнего доступного бара
      datetime nowTf = iTime(_Symbol, tf, 0);
      datetime endWindow = iTime(_Symbol, tf, startIndex - (count-1));
      if(nowTf <= endWindow)
        continue; // еще не завершили окно
      gPredictions[i].validated = true; // помечаем как обработанный (неудача)
    }
  }

  // Адаптация чувствительности по частоте успехов
  double successRate = 0.0;
  if(gTotalSignals > 20)
    successRate = (double)gSuccessfulSignals / (double)gTotalSignals;
  else
    successRate = 0.5; // недостаточно данных — нейтрально

  // Чем выше успех — тем ниже порог (чтобы давать больше сигналов)
  // Чем ниже успех — тем выше порог (более консервативно)
  gAdaptiveThreshold = MathMin(0.95, MathMax(0.05, InpSpikePredictionSensitivity + (0.5 - successRate) * 0.2));
}

// Рисование/обновление панели статуса
void DrawOrUpdatePanel(double probability, int dir, double rsi, double atr, double macdHist)
{
  string bg = CB_OBJ_BG;
  string lb = CB_OBJ_LABEL;

  if(ObjectFind(0, bg) == -1)
  {
    ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, bg, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, 25);
    ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, (color)clrBlack);
    ObjectSetInteger(0, bg, OBJPROP_BACK, true);
    ObjectSetInteger(0, bg, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, bg, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, bg, OBJPROP_ZORDER, 0);
    ObjectSetInteger(0, bg, OBJPROP_COLOR, (color)clrBlack);
    ObjectSetInteger(0, bg, OBJPROP_WIDTH, 230);
    ObjectSetInteger(0, bg, OBJPROP_HEIGHT, 80);
  }

  if(ObjectFind(0, lb) == -1)
  {
    ObjectCreate(0, lb, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, lb, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(0, lb, OBJPROP_XDISTANCE, 18);
    ObjectSetInteger(0, lb, OBJPROP_YDISTANCE, 30);
    ObjectSetInteger(0, lb, OBJPROP_FONTSIZE, 9);
    ObjectSetString(0, lb, OBJPROP_FONT, "Tahoma");
    ObjectSetInteger(0, lb, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, lb, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, lb, OBJPROP_COLOR, (color)clrWhite);
  }

  string trendStr = (dir>0 ? "Trend: Up (Boom)" : "Trend: Down (Crash)");
  string msg;
  msg += trendStr + "\n";
  msg += StringFormat("Probability: %d%%\n", (int)MathRound(probability*100.0));
  msg += StringFormat("RSI: %.1f  ATR: %.1f  MACD: %.4f", rsi, atr, macdHist);
  ObjectSetString(0, lb, OBJPROP_TEXT, msg);
}

// Рисование Фибо-уровней на последних свингах
void DrawFibonacci()
{
  if(!InpShowFibonacciLevels)
    return;

  // Удалим старые Фибо
  for(int i=0; i<1000; ++i)
  {
    string name = CB_OBJ_FIBO + IntegerToString(i);
    if(ObjectFind(0, name) != -1)
      ObjectDelete(0, name);
  }

  int fup1, fup2; double pup1, pup2;
  int fdn1, fdn2; double pdn1, pdn2;
  bool okUp = FindLastTwoFractals(true,  fup1, pup1, fup2, pup2);
  bool okDn = FindLastTwoFractals(false, fdn1, pdn1, fdn2, pdn2);

  if(!okUp || !okDn) return;

  // Возьмем последнюю пару high/low
  datetime t1 = iTime(_Symbol, (InpTimeframe==PERIOD_CURRENT ? _Period : InpTimeframe), MathMin(fup1, fdn1));
  datetime t2 = iTime(_Symbol, (InpTimeframe==PERIOD_CURRENT ? _Period : InpTimeframe), MathMax(fup1, fdn1));

  double swingHigh = pup1;
  double swingLow  = pdn1;

  string name = CB_OBJ_FIBO + "0";
  if(ObjectCreate(0, name, OBJ_FIBO, 0, t1, swingHigh, t2, swingLow))
  {
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, name, OBJPROP_COLOR, (color)clrDarkSlateGray);
  }
}

// Отрисовать стрелку и текстовую метку
void PlotSignalArrow(datetime bar_time, int bar_index, int dir, int leadBars, const string &text)
{
  // Вычислим цену для размещения стрелки с отступом
  double price = (dir>0 ? iHigh(_Symbol, _Period, bar_index) : iLow(_Symbol, _Period, bar_index));
  double offset = InpArrowDistancePoints * _Point;
  double y = (dir>0 ? price + offset : price - offset);

  if(dir > 0)
  {
    gBuyArrowBuffer[bar_index] = y;
    gSellArrowBuffer[bar_index] = EMPTY_VALUE;
  }
  else
  {
    gSellArrowBuffer[bar_index] = y;
    gBuyArrowBuffer[bar_index] = EMPTY_VALUE;
  }

  // Подпись на графике
  string name = (dir>0 ? CB_OBJ_ARROW_BUY : CB_OBJ_ARROW_SELL) + IntegerToString((long)bar_time);
  if(ObjectFind(0, name) == -1)
  {
    ObjectCreate(0, name, OBJ_ARROW, 0, bar_time, y);
    ObjectSetInteger(0, name, OBJPROP_ARROWCODE, (dir>0 ? 233 : 234));
    ObjectSetInteger(0, name, OBJPROP_COLOR, (color)(dir>0 ? clrDodgerBlue : clrTomato));
    ObjectSetInteger(0, name, OBJPROP_WIDTH, InpArrowSize);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

    string label = name + "_txt";
    ObjectCreate(0, label, OBJ_TEXT, 0, bar_time, y);
    ObjectSetInteger(0, label, OBJPROP_COLOR, (color)(dir>0 ? clrDodgerBlue : clrTomato));
    ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 9);
    ObjectSetString(0, label, OBJPROP_TEXT, text);
    ObjectSetInteger(0, label, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, label, OBJPROP_HIDDEN, true);
  }
}

// Отправить оповещения
void NotifySignal(int dir, double probability)
{
  if(!InpEnableAlerts)
    return;

  string dirStr = (dir>0 ? "Boom spike soon" : "Crash spike soon");
  string msg = StringFormat("%s on %s %s, probability=%d%%", dirStr, _Symbol, EnumToString(_Period), (int)MathRound(probability*100.0));

  Alert(msg);
  Print(msg);

  // Опционально: push/email — сработают, если настроены в терминале
  SendNotification(msg);
  SendMail("CrashBoom_ImpulseDetector", msg);
}

// Загрузка/сохранение статистики в Global Variables терминала
void LoadStats()
{
  string keyT = CB_STATS_PREFIX + _Symbol + "_" + IntegerToString(_Period) + "_T";
  string keyS = CB_STATS_PREFIX + _Symbol + "_" + IntegerToString(_Period) + "_S";
  if(GlobalVariableCheck(keyT)) gTotalSignals = (ulong)GlobalVariableGet(keyT);
  if(GlobalVariableCheck(keyS)) gSuccessfulSignals = (ulong)GlobalVariableGet(keyS);
}

void SaveStats()
{
  string keyT = CB_STATS_PREFIX + _Symbol + "_" + IntegerToString(_Period) + "_T";
  string keyS = CB_STATS_PREFIX + _Symbol + "_" + IntegerToString(_Period) + "_S";
  GlobalVariableSet(keyT, (double)gTotalSignals);
  GlobalVariableSet(keyS, (double)gSuccessfulSignals);
}

// Очистка старых объектов с префиксом CB_PREFIX (ограниченно, чтобы не засорять график)
void CleanupOldObjects(int maxObjects)
{
  int total = ObjectsTotal(0, -1, -1);
  int count=0;
  for(int i=total-1; i>=0; --i)
  {
    string name = ObjectName(0, i);
    if(StringFind(name, CB_PREFIX) == 0)
    {
      count++;
      if(count > maxObjects)
        ObjectDelete(0, name);
    }
  }
}

//+------------------------------------------------------------------+
//| Инициализация                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
  DetectSymbolType();
  LoadStats();

  //--- Хэндлы индикаторов
  int tf = (InpTimeframe==PERIOD_CURRENT ? _Period : InpTimeframe);
  hEMA1 = iMA(_Symbol, tf, InpMAPeriod1, 0, MODE_EMA, PRICE_CLOSE);
  hEMA2 = iMA(_Symbol, tf, InpMAPeriod2, 0, MODE_EMA, PRICE_CLOSE);
  hEMA3 = iMA(_Symbol, tf, InpMAPeriod3, 0, MODE_EMA, PRICE_CLOSE);
  hRSI  = iRSI(_Symbol, tf, InpRSIPeriod, PRICE_CLOSE);
  hMACD = iMACD(_Symbol, tf, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
  hATR  = iATR(_Symbol, tf, InpATRPeriod);
  hFractals = iFractals(_Symbol, tf);
  hBands = iBands(_Symbol, tf, 20, 2.0, 0, PRICE_CLOSE);

  if(hEMA1==INVALID_HANDLE || hEMA2==INVALID_HANDLE || hEMA3==INVALID_HANDLE ||
     hRSI==INVALID_HANDLE  || hMACD==INVALID_HANDLE || hATR==INVALID_HANDLE  ||
     hFractals==INVALID_HANDLE || hBands==INVALID_HANDLE)
  {
    Print("[CrashBoom_ImpulseDetector] Ошибка создания хэндлов индикаторов");
    return(INIT_FAILED);
  }

  //--- Буферы
  SetIndexBuffer(0, gBuyArrowBuffer, INDICATOR_DATA);
  SetIndexBuffer(1, gSellArrowBuffer, INDICATOR_DATA);
  SetIndexBuffer(2, gProbabilityBuffer, INDICATOR_CALCULATIONS);

  ArraySetAsSeries(gBuyArrowBuffer, true);
  ArraySetAsSeries(gSellArrowBuffer, true);
  ArraySetAsSeries(gProbabilityBuffer, true);

  PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_ARROW);
  PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_ARROW);
  PlotIndexSetInteger(0, PLOT_ARROW, 233); // вверх
  PlotIndexSetInteger(1, PLOT_ARROW, 234); // вниз
  PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpArrowSize);
  PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpArrowSize);

  IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
  IndicatorSetString(INDICATOR_SHORTNAME, "CrashBoom ImpulseDetector");

  gAdaptiveThreshold = InpSpikePredictionSensitivity;

  return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Деинициализация                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  SaveStats();
  // Не удаляем стрелки/панель насильно — возможно, нужно для истории
}

//+------------------------------------------------------------------+
//| Основной расчет                                                  |
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
  if(rates_total < 300)
    return prev_calculated;

  int start = (prev_calculated==0 ? rates_total-200 : prev_calculated-1);
  if(start < 0) start = 0;

  // Валидация ранее выданных прогнозов (для адаптации)
  ValidatePredictionsOnHistory();

  // Обработаем бары
  for(int i=start; i<rates_total; ++i)
  {
    gBuyArrowBuffer[i] = EMPTY_VALUE;
    gSellArrowBuffer[i] = EMPTY_VALUE;
    gProbabilityBuffer[i] = 0.0;

    double prob; int dir; int lead;
    if(!ComputeSpikeForecastForBar(i, prob, dir, lead))
      continue;

    gProbabilityBuffer[i] = prob;

    // Сигнал генерируем на закрытом баре (i>=1), если вероятность выше адаптивного порога
    if(i >= 1 && prob >= gAdaptiveThreshold)
    {
      // Разместим стрелку на баре i (предупреждение заранее перед потенциальным импульсом)
      PlotSignalArrow(time[i], i, dir, lead, (dir>0 ? "Boom spike soon" : "Crash spike soon"));

      // Оповещение только 1 раз на новый бар
      if(time[i] != gLastAlertBarTime)
      {
        NotifySignal(dir, prob);
        gLastAlertBarTime = time[i];
        gTotalSignals++;
        TrackPrediction(time[i], dir);
      }
    }
  }

  // Обновление панели состояния по последнему бару (0)
  {
    double rsi0=0.0, rsi1=0.0;
    int tfIndex = TfShiftByTime(time[0]);
    if(tfIndex>=1)
    {
      GetTwoValues(hRSI, 0, tfIndex, rsi1, rsi0);
      double atr0=0.0; GetValue(hATR, 0, tfIndex, atr0);
      double m0=0.0,m1=0.0,s0=0.0,s1=0.0; GetTwoValues(hMACD,0,tfIndex,m1,m0); GetTwoValues(hMACD,1,tfIndex,s1,s0);
      double macdHist0 = m0 - s0;

      double prob0 = 0.0; int dir0=0; int lead0=0;
      ComputeSpikeForecastForBar(0, prob0, dir0, lead0);
      DrawOrUpdatePanel(prob0, dir0, rsi0, atr0, macdHist0);
    }
  }

  // Фибо уровни (редко обновляем, чтобы не мусорить)
  if(InpShowFibonacciLevels && (prev_calculated==0 || (TimeCurrent()%60)==0))
    DrawFibonacci();

  // Легкая уборка старых объектов
  CleanupOldObjects(200);

  return(rates_total);
}

//+------------------------------------------------------------------+
//| Дополнительно: горячие клавиши/параметры                         |
//+------------------------------------------------------------------+
// Примечание:
// - Индикатор работает в тестере стратегий MT5 (визуальный режим).
// - Поддерживает тик-данные Deriv синтетических индексов.
// - Параметры можно оптимизировать через MT5 Optimization.
// - Алгоритм использует: EMA (50/100/200) тренд, RSI/MACD с дивергенциями,
//   ATR и ширину Bollinger Bands (волатильность), фрактальные уровни,
//   а также простую адаптацию порога чувствительности по историческим успехам.
// - Для минимизации мусора на графике включена "мягкая" очистка старых объектов.
// - Код модульный, все ключевые этапы вынесены в функции.
// - Комментарии на русском.
//+------------------------------------------------------------------+
