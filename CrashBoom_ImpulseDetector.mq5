//+------------------------------------------------------------------+
//|                                    CrashBoom_ImpulseDetector.mq5 |
//|                        Комплексный индикатор для Deriv Crash/Boom |
//|                                         Детектор импульсов (Spikes) |
//+------------------------------------------------------------------+
#property copyright "CrashBoom Impulse Detector"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2

// Буферы для стрелок
#property indicator_label1  "Buy Signal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrBlue
#property indicator_width1  2

#property indicator_label2  "Sell Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  2

//--- Входные параметры
input group "=== Общие настройки ==="
input ENUM_TIMEFRAMES Timeframe = PERIOD_CURRENT;          // Таймфрейм анализа
input int             SpikeDetectionDepth = 100;            // Глубина анализа свечей
input double          SpikePredictionSensitivity = 0.65;    // Чувствительность прогноза (0-1)
input bool            EnableAlerts = true;                  // Включить оповещения
input bool            EnablePushNotifications = false;       // Push-уведомления
input bool            EnableEmailNotifications = false;      // Email-уведомления

input group "=== Скользящие средние ==="
input int             MovingAveragePeriod1 = 50;            // Период EMA 1
input int             MovingAveragePeriod2 = 100;           // Период EMA 2
input int             MovingAveragePeriod3 = 200;           // Период EMA 3
input ENUM_MA_METHOD  MA_Method = MODE_EMA;                 // Метод MA

input group "=== Осцилляторы ==="
input int             RSI_Period = 14;                      // Период RSI
input int             MACD_Fast = 12;                       // MACD Быстрая линия
input int             MACD_Slow = 26;                       // MACD Медленная линия
input int             MACD_Signal = 9;                      // MACD Сигнальная линия
input int             Stochastic_K = 5;                     // Stochastic %K
input int             Stochastic_D = 3;                     // Stochastic %D
input int             Stochastic_Slowing = 3;               // Stochastic Slowing
input int             CCI_Period = 14;                      // Период CCI
input int             WPR_Period = 14;                      // Период Williams %R
input int             Momentum_Period = 14;                 // Период Momentum

input group "=== Волатильность ==="
input int             ATR_Period = 14;                      // Период ATR
input int             BB_Period = 20;                       // Период Bollinger Bands
input double          BB_Deviation = 2.0;                   // Отклонение Bollinger Bands

input group "=== Bill Williams ==="
input int             Alligator_Jaw = 13;                   // Alligator Jaw период
input int             Alligator_Teeth = 8;                  // Alligator Teeth период
input int             Alligator_Lips = 5;                   // Alligator Lips период
input int             Fractal_Depth = 5;                    // Глубина фракталов

input group "=== Фибоначчи и графические объекты ==="
input bool            ShowFibonacciLevels = true;           // Показывать Фибоначчи уровни
input bool            ShowSupportResistance = true;         // Показывать поддержку/сопротивление
input bool            ShowTrendLines = true;                // Показывать трендовые линии
input int             SR_LookbackPeriod = 50;               // Период анализа S/R

input group "=== Визуализация ==="
input int             ArrowSize = 2;                        // Размер стрелки
input int             ArrowDistance = 10;                   // Смещение стрелки от свечи (пункты)
input bool            ShowInfoPanel = true;                 // Показывать информационную панель
input color           BuyArrowColor = clrBlue;              // Цвет стрелки Buy
input color           SellArrowColor = clrRed;              // Цвет стрелки Sell

input group "=== Дополнительные индикаторы ==="
input int             SAR_Step = 2;                         // Parabolic SAR шаг
input int             SAR_Maximum = 20;                     // Parabolic SAR максимум
input int             Ichimoku_Tenkan = 9;                  // Ichimoku Tenkan-sen
input int             Ichimoku_Kijun = 26;                  // Ichimoku Kijun-sen
input int             Ichimoku_Senkou = 52;                 // Ichimoku Senkou Span B
input int             OBV_AppliedPrice = PRICE_CLOSE;       // OBV Applied Price
input int             MFI_Period = 14;                      // Период Money Flow Index
input int             ZigZag_Depth = 12;                    // ZigZag Depth
input int             ZigZag_Deviation = 5;                 // ZigZag Deviation
input int             ZigZag_Backstep = 3;                  // ZigZag Backstep

input group "=== Самообучение ==="
input bool            EnableSelfLearning = true;            // Включить самообучение
input int             LearningHistoryBars = 1000;           // История для обучения
input double          LearningRate = 0.1;                   // Скорость обучения

//--- Буферы индикатора
double BuySignalBuffer[];
double SellSignalBuffer[];
double TrendBuffer[];
double ProbabilityBuffer[];

//--- Глобальные переменные
int handleMA1, handleMA2, handleMA3;
int handleRSI, handleMACD, handleATR, handleBB;
int handleStoch, handleCCI, handleWPR, handleMomentum;
int handleAlligator, handleFractals, handleSAR;
int handleIchimoku, handleOBV, handleMFI, handleZigZag;
int handleAO, handleAC;

datetime lastAlertTime = 0;
string symbolName;
bool isCrashSymbol = false;
bool isBoomSymbol = false;

// Структура для хранения истории сигналов (самообучение)
struct SignalHistory {
    datetime time;
    double predictedPrice;
    double actualPrice;
    bool wasSpike;
    double accuracy;
};
SignalHistory signalHistory[];
int historySize = 0;

// Структура для уровней поддержки/сопротивления
struct SRLevel {
    double price;
    int touches;
    datetime lastTouch;
    bool isSupport;
};
SRLevel srLevels[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    // Определение типа символа
    symbolName = Symbol();
    isCrashSymbol = (StringFind(symbolName, "Crash") >= 0 || StringFind(symbolName, "CRASH") >= 0);
    isBoomSymbol = (StringFind(symbolName, "Boom") >= 0 || StringFind(symbolName, "BOOM") >= 0);
    
    if(!isCrashSymbol && !isBoomSymbol)
    {
        Alert("ВНИМАНИЕ: Индикатор предназначен для символов Crash/Boom!");
        Print("Текущий символ: ", symbolName);
    }
    
    // Установка буферов
    SetIndexBuffer(0, BuySignalBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, SellSignalBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, TrendBuffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(3, ProbabilityBuffer, INDICATOR_CALCULATIONS);
    
    // Настройка стрелок
    PlotIndexSetInteger(0, PLOT_ARROW, 233);  // Стрелка вверх
    PlotIndexSetInteger(1, PLOT_ARROW, 234);  // Стрелка вниз
    PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, -ArrowDistance);
    PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, ArrowDistance);
    
    // Инициализация индикаторов
    handleMA1 = iMA(symbolName, Timeframe, MovingAveragePeriod1, 0, MA_Method, PRICE_CLOSE);
    handleMA2 = iMA(symbolName, Timeframe, MovingAveragePeriod2, 0, MA_Method, PRICE_CLOSE);
    handleMA3 = iMA(symbolName, Timeframe, MovingAveragePeriod3, 0, MA_Method, PRICE_CLOSE);
    handleRSI = iRSI(symbolName, Timeframe, RSI_Period, PRICE_CLOSE);
    handleMACD = iMACD(symbolName, Timeframe, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
    handleATR = iATR(symbolName, Timeframe, ATR_Period);
    handleBB = iBands(symbolName, Timeframe, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
    handleStoch = iStochastic(symbolName, Timeframe, Stochastic_K, Stochastic_D, Stochastic_Slowing, MODE_SMA, STO_LOWHIGH);
    handleCCI = iCCI(symbolName, Timeframe, CCI_Period, PRICE_TYPICAL);
    handleWPR = iWPR(symbolName, Timeframe, WPR_Period);
    handleMomentum = iMomentum(symbolName, Timeframe, Momentum_Period, PRICE_CLOSE);
    handleAlligator = iAlligator(symbolName, Timeframe, Alligator_Jaw, 8, Alligator_Teeth, 5, Alligator_Lips, 3, MODE_SMMA, PRICE_MEDIAN);
    handleSAR = iSAR(symbolName, Timeframe, SAR_Step * 0.01, SAR_Maximum * 0.01);
    handleIchimoku = iIchimoku(symbolName, Timeframe, Ichimoku_Tenkan, Ichimoku_Kijun, Ichimoku_Senkou);
    handleOBV = iOBV(symbolName, Timeframe, VOLUME_TICK);
    handleMFI = iMFI(symbolName, Timeframe, MFI_Period, VOLUME_TICK);
    handleAO = iAO(symbolName, Timeframe);
    handleAC = iAC(symbolName, Timeframe);
    
    // Проверка создания индикаторов
    if(handleMA1 == INVALID_HANDLE || handleMA2 == INVALID_HANDLE || handleMA3 == INVALID_HANDLE ||
       handleRSI == INVALID_HANDLE || handleMACD == INVALID_HANDLE || handleATR == INVALID_HANDLE)
    {
        Print("Ошибка создания индикаторов!");
        return(INIT_FAILED);
    }
    
    // Инициализация массивов
    ArraySetAsSeries(BuySignalBuffer, true);
    ArraySetAsSeries(SellSignalBuffer, true);
    ArraySetAsSeries(TrendBuffer, true);
    ArraySetAsSeries(ProbabilityBuffer, true);
    
    if(EnableSelfLearning)
    {
        ArrayResize(signalHistory, LearningHistoryBars);
        ArrayInitialize(signalHistory, 0);
    }
    
    // Создание информационной панели
    if(ShowInfoPanel)
    {
        CreateInfoPanel();
    }
    
    Print("Индикатор CrashBoom_ImpulseDetector успешно инициализирован для ", symbolName);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Освобождение индикаторов
    if(handleMA1 != INVALID_HANDLE) IndicatorRelease(handleMA1);
    if(handleMA2 != INVALID_HANDLE) IndicatorRelease(handleMA2);
    if(handleMA3 != INVALID_HANDLE) IndicatorRelease(handleMA3);
    if(handleRSI != INVALID_HANDLE) IndicatorRelease(handleRSI);
    if(handleMACD != INVALID_HANDLE) IndicatorRelease(handleMACD);
    if(handleATR != INVALID_HANDLE) IndicatorRelease(handleATR);
    if(handleBB != INVALID_HANDLE) IndicatorRelease(handleBB);
    if(handleStoch != INVALID_HANDLE) IndicatorRelease(handleStoch);
    if(handleCCI != INVALID_HANDLE) IndicatorRelease(handleCCI);
    if(handleWPR != INVALID_HANDLE) IndicatorRelease(handleWPR);
    if(handleMomentum != INVALID_HANDLE) IndicatorRelease(handleMomentum);
    if(handleAlligator != INVALID_HANDLE) IndicatorRelease(handleAlligator);
    if(handleSAR != INVALID_HANDLE) IndicatorRelease(handleSAR);
    if(handleIchimoku != INVALID_HANDLE) IndicatorRelease(handleIchimoku);
    if(handleOBV != INVALID_HANDLE) IndicatorRelease(handleOBV);
    if(handleMFI != INVALID_HANDLE) IndicatorRelease(handleMFI);
    if(handleAO != INVALID_HANDLE) IndicatorRelease(handleAO);
    if(handleAC != INVALID_HANDLE) IndicatorRelease(handleAC);
    
    // Удаление графических объектов
    DeleteAllObjects();
    
    Print("Индикатор CrashBoom_ImpulseDetector деинициализирован");
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
    if(rates_total < SpikeDetectionDepth + MovingAveragePeriod3)
        return(0);
    
    ArraySetAsSeries(time, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(tick_volume, true);
    
    int limit = rates_total - prev_calculated;
    if(limit > SpikeDetectionDepth)
        limit = SpikeDetectionDepth;
    
    if(prev_calculated == 0)
    {
        ArrayInitialize(BuySignalBuffer, EMPTY_VALUE);
        ArrayInitialize(SellSignalBuffer, EMPTY_VALUE);
        limit = MathMin(SpikeDetectionDepth, rates_total - MovingAveragePeriod3);
    }
    
    // Основной цикл расчета
    for(int i = limit; i >= 0; i--)
    {
        // Получение данных индикаторов
        double ma1[], ma2[], ma3[], rsi[], macd_main[], macd_signal[], atr[], bb_upper[], bb_lower[];
        double stoch_main[], stoch_signal[], cci[], wpr[], momentum[];
        double alligator_jaw[], alligator_teeth[], alligator_lips[], sar[];
        double ichimoku_tenkan[], ichimoku_kijun[], obv[], mfi[], ao[], ac[];
        
        ArraySetAsSeries(ma1, true);
        ArraySetAsSeries(ma2, true);
        ArraySetAsSeries(ma3, true);
        ArraySetAsSeries(rsi, true);
        ArraySetAsSeries(macd_main, true);
        ArraySetAsSeries(macd_signal, true);
        ArraySetAsSeries(atr, true);
        ArraySetAsSeries(bb_upper, true);
        ArraySetAsSeries(bb_lower, true);
        ArraySetAsSeries(stoch_main, true);
        ArraySetAsSeries(stoch_signal, true);
        ArraySetAsSeries(cci, true);
        ArraySetAsSeries(wpr, true);
        ArraySetAsSeries(momentum, true);
        ArraySetAsSeries(alligator_jaw, true);
        ArraySetAsSeries(alligator_teeth, true);
        ArraySetAsSeries(alligator_lips, true);
        ArraySetAsSeries(sar, true);
        ArraySetAsSeries(ichimoku_tenkan, true);
        ArraySetAsSeries(ichimoku_kijun, true);
        ArraySetAsSeries(obv, true);
        ArraySetAsSeries(mfi, true);
        ArraySetAsSeries(ao, true);
        ArraySetAsSeries(ac, true);
        
        // Копирование данных индикаторов
        if(CopyBuffer(handleMA1, 0, i, 10, ma1) <= 0) continue;
        if(CopyBuffer(handleMA2, 0, i, 10, ma2) <= 0) continue;
        if(CopyBuffer(handleMA3, 0, i, 10, ma3) <= 0) continue;
        if(CopyBuffer(handleRSI, 0, i, 10, rsi) <= 0) continue;
        if(CopyBuffer(handleMACD, 0, i, 10, macd_main) <= 0) continue;
        if(CopyBuffer(handleMACD, 1, i, 10, macd_signal) <= 0) continue;
        if(CopyBuffer(handleATR, 0, i, 10, atr) <= 0) continue;
        if(CopyBuffer(handleBB, 1, i, 10, bb_upper) <= 0) continue;
        if(CopyBuffer(handleBB, 2, i, 10, bb_lower) <= 0) continue;
        if(CopyBuffer(handleStoch, 0, i, 10, stoch_main) <= 0) continue;
        if(CopyBuffer(handleStoch, 1, i, 10, stoch_signal) <= 0) continue;
        if(CopyBuffer(handleCCI, 0, i, 10, cci) <= 0) continue;
        if(CopyBuffer(handleWPR, 0, i, 10, wpr) <= 0) continue;
        if(CopyBuffer(handleMomentum, 0, i, 10, momentum) <= 0) continue;
        if(CopyBuffer(handleAlligator, 0, i, 10, alligator_jaw) <= 0) continue;
        if(CopyBuffer(handleAlligator, 1, i, 10, alligator_teeth) <= 0) continue;
        if(CopyBuffer(handleAlligator, 2, i, 10, alligator_lips) <= 0) continue;
        if(CopyBuffer(handleSAR, 0, i, 10, sar) <= 0) continue;
        if(CopyBuffer(handleIchimoku, 0, i, 10, ichimoku_tenkan) <= 0) continue;
        if(CopyBuffer(handleIchimoku, 1, i, 10, ichimoku_kijun) <= 0) continue;
        if(CopyBuffer(handleOBV, 0, i, 10, obv) <= 0) continue;
        if(CopyBuffer(handleMFI, 0, i, 10, mfi) <= 0) continue;
        if(CopyBuffer(handleAO, 0, i, 10, ao) <= 0) continue;
        if(CopyBuffer(handleAC, 0, i, 10, ac) <= 0) continue;
        
        // Комплексный анализ для определения вероятности импульса
        double probability = CalculateSpikeProbability(
            i, close, high, low, open, tick_volume,
            ma1, ma2, ma3, rsi, macd_main, macd_signal, atr,
            bb_upper, bb_lower, stoch_main, stoch_signal,
            cci, wpr, momentum, alligator_jaw, alligator_teeth, alligator_lips,
            sar, ichimoku_tenkan, ichimoku_kijun, obv, mfi, ao, ac
        );
        
        // Определение тренда
        int trend = DetermineTrend(ma1[0], ma2[0], ma3[0], close[i]);
        TrendBuffer[i] = trend;
        ProbabilityBuffer[i] = probability;
        
        // Сброс сигналов
        BuySignalBuffer[i] = EMPTY_VALUE;
        SellSignalBuffer[i] = EMPTY_VALUE;
        
        // Генерация сигналов на основе вероятности
        if(i <= 5) // Анализируем только последние свечи для сигналов
        {
            if(probability >= SpikePredictionSensitivity)
            {
                if(isBoomSymbol && trend >= 0) // Boom - ожидаем рост
                {
                    BuySignalBuffer[i] = low[i] - ArrowDistance * _Point;
                    
                    if(i == 0 && time[0] != lastAlertTime)
                    {
                        SendAlert("BOOM SPIKE", "Вероятный импульс вверх!", probability);
                        lastAlertTime = time[0];
                    }
                }
                else if(isCrashSymbol && trend <= 0) // Crash - ожидаем падение
                {
                    SellSignalBuffer[i] = high[i] + ArrowDistance * _Point;
                    
                    if(i == 0 && time[0] != lastAlertTime)
                    {
                        SendAlert("CRASH SPIKE", "Вероятное падение!", probability);
                        lastAlertTime = time[0];
                    }
                }
            }
        }
        
        // Обновление самообучения
        if(EnableSelfLearning && i > 0)
        {
            UpdateLearningData(i, time[i], close[i], probability);
        }
    }
    
    // Обновление информационной панели
    if(ShowInfoPanel && rates_total > 0)
    {
        UpdateInfoPanel(TrendBuffer[0], ProbabilityBuffer[0]);
    }
    
    // Построение графических объектов (каждые N свечей для оптимизации)
    static datetime lastDrawTime = 0;
    if(time[0] != lastDrawTime && ShowFibonacciLevels)
    {
        DrawFibonacciLevels(time, high, low, rates_total);
        lastDrawTime = time[0];
    }
    
    if(ShowSupportResistance)
    {
        UpdateSupportResistanceLevels(high, low, close, rates_total);
    }
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Расчет вероятности импульса (комплексный анализ)                |
//+------------------------------------------------------------------+
double CalculateSpikeProbability(
    int shift,
    const double &close[],
    const double &high[],
    const double &low[],
    const double &open[],
    const long &volume[],
    const double &ma1[],
    const double &ma2[],
    const double &ma3[],
    const double &rsi[],
    const double &macd_main[],
    const double &macd_signal[],
    const double &atr[],
    const double &bb_upper[],
    const double &bb_lower[],
    const double &stoch_main[],
    const double &stoch_signal[],
    const double &cci[],
    const double &wpr[],
    const double &momentum[],
    const double &alligator_jaw[],
    const double &alligator_teeth[],
    const double &alligator_lips[],
    const double &sar[],
    const double &ichimoku_tenkan[],
    const double &ichimoku_kijun[],
    const double &obv[],
    const double &mfi[],
    const double &ao[],
    const double &ac[]
)
{
    double score = 0.0;
    double maxScore = 0.0;
    
    // 1. Анализ скользящих средних (вес 10%)
    maxScore += 10.0;
    if(close[shift] > ma1[0] && ma1[0] > ma2[0] && ma2[0] > ma3[0])
        score += 10.0; // Сильный восходящий тренд
    else if(close[shift] < ma1[0] && ma1[0] < ma2[0] && ma2[0] < ma3[0])
        score += 10.0; // Сильный нисходящий тренд
    else if(close[shift] > ma1[0] && close[shift] > ma2[0])
        score += 5.0;  // Умеренный тренд
    else if(close[shift] < ma1[0] && close[shift] < ma2[0])
        score += 5.0;
    
    // 2. RSI - перекупленность/перепроданность (вес 15%)
    maxScore += 15.0;
    if(isBoomSymbol)
    {
        if(rsi[0] < 30) score += 15.0; // Перепроданность - вероятен отскок
        else if(rsi[0] < 40) score += 10.0;
        else if(rsi[0] > 50 && rsi[0] < 70) score += 5.0;
    }
    else if(isCrashSymbol)
    {
        if(rsi[0] > 70) score += 15.0; // Перекупленность - вероятно падение
        else if(rsi[0] > 60) score += 10.0;
        else if(rsi[0] > 30 && rsi[0] < 50) score += 5.0;
    }
    
    // 3. MACD - дивергенция и пересечения (вес 12%)
    maxScore += 12.0;
    if(macd_main[0] > macd_signal[0] && macd_main[1] <= macd_signal[1])
        score += 12.0; // Пересечение вверх
    else if(macd_main[0] < macd_signal[0] && macd_main[1] >= macd_signal[1])
        score += 12.0; // Пересечение вниз
    else if(MathAbs(macd_main[0] - macd_signal[0]) < MathAbs(macd_main[1] - macd_signal[1]))
        score += 6.0; // Схождение линий
    
    // 4. Bollinger Bands - выход за границы (вес 10%)
    maxScore += 10.0;
    if(isBoomSymbol && close[shift] <= bb_lower[0])
        score += 10.0; // Цена у нижней границы - вероятен рост
    else if(isCrashSymbol && close[shift] >= bb_upper[0])
        score += 10.0; // Цена у верхней границы - вероятно падение
    else if(close[shift] > bb_lower[0] && close[shift] < bb_upper[0])
        score += 3.0; // Внутри диапазона
    
    // 5. Stochastic - перекупленность/перепроданность (вес 8%)
    maxScore += 8.0;
    if(isBoomSymbol)
    {
        if(stoch_main[0] < 20) score += 8.0;
        else if(stoch_main[0] < 30) score += 5.0;
    }
    else if(isCrashSymbol)
    {
        if(stoch_main[0] > 80) score += 8.0;
        else if(stoch_main[0] > 70) score += 5.0;
    }
    
    // 6. CCI - экстремальные значения (вес 7%)
    maxScore += 7.0;
    if(isBoomSymbol && cci[0] < -100)
        score += 7.0;
    else if(isCrashSymbol && cci[0] > 100)
        score += 7.0;
    else if(MathAbs(cci[0]) > 50)
        score += 3.0;
    
    // 7. Williams %R (вес 6%)
    maxScore += 6.0;
    if(isBoomSymbol && wpr[0] < -80)
        score += 6.0;
    else if(isCrashSymbol && wpr[0] > -20)
        score += 6.0;
    
    // 8. Momentum (вес 5%)
    maxScore += 5.0;
    if(isBoomSymbol && momentum[0] < momentum[1] && momentum[1] < momentum[2])
        score += 5.0; // Падающий моментум - возможен разворот вверх
    else if(isCrashSymbol && momentum[0] > momentum[1] && momentum[1] > momentum[2])
        score += 5.0; // Растущий моментум - возможен разворот вниз
    
    // 9. Alligator - положение цены относительно линий (вес 7%)
    maxScore += 7.0;
    if(isBoomSymbol)
    {
        if(close[shift] < alligator_lips[0] && alligator_lips[0] < alligator_teeth[0] && alligator_teeth[0] < alligator_jaw[0])
            score += 7.0; // Цена ниже аллигатора - вероятен рост
    }
    else if(isCrashSymbol)
    {
        if(close[shift] > alligator_lips[0] && alligator_lips[0] > alligator_teeth[0] && alligator_teeth[0] > alligator_jaw[0])
            score += 7.0; // Цена выше аллигатора - вероятно падение
    }
    
    // 10. Parabolic SAR (вес 5%)
    maxScore += 5.0;
    if(isBoomSymbol && sar[0] > close[shift] && sar[1] < close[shift+1])
        score += 5.0; // Разворот вверх
    else if(isCrashSymbol && sar[0] < close[shift] && sar[1] > close[shift+1])
        score += 5.0; // Разворот вниз
    
    // 11. Ichimoku (вес 6%)
    maxScore += 6.0;
    if(isBoomSymbol && ichimoku_tenkan[0] > ichimoku_kijun[0] && ichimoku_tenkan[1] <= ichimoku_kijun[1])
        score += 6.0;
    else if(isCrashSymbol && ichimoku_tenkan[0] < ichimoku_kijun[0] && ichimoku_tenkan[1] >= ichimoku_kijun[1])
        score += 6.0;
    
    // 12. Money Flow Index (вес 5%)
    maxScore += 5.0;
    if(isBoomSymbol && mfi[0] < 20)
        score += 5.0;
    else if(isCrashSymbol && mfi[0] > 80)
        score += 5.0;
    
    // 13. Awesome Oscillator (вес 4%)
    maxScore += 4.0;
    if(isBoomSymbol && ao[0] > ao[1] && ao[1] < ao[2])
        score += 4.0; // Разворот вверх
    else if(isCrashSymbol && ao[0] < ao[1] && ao[1] > ao[2])
        score += 4.0; // Разворот вниз
    
    // 14. Accelerator Oscillator (вес 4%)
    maxScore += 4.0;
    if(isBoomSymbol && ac[0] > 0 && ac[1] <= 0)
        score += 4.0;
    else if(isCrashSymbol && ac[0] < 0 && ac[1] >= 0)
        score += 4.0;
    
    // 15. ATR - волатильность (вес 6%)
    maxScore += 6.0;
    double avgATR = (atr[0] + atr[1] + atr[2]) / 3.0;
    if(atr[0] > avgATR * 1.5)
        score += 6.0; // Высокая волатильность - вероятен импульс
    else if(atr[0] > avgATR * 1.2)
        score += 3.0;
    
    // Нормализация вероятности
    double probability = (maxScore > 0) ? (score / maxScore) : 0.0;
    
    // Применение самообучения (корректировка на основе истории)
    if(EnableSelfLearning && historySize > 10)
    {
        double learningAdjustment = CalculateLearningAdjustment(probability);
        probability = probability * (1.0 - LearningRate) + learningAdjustment * LearningRate;
    }
    
    return MathMin(1.0, MathMax(0.0, probability));
}

//+------------------------------------------------------------------+
//| Определение тренда                                               |
//+------------------------------------------------------------------+
int DetermineTrend(double ma1, double ma2, double ma3, double price)
{
    if(price > ma1 && ma1 > ma2 && ma2 > ma3)
        return 1;  // Восходящий тренд
    else if(price < ma1 && ma1 < ma2 && ma2 < ma3)
        return -1; // Нисходящий тренд
    else
        return 0;  // Боковой тренд
}

//+------------------------------------------------------------------+
//| Отправка оповещений                                              |
//+------------------------------------------------------------------+
void SendAlert(string title, string message, double probability)
{
    if(!EnableAlerts)
        return;
    
    string fullMessage = StringFormat("%s: %s (Вероятность: %.1f%%)", title, message, probability * 100);
    
    // Звуковое оповещение
    Alert(fullMessage);
    
    // Вывод в лог
    Print(fullMessage);
    
    // Push-уведомление
    if(EnablePushNotifications)
    {
        SendNotification(fullMessage);
    }
    
    // Email-уведомление
    if(EnableEmailNotifications)
    {
        SendMail("CrashBoom Spike Alert", fullMessage);
    }
}

//+------------------------------------------------------------------+
//| Создание информационной панели                                   |
//+------------------------------------------------------------------+
void CreateInfoPanel()
{
    string objName = "InfoPanel_Background";
    int x = 10, y = 30;
    int width = 250, height = 150;
    
    // Фон панели
    if(ObjectFind(0, objName) < 0)
    {
        ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, objName, OBJPROP_XSIZE, width);
        ObjectSetInteger(0, objName, OBJPROP_YSIZE, height);
        ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, clrBlack);
        ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, objName, OBJPROP_BACK, false);
        ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
    }
    
    // Заголовок
    objName = "InfoPanel_Title";
    if(ObjectFind(0, objName) < 0)
    {
        ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x + 10);
        ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y + 10);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clrYellow);
        ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
        ObjectSetString(0, objName, OBJPROP_FONT, "Arial Bold");
        ObjectSetString(0, objName, OBJPROP_TEXT, "CrashBoom Detector");
        ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
    }
}

//+------------------------------------------------------------------+
//| Обновление информационной панели                                 |
//+------------------------------------------------------------------+
void UpdateInfoPanel(double trend, double probability)
{
    int x = 10, y = 30;
    
    // Тренд
    string objName = "InfoPanel_Trend";
    if(ObjectFind(0, objName) < 0)
    {
        ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x + 10);
        ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y + 35);
        ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 9);
        ObjectSetString(0, objName, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
    }
    
    string trendText = "Тренд: ";
    color trendColor = clrWhite;
    if(trend > 0) { trendText += "Восходящий ↑"; trendColor = clrLime; }
    else if(trend < 0) { trendText += "Нисходящий ↓"; trendColor = clrRed; }
    else { trendText += "Боковой →"; trendColor = clrYellow; }
    
    ObjectSetString(0, objName, OBJPROP_TEXT, trendText);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, trendColor);
    
    // Вероятность импульса
    objName = "InfoPanel_Probability";
    if(ObjectFind(0, objName) < 0)
    {
        ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x + 10);
        ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y + 55);
        ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 9);
        ObjectSetString(0, objName, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
    }
    
    string probText = StringFormat("Вероятность импульса: %.1f%%", probability * 100);
    color probColor = clrWhite;
    if(probability >= 0.7) probColor = clrLime;
    else if(probability >= 0.5) probColor = clrYellow;
    else probColor = clrGray;
    
    ObjectSetString(0, objName, OBJPROP_TEXT, probText);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, probColor);
    
    // Тип символа
    objName = "InfoPanel_Symbol";
    if(ObjectFind(0, objName) < 0)
    {
        ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x + 10);
        ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y + 75);
        ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 9);
        ObjectSetString(0, objName, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
    }
    
    string symbolType = "Символ: ";
    if(isBoomSymbol) symbolType += "BOOM (Buy Spikes)";
    else if(isCrashSymbol) symbolType += "CRASH (Sell Spikes)";
    else symbolType += "Неизвестный";
    
    ObjectSetString(0, objName, OBJPROP_TEXT, symbolType);
    
    // Индикаторы RSI и текущие данные
    double rsi[];
    ArraySetAsSeries(rsi, true);
    if(CopyBuffer(handleRSI, 0, 0, 1, rsi) > 0)
    {
        objName = "InfoPanel_RSI";
        if(ObjectFind(0, objName) < 0)
        {
            ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x + 10);
            ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y + 95);
            ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 8);
            ObjectSetString(0, objName, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrSilver);
            ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
        }
        ObjectSetString(0, objName, OBJPROP_TEXT, StringFormat("RSI: %.1f", rsi[0]));
    }
    
    double atr[];
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(handleATR, 0, 0, 1, atr) > 0)
    {
        objName = "InfoPanel_ATR";
        if(ObjectFind(0, objName) < 0)
        {
            ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x + 10);
            ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y + 110);
            ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 8);
            ObjectSetString(0, objName, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrSilver);
            ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
        }
        ObjectSetString(0, objName, OBJPROP_TEXT, StringFormat("ATR: %.5f", atr[0]));
    }
    
    double macd[];
    ArraySetAsSeries(macd, true);
    if(CopyBuffer(handleMACD, 0, 0, 1, macd) > 0)
    {
        objName = "InfoPanel_MACD";
        if(ObjectFind(0, objName) < 0)
        {
            ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x + 10);
            ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y + 125);
            ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 8);
            ObjectSetString(0, objName, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrSilver);
            ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
        }
        ObjectSetString(0, objName, OBJPROP_TEXT, StringFormat("MACD: %.5f", macd[0]));
    }
}

//+------------------------------------------------------------------+
//| Построение уровней Фибоначчи                                     |
//+------------------------------------------------------------------+
void DrawFibonacciLevels(const datetime &time[], const double &high[], const double &low[], int rates_total)
{
    // Поиск максимума и минимума за последние N свечей
    int lookback = MathMin(100, rates_total - 1);
    double maxPrice = high[ArrayMaximum(high, 0, lookback)];
    double minPrice = low[ArrayMinimum(low, 0, lookback)];
    
    // Удаление старых уровней Фибоначчи
    ObjectDelete(0, "Fibo_Main");
    
    // Создание Фибоначчи
    if(ObjectFind(0, "Fibo_Main") < 0)
    {
        ObjectCreate(0, "Fibo_Main", OBJ_FIBO, 0, time[lookback], minPrice, time[0], maxPrice);
        ObjectSetInteger(0, "Fibo_Main", OBJPROP_COLOR, clrGold);
        ObjectSetInteger(0, "Fibo_Main", OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, "Fibo_Main", OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, "Fibo_Main", OBJPROP_BACK, true);
        ObjectSetInteger(0, "Fibo_Main", OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, "Fibo_Main", OBJPROP_HIDDEN, true);
        
        // Стандартные уровни Фибоначчи
        ObjectSetDouble(0, "Fibo_Main", OBJPROP_LEVELVALUE, 0, 0.0);
        ObjectSetDouble(0, "Fibo_Main", OBJPROP_LEVELVALUE, 1, 0.236);
        ObjectSetDouble(0, "Fibo_Main", OBJPROP_LEVELVALUE, 2, 0.382);
        ObjectSetDouble(0, "Fibo_Main", OBJPROP_LEVELVALUE, 3, 0.5);
        ObjectSetDouble(0, "Fibo_Main", OBJPROP_LEVELVALUE, 4, 0.618);
        ObjectSetDouble(0, "Fibo_Main", OBJPROP_LEVELVALUE, 5, 0.786);
        ObjectSetDouble(0, "Fibo_Main", OBJPROP_LEVELVALUE, 6, 1.0);
    }
}

//+------------------------------------------------------------------+
//| Обновление уровней поддержки/сопротивления                       |
//+------------------------------------------------------------------+
void UpdateSupportResistanceLevels(const double &high[], const double &low[], const double &close[], int rates_total)
{
    // Простой алгоритм поиска уровней S/R
    ArrayResize(srLevels, 0);
    
    int lookback = MathMin(SR_LookbackPeriod, rates_total - 1);
    double priceRange = high[ArrayMaximum(high, 0, lookback)] - low[ArrayMinimum(low, 0, lookback)];
    double tolerance = priceRange * 0.001; // 0.1% допуск
    
    // Поиск локальных экстремумов
    for(int i = 2; i < lookback - 2; i++)
    {
        // Локальный максимум
        if(high[i] > high[i-1] && high[i] > high[i-2] && high[i] > high[i+1] && high[i] > high[i+2])
        {
            AddSRLevel(high[i], false, tolerance);
        }
        
        // Локальный минимум
        if(low[i] < low[i-1] && low[i] < low[i-2] && low[i] < low[i+1] && low[i] < low[i+2])
        {
            AddSRLevel(low[i], true, tolerance);
        }
    }
    
    // Отрисовка уровней (только сильные с несколькими касаниями)
    DeleteSRLines();
    for(int i = 0; i < ArraySize(srLevels); i++)
    {
        if(srLevels[i].touches >= 2)
        {
            string objName = StringFormat("SR_Level_%d", i);
            if(ObjectFind(0, objName) < 0)
            {
                ObjectCreate(0, objName, OBJ_HLINE, 0, 0, srLevels[i].price);
                ObjectSetInteger(0, objName, OBJPROP_COLOR, srLevels[i].isSupport ? clrGreen : clrRed);
                ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DASH);
                ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
                ObjectSetInteger(0, objName, OBJPROP_BACK, true);
                ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Добавление уровня S/R                                            |
//+------------------------------------------------------------------+
void AddSRLevel(double price, bool isSupport, double tolerance)
{
    // Проверка, существует ли уже такой уровень
    for(int i = 0; i < ArraySize(srLevels); i++)
    {
        if(MathAbs(srLevels[i].price - price) < tolerance)
        {
            srLevels[i].touches++;
            srLevels[i].lastTouch = TimeCurrent();
            return;
        }
    }
    
    // Добавление нового уровня
    int size = ArraySize(srLevels);
    ArrayResize(srLevels, size + 1);
    srLevels[size].price = price;
    srLevels[size].touches = 1;
    srLevels[size].lastTouch = TimeCurrent();
    srLevels[size].isSupport = isSupport;
}

//+------------------------------------------------------------------+
//| Удаление линий S/R                                               |
//+------------------------------------------------------------------+
void DeleteSRLines()
{
    for(int i = ObjectsTotal(0, 0, OBJ_HLINE) - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i, 0, OBJ_HLINE);
        if(StringFind(objName, "SR_Level_") >= 0)
        {
            ObjectDelete(0, objName);
        }
    }
}

//+------------------------------------------------------------------+
//| Обновление данных самообучения                                   |
//+------------------------------------------------------------------+
void UpdateLearningData(int shift, datetime time, double price, double probability)
{
    if(!EnableSelfLearning || shift == 0)
        return;
    
    // Проверка, был ли реальный импульс после прогноза
    // (упрощенная версия - проверка большого движения цены)
    double priceChange = MathAbs(price - iClose(symbolName, Timeframe, shift + 5));
    double atr[];
    ArraySetAsSeries(atr, true);
    
    if(CopyBuffer(handleATR, 0, shift, 1, atr) > 0)
    {
        bool wasSpike = (priceChange > atr[0] * 3.0); // Движение больше 3 ATR
        
        if(historySize < LearningHistoryBars)
        {
            signalHistory[historySize].time = time;
            signalHistory[historySize].predictedPrice = price;
            signalHistory[historySize].wasSpike = wasSpike;
            signalHistory[historySize].accuracy = (wasSpike && probability > 0.5) ? 1.0 : 0.0;
            historySize++;
        }
    }
}

//+------------------------------------------------------------------+
//| Расчет корректировки на основе самообучения                      |
//+------------------------------------------------------------------+
double CalculateLearningAdjustment(double currentProbability)
{
    if(historySize < 10)
        return currentProbability;
    
    // Расчет средней точности прогнозов
    double totalAccuracy = 0.0;
    int count = 0;
    
    for(int i = 0; i < historySize && i < 100; i++)
    {
        totalAccuracy += signalHistory[i].accuracy;
        count++;
    }
    
    double avgAccuracy = (count > 0) ? (totalAccuracy / count) : 0.5;
    
    // Корректировка текущей вероятности на основе исторической точности
    return currentProbability * avgAccuracy;
}

//+------------------------------------------------------------------+
//| Удаление всех объектов индикатора                                |
//+------------------------------------------------------------------+
void DeleteAllObjects()
{
    for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i);
        if(StringFind(objName, "InfoPanel_") >= 0 || 
           StringFind(objName, "SR_Level_") >= 0 ||
           StringFind(objName, "Fibo_") >= 0)
        {
            ObjectDelete(0, objName);
        }
    }
}

//+------------------------------------------------------------------+
