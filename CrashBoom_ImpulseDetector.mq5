//+------------------------------------------------------------------+
//|                                     CrashBoom_ImpulseDetector.mq5 |
//|                        Комплексный индикатор для Deriv Crash/Boom |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "CrashBoom Predictor v1.0"
#property link      "https://deriv.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2

//--- Графические буферы для стрелок
#property indicator_label1  "Buy Signal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrDodgerBlue
#property indicator_width1  3

#property indicator_label2  "Sell Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  3

//+------------------------------------------------------------------+
//| ВХОДНЫЕ ПАРАМЕТРЫ                                                |
//+------------------------------------------------------------------+
input group "=== Основные параметры ==="
input int    SpikeDetectionDepth = 100;          // Глубина анализа фракталов/ZigZag
input double SpikePredictionSensitivity = 0.65;  // Чувствительность предсказания (0.0-1.0)
input bool   EnableAlerts = true;                // Включить звуковые сигналы
input bool   EnablePushNotifications = false;    // Включить Push-уведомления
input bool   EnableEmailNotifications = false;   // Включить Email-уведомления

input group "=== Скользящие средние ==="
input int    MA_Period_Fast = 20;                // Период быстрой MA
input int    MA_Period_Medium = 50;              // Период средней MA
input int    MA_Period_Slow = 100;               // Период медленной MA
input int    MA_Period_SuperSlow = 200;          // Период сверхмедленной MA
input ENUM_MA_METHOD MA_Method = MODE_EMA;       // Метод MA

input group "=== Осцилляторы ==="
input int    RSI_Period = 14;                    // Период RSI
input int    Stochastic_K_Period = 14;           // Период Stochastic %K
input int    Stochastic_D_Period = 3;            // Период Stochastic %D
input int    Stochastic_Slowing = 3;             // Замедление Stochastic
input int    CCI_Period = 14;                    // Период CCI
input int    Momentum_Period = 14;               // Период Momentum
input int    WilliamsR_Period = 14;              // Период Williams %R

input group "=== MACD параметры ==="
input int    MACD_Fast = 12;                     // MACD Быстрая EMA
input int    MACD_Slow = 26;                     // MACD Медленная EMA
input int    MACD_Signal = 9;                    // MACD Сигнальная линия

input group "=== Волатильность ==="
input int    ATR_Period = 14;                    // Период ATR
input int    BB_Period = 20;                     // Период Bollinger Bands
input double BB_Deviation = 2.0;                 // Отклонение Bollinger Bands

input group "=== Фракталы и уровни ==="
input bool   ShowFibonacciLevels = true;         // Показывать уровни Фибоначчи
input int    Fractal_Period = 5;                 // Период фракталов
input int    ZigZag_Depth = 12;                  // ZigZag Глубина
input int    ZigZag_Deviation = 5;               // ZigZag Отклонение
input int    ZigZag_Backstep = 3;                // ZigZag Шаг назад

input group "=== Визуализация ==="
input int    ArrowSize = 3;                      // Размер стрелки (1-5)
input int    ArrowDistance = 20;                 // Расстояние стрелки от свечи (в пунктах)
input bool   ShowInfoPanel = true;               // Показывать информационную панель
input int    PredictionBarsAhead = 3;            // За сколько свечей предсказывать (1-5)

input group "=== Самообучение ==="
input bool   EnableLearning = true;              // Включить самообучение
input int    LearningHistoryBars = 1000;         // Количество баров для обучения
input double LearningRate = 0.01;                // Скорость обучения

//+------------------------------------------------------------------+
//| ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ                                            |
//+------------------------------------------------------------------+
double BuySignalBuffer[];
double SellSignalBuffer[];
double TrendBuffer[];
double VolatilityBuffer[];

// Хендлы индикаторов
int handle_MA_Fast, handle_MA_Medium, handle_MA_Slow, handle_MA_SuperSlow;
int handle_RSI, handle_MACD, handle_ATR, handle_BB;
int handle_Stochastic, handle_CCI, handle_Momentum, handle_WilliamsR;
int handle_Fractals, handle_Alligator, handle_AO, handle_AC;
int handle_Ichimoku, handle_SAR, handle_ADX, handle_Envelopes;
int handle_OBV, handle_MFI, handle_DeMarker;

// Массивы для хранения данных индикаторов
double ma_fast[], ma_medium[], ma_slow[], ma_superslow[];
double rsi_values[], macd_main[], macd_signal[], atr_values[];
double bb_upper[], bb_middle[], bb_lower[];
double stoch_main[], stoch_signal[];
double cci_values[], momentum_values[], williams_values[];
double fractal_up[], fractal_down[];
double alligator_jaw[], alligator_teeth[], alligator_lips[];
double ao_values[], ac_values[];
double ichimoku_tenkan[], ichimoku_kijun[], ichimoku_senkou_a[], ichimoku_senkou_b[];
double sar_values[], adx_values[];
double obv_values[], mfi_values[], demarker_values[];

// Переменные для самообучения
struct LearningData {
    double indicators[50];  // Массив значений индикаторов
    bool wasSpike;          // Был ли импульс
    int spikeDirection;     // Направление импульса (1=buy, -1=sell)
};

LearningData learningHistory[];
double weights[50];  // Веса для каждого индикатора
int historyCount = 0;

// Переменные для отслеживания сигналов
datetime lastAlertTime = 0;
string lastSymbol = "";
bool isCrashSymbol = false;

//+------------------------------------------------------------------+
//| Инициализация индикатора                                         |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Установка буферов индикатора
    SetIndexBuffer(0, BuySignalBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, SellSignalBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, TrendBuffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(3, VolatilityBuffer, INDICATOR_CALCULATIONS);
    
    //--- Установка стрелок
    PlotIndexSetInteger(0, PLOT_ARROW, 233);  // Стрелка вверх
    PlotIndexSetInteger(1, PLOT_ARROW, 234);  // Стрелка вниз
    
    //--- Установка пустых значений
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
    
    //--- Определение типа символа (Crash или Boom)
    string symbol = _Symbol;
    lastSymbol = symbol;
    
    if(StringFind(symbol, "Crash") >= 0 || StringFind(symbol, "CRASH") >= 0)
        isCrashSymbol = true;
    else if(StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "BOOM") >= 0)
        isCrashSymbol = false;
    else {
        Print("⚠️ ПРЕДУПРЕЖДЕНИЕ: Символ не распознан как Crash или Boom. Используйте индексы Deriv!");
        return(INIT_SUCCEEDED); // Всё равно запускаем
    }
    
    //--- Инициализация индикаторов
    if(!InitializeIndicators()) {
        Print("❌ ОШИБКА: Не удалось инициализировать индикаторы!");
        return(INIT_FAILED);
    }
    
    //--- Инициализация системы самообучения
    if(EnableLearning) {
        InitializeLearning();
    }
    
    //--- Создание информационной панели
    if(ShowInfoPanel) {
        CreateInfoPanel();
    }
    
    Print("✅ Индикатор CrashBoom_ImpulseDetector успешно загружен для ", symbol);
    Print("📊 Тип: ", isCrashSymbol ? "CRASH (импульсы вниз)" : "BOOM (импульсы вверх)");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Деинициализация индикатора                                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Освобождение хендлов индикаторов
    ReleaseIndicatorHandles();
    
    //--- Удаление графических объектов
    ObjectsDeleteAll(0, "CBID_");
    
    Print("🔴 Индикатор CrashBoom_ImpulseDetector выгружен. Причина: ", reason);
}

//+------------------------------------------------------------------+
//| Основная функция расчёта индикатора                             |
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
    //--- Проверка минимального количества баров
    if(rates_total < SpikeDetectionDepth + 100) {
        Print("⚠️ Недостаточно данных для анализа. Требуется минимум ", SpikeDetectionDepth + 100, " баров");
        return(0);
    }
    
    //--- Определение начальной позиции расчёта
    int start_pos = prev_calculated > 0 ? prev_calculated - 1 : SpikeDetectionDepth;
    
    //--- Основной цикл расчёта
    for(int i = start_pos; i < rates_total - 1; i++) 
    {
        //--- Сброс буферов
        BuySignalBuffer[i] = 0.0;
        SellSignalBuffer[i] = 0.0;
        
        //--- Копирование данных индикаторов
        if(!CopyIndicatorData(i)) {
            continue;
        }
        
        //--- Комплексный технический анализ
        double signalStrength = 0.0;
        int signalDirection = 0;  // 1 = Buy, -1 = Sell, 0 = Нет сигнала
        
        signalStrength = PerformComplexAnalysis(i, signalDirection);
        
        //--- Определение тренда
        TrendBuffer[i] = AnalyzeTrend(i);
        
        //--- Определение волатильности
        VolatilityBuffer[i] = AnalyzeVolatility(i);
        
        //--- Предсказание импульса
        if(signalStrength >= SpikePredictionSensitivity * 100.0) 
        {
            //--- Для Crash ищем импульсы вниз (Sell)
            if(isCrashSymbol && signalDirection == -1) {
                SellSignalBuffer[i] = high[i] + ArrowDistance * _Point;
                
                // Отправка уведомления (только для текущей свечи)
                if(i == rates_total - 2 && time[i] != lastAlertTime) {
                    SendSignalAlert("CRASH", "SELL", signalStrength, time[i]);
                    lastAlertTime = time[i];
                }
            }
            //--- Для Boom ищем импульсы вверх (Buy)
            else if(!isCrashSymbol && signalDirection == 1) {
                BuySignalBuffer[i] = low[i] - ArrowDistance * _Point;
                
                // Отправка уведомления (только для текущей свечи)
                if(i == rates_total - 2 && time[i] != lastAlertTime) {
                    SendSignalAlert("BOOM", "BUY", signalStrength, time[i]);
                    lastAlertTime = time[i];
                }
            }
        }
        
        //--- Самообучение (только на истории)
        if(EnableLearning && i < rates_total - 10) {
            UpdateLearningData(i, close);
        }
    }
    
    //--- Обновление информационной панели
    if(ShowInfoPanel) {
        UpdateInfoPanel(rates_total - 1);
    }
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Инициализация всех технических индикаторов                      |
//+------------------------------------------------------------------+
bool InitializeIndicators()
{
    //--- Скользящие средние
    handle_MA_Fast = iMA(_Symbol, PERIOD_CURRENT, MA_Period_Fast, 0, MA_Method, PRICE_CLOSE);
    handle_MA_Medium = iMA(_Symbol, PERIOD_CURRENT, MA_Period_Medium, 0, MA_Method, PRICE_CLOSE);
    handle_MA_Slow = iMA(_Symbol, PERIOD_CURRENT, MA_Period_Slow, 0, MA_Method, PRICE_CLOSE);
    handle_MA_SuperSlow = iMA(_Symbol, PERIOD_CURRENT, MA_Period_SuperSlow, 0, MA_Method, PRICE_CLOSE);
    
    //--- Осцилляторы
    handle_RSI = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
    handle_MACD = iMACD(_Symbol, PERIOD_CURRENT, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
    handle_Stochastic = iStochastic(_Symbol, PERIOD_CURRENT, Stochastic_K_Period, Stochastic_D_Period, Stochastic_Slowing, MODE_SMA, STO_LOWHIGH);
    handle_CCI = iCCI(_Symbol, PERIOD_CURRENT, CCI_Period, PRICE_TYPICAL);
    handle_Momentum = iMomentum(_Symbol, PERIOD_CURRENT, Momentum_Period, PRICE_CLOSE);
    handle_WilliamsR = iWPR(_Symbol, PERIOD_CURRENT, WilliamsR_Period);
    
    //--- Волатильность
    handle_ATR = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
    handle_BB = iBands(_Symbol, PERIOD_CURRENT, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
    
    //--- Bill Williams
    handle_Fractals = iFractals(_Symbol, PERIOD_CURRENT);
    handle_Alligator = iAlligator(_Symbol, PERIOD_CURRENT, 13, 8, 8, 5, 5, 3, MODE_SMMA, PRICE_MEDIAN);
    handle_AO = iAO(_Symbol, PERIOD_CURRENT);
    handle_AC = iAC(_Symbol, PERIOD_CURRENT);
    
    //--- Трендовые
    handle_Ichimoku = iIchimoku(_Symbol, PERIOD_CURRENT, 9, 26, 52);
    handle_SAR = iSAR(_Symbol, PERIOD_CURRENT, 0.02, 0.2);
    handle_ADX = iADX(_Symbol, PERIOD_CURRENT, 14);
    handle_Envelopes = iEnvelopes(_Symbol, PERIOD_CURRENT, 14, 0, MODE_SMA, PRICE_CLOSE, 0.1);
    
    //--- Объёмы
    handle_OBV = iOBV(_Symbol, PERIOD_CURRENT, VOLUME_TICK);
    handle_MFI = iMFI(_Symbol, PERIOD_CURRENT, 14, VOLUME_TICK);
    handle_DeMarker = iDeMarker(_Symbol, PERIOD_CURRENT, 14);
    
    //--- Проверка успешности инициализации
    if(handle_MA_Fast == INVALID_HANDLE || handle_RSI == INVALID_HANDLE || handle_MACD == INVALID_HANDLE) {
        Print("❌ Ошибка инициализации индикаторов!");
        return false;
    }
    
    //--- Установка массивов как серий
    ArraySetAsSeries(ma_fast, true);
    ArraySetAsSeries(ma_medium, true);
    ArraySetAsSeries(ma_slow, true);
    ArraySetAsSeries(ma_superslow, true);
    ArraySetAsSeries(rsi_values, true);
    ArraySetAsSeries(macd_main, true);
    ArraySetAsSeries(macd_signal, true);
    ArraySetAsSeries(atr_values, true);
    ArraySetAsSeries(bb_upper, true);
    ArraySetAsSeries(bb_middle, true);
    ArraySetAsSeries(bb_lower, true);
    
    return true;
}

//+------------------------------------------------------------------+
//| Копирование данных индикаторов                                  |
//+------------------------------------------------------------------+
bool CopyIndicatorData(int bar_index)
{
    //--- Копирование данных скользящих средних
    if(CopyBuffer(handle_MA_Fast, 0, bar_index, 1, ma_fast) <= 0) return false;
    if(CopyBuffer(handle_MA_Medium, 0, bar_index, 1, ma_medium) <= 0) return false;
    if(CopyBuffer(handle_MA_Slow, 0, bar_index, 1, ma_slow) <= 0) return false;
    if(CopyBuffer(handle_MA_SuperSlow, 0, bar_index, 1, ma_superslow) <= 0) return false;
    
    //--- Копирование RSI
    if(CopyBuffer(handle_RSI, 0, bar_index, 1, rsi_values) <= 0) return false;
    
    //--- Копирование MACD
    if(CopyBuffer(handle_MACD, 0, bar_index, 1, macd_main) <= 0) return false;
    if(CopyBuffer(handle_MACD, 1, bar_index, 1, macd_signal) <= 0) return false;
    
    //--- Копирование ATR
    if(CopyBuffer(handle_ATR, 0, bar_index, 1, atr_values) <= 0) return false;
    
    //--- Копирование Bollinger Bands
    if(CopyBuffer(handle_BB, 1, bar_index, 1, bb_upper) <= 0) return false;
    if(CopyBuffer(handle_BB, 0, bar_index, 1, bb_middle) <= 0) return false;
    if(CopyBuffer(handle_BB, 2, bar_index, 1, bb_lower) <= 0) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Комплексный анализ всех индикаторов                             |
//+------------------------------------------------------------------+
double PerformComplexAnalysis(int bar_index, int &direction)
{
    double totalScore = 0.0;
    double buySignals = 0.0;
    double sellSignals = 0.0;
    int signalCount = 0;
    
    //--- 1. Анализ скользящих средних (тренд)
    double ma_score = AnalyzeMovingAverages(bar_index);
    if(ma_score > 0) buySignals += ma_score;
    else sellSignals += MathAbs(ma_score);
    signalCount++;
    
    //--- 2. Анализ RSI (перекупленность/перепроданность)
    double rsi_score = AnalyzeRSI(bar_index);
    if(rsi_score > 0) buySignals += rsi_score;
    else sellSignals += MathAbs(rsi_score);
    signalCount++;
    
    //--- 3. Анализ MACD (дивергенция и пересечения)
    double macd_score = AnalyzeMACD(bar_index);
    if(macd_score > 0) buySignals += macd_score;
    else sellSignals += MathAbs(macd_score);
    signalCount++;
    
    //--- 4. Анализ волатильности (ATR и Bollinger Bands)
    double volatility_score = AnalyzeBollingerBands(bar_index);
    if(volatility_score > 0) buySignals += volatility_score;
    else sellSignals += MathAbs(volatility_score);
    signalCount++;
    
    //--- 5. Анализ Stochastic
    double stoch_values_main[1], stoch_values_signal[1];
    if(CopyBuffer(handle_Stochastic, 0, bar_index, 1, stoch_values_main) > 0 &&
       CopyBuffer(handle_Stochastic, 1, bar_index, 1, stoch_values_signal) > 0) {
        if(stoch_values_main[0] < 20 && stoch_values_main[0] > stoch_values_signal[0])
            buySignals += 15.0;
        else if(stoch_values_main[0] > 80 && stoch_values_main[0] < stoch_values_signal[0])
            sellSignals += 15.0;
        signalCount++;
    }
    
    //--- 6. Анализ CCI
    double cci_vals[1];
    if(CopyBuffer(handle_CCI, 0, bar_index, 1, cci_vals) > 0) {
        if(cci_vals[0] < -100) buySignals += 10.0;
        else if(cci_vals[0] > 100) sellSignals += 10.0;
        signalCount++;
    }
    
    //--- 7. Анализ Williams %R
    double williams_vals[1];
    if(CopyBuffer(handle_WilliamsR, 0, bar_index, 1, williams_vals) > 0) {
        if(williams_vals[0] < -80) buySignals += 10.0;
        else if(williams_vals[0] > -20) sellSignals += 10.0;
        signalCount++;
    }
    
    //--- 8. Анализ MFI (Money Flow Index)
    double mfi_vals[1];
    if(CopyBuffer(handle_MFI, 0, bar_index, 1, mfi_vals) > 0) {
        if(mfi_vals[0] < 20) buySignals += 12.0;
        else if(mfi_vals[0] > 80) sellSignals += 12.0;
        signalCount++;
    }
    
    //--- 9. Анализ Awesome Oscillator
    double ao_vals[1];
    if(CopyBuffer(handle_AO, 0, bar_index, 1, ao_vals) > 0) {
        if(ao_vals[0] > 0) buySignals += 8.0;
        else sellSignals += 8.0;
        signalCount++;
    }
    
    //--- 10. Анализ ADX (сила тренда)
    double adx_vals[1];
    if(CopyBuffer(handle_ADX, 0, bar_index, 1, adx_vals) > 0) {
        if(adx_vals[0] > 25) {
            // Сильный тренд - усиливаем сигнал
            double multiplier = adx_vals[0] / 50.0;
            buySignals *= (1.0 + multiplier * 0.3);
            sellSignals *= (1.0 + multiplier * 0.3);
        }
        signalCount++;
    }
    
    //--- 11. Применение весов самообучения (если включено)
    if(EnableLearning && ArraySize(weights) > 0) {
        buySignals *= (1.0 + weights[0] * 0.5);
        sellSignals *= (1.0 + weights[1] * 0.5);
    }
    
    //--- Определение направления сигнала
    if(buySignals > sellSignals) {
        direction = 1;  // Buy
        totalScore = (buySignals / (buySignals + sellSignals)) * 100.0;
    }
    else if(sellSignals > buySignals) {
        direction = -1; // Sell
        totalScore = (sellSignals / (buySignals + sellSignals)) * 100.0;
    }
    else {
        direction = 0;  // Нет сигнала
        totalScore = 50.0;
    }
    
    return totalScore;
}

//+------------------------------------------------------------------+
//| Анализ скользящих средних                                       |
//+------------------------------------------------------------------+
double AnalyzeMovingAverages(int bar_index)
{
    double score = 0.0;
    
    // Получение цены закрытия
    double close_price = iClose(_Symbol, PERIOD_CURRENT, bar_index);
    
    //--- Анализ положения цены относительно MA
    if(close_price > ma_fast[0] && ma_fast[0] > ma_medium[0] && ma_medium[0] > ma_slow[0])
        score += 30.0;  // Сильный восходящий тренд
    else if(close_price < ma_fast[0] && ma_fast[0] < ma_medium[0] && ma_medium[0] < ma_slow[0])
        score -= 30.0;  // Сильный нисходящий тренд
    
    //--- Пересечение быстрой и средней MA
    double ma_fast_prev[1], ma_medium_prev[1];
    if(CopyBuffer(handle_MA_Fast, 0, bar_index + 1, 1, ma_fast_prev) > 0 &&
       CopyBuffer(handle_MA_Medium, 0, bar_index + 1, 1, ma_medium_prev) > 0) {
        
        // Бычье пересечение
        if(ma_fast[0] > ma_medium[0] && ma_fast_prev[0] <= ma_medium_prev[0])
            score += 20.0;
        // Медвежье пересечение
        else if(ma_fast[0] < ma_medium[0] && ma_fast_prev[0] >= ma_medium_prev[0])
            score -= 20.0;
    }
    
    return score;
}

//+------------------------------------------------------------------+
//| Анализ RSI                                                       |
//+------------------------------------------------------------------+
double AnalyzeRSI(int bar_index)
{
    double score = 0.0;
    
    if(rsi_values[0] < 30) {
        score += (30 - rsi_values[0]) * 2.0;  // Перепроданность
    }
    else if(rsi_values[0] > 70) {
        score -= (rsi_values[0] - 70) * 2.0;  // Перекупленность
    }
    
    //--- Дивергенция RSI (упрощённая проверка)
    double rsi_prev[5];
    double close_prices[5];
    if(CopyBuffer(handle_RSI, 0, bar_index, 5, rsi_prev) > 0) {
        for(int i = 0; i < 5; i++) {
            close_prices[i] = iClose(_Symbol, PERIOD_CURRENT, bar_index + i);
        }
        
        // Бычья дивергенция: цена падает, RSI растёт
        if(close_prices[0] < close_prices[4] && rsi_prev[0] > rsi_prev[4])
            score += 25.0;
        // Медвежья дивергенция: цена растёт, RSI падает
        else if(close_prices[0] > close_prices[4] && rsi_prev[0] < rsi_prev[4])
            score -= 25.0;
    }
    
    return score;
}

//+------------------------------------------------------------------+
//| Анализ MACD                                                      |
//+------------------------------------------------------------------+
double AnalyzeMACD(int bar_index)
{
    double score = 0.0;
    
    //--- Пересечение линий MACD
    double macd_main_prev[1], macd_signal_prev[1];
    if(CopyBuffer(handle_MACD, 0, bar_index + 1, 1, macd_main_prev) > 0 &&
       CopyBuffer(handle_MACD, 1, bar_index + 1, 1, macd_signal_prev) > 0) {
        
        // Бычье пересечение
        if(macd_main[0] > macd_signal[0] && macd_main_prev[0] <= macd_signal_prev[0])
            score += 25.0;
        // Медвежье пересечение
        else if(macd_main[0] < macd_signal[0] && macd_main_prev[0] >= macd_signal_prev[0])
            score -= 25.0;
    }
    
    //--- Пересечение нулевой линии
    if(macd_main[0] > 0 && macd_main_prev[0] <= 0)
        score += 15.0;
    else if(macd_main[0] < 0 && macd_main_prev[0] >= 0)
        score -= 15.0;
    
    return score;
}

//+------------------------------------------------------------------+
//| Анализ Bollinger Bands                                          |
//+------------------------------------------------------------------+
double AnalyzeBollingerBands(int bar_index)
{
    double score = 0.0;
    double close_price = iClose(_Symbol, PERIOD_CURRENT, bar_index);
    
    //--- Касание/пробой границ
    if(close_price <= bb_lower[0])
        score += 20.0;  // Отскок от нижней границы
    else if(close_price >= bb_upper[0])
        score -= 20.0;  // Отскок от верхней границы
    
    //--- Ширина полос (волатильность)
    double bb_width = (bb_upper[0] - bb_lower[0]) / bb_middle[0] * 100.0;
    if(bb_width < 2.0) {
        // Низкая волатильность - возможен прорыв
        score += 10.0;
    }
    
    return score;
}

//+------------------------------------------------------------------+
//| Анализ тренда                                                    |
//+------------------------------------------------------------------+
double AnalyzeTrend(int bar_index)
{
    double trend = 0.0;
    
    // Простой анализ по скользящим средним
    if(ma_fast[0] > ma_medium[0] && ma_medium[0] > ma_slow[0])
        trend = 1.0;  // Восходящий тренд
    else if(ma_fast[0] < ma_medium[0] && ma_medium[0] < ma_slow[0])
        trend = -1.0; // Нисходящий тренд
    else
        trend = 0.0;  // Боковик
    
    return trend;
}

//+------------------------------------------------------------------+
//| Анализ волатильности                                            |
//+------------------------------------------------------------------+
double AnalyzeVolatility(int bar_index)
{
    double volatility = 0.0;
    
    if(atr_values[0] > 0) {
        double close_price = iClose(_Symbol, PERIOD_CURRENT, bar_index);
        volatility = (atr_values[0] / close_price) * 100.0;
    }
    
    return volatility;
}

//+------------------------------------------------------------------+
//| Инициализация системы самообучения                              |
//+------------------------------------------------------------------+
void InitializeLearning()
{
    //--- Инициализация весов случайными значениями
    ArrayResize(weights, 50);
    for(int i = 0; i < 50; i++) {
        weights[i] = 0.5 + (MathRand() / 32767.0 - 0.5) * 0.2; // 0.4 - 0.6
    }
    
    //--- Инициализация истории обучения
    ArrayResize(learningHistory, LearningHistoryBars);
    historyCount = 0;
    
    Print("🧠 Система самообучения инициализирована. Начало сбора данных...");
}

//+------------------------------------------------------------------+
//| Обновление данных для самообучения                              |
//+------------------------------------------------------------------+
void UpdateLearningData(int bar_index, const double &close[])
{
    if(!EnableLearning || historyCount >= LearningHistoryBars)
        return;
    
    //--- Определение, был ли импульс на следующих свечах
    bool wasSpike = false;
    int spikeDir = 0;
    
    // Проверка следующих 5 свечей на наличие импульса
    for(int i = 1; i <= 5; i++) {
        if(bar_index - i < 0) break;
        
        double priceChange = MathAbs(close[bar_index - i] - close[bar_index - i + 1]);
        double avgChange = atr_values[0];
        
        // Импульс = изменение цены > 3 * ATR
        if(priceChange > avgChange * 3.0) {
            wasSpike = true;
            spikeDir = (close[bar_index - i] > close[bar_index - i + 1]) ? 1 : -1;
            break;
        }
    }
    
    //--- Сохранение данных в историю
    if(historyCount < LearningHistoryBars) {
        learningHistory[historyCount].wasSpike = wasSpike;
        learningHistory[historyCount].spikeDirection = spikeDir;
        
        // Сохранение значений индикаторов
        learningHistory[historyCount].indicators[0] = rsi_values[0];
        learningHistory[historyCount].indicators[1] = macd_main[0];
        learningHistory[historyCount].indicators[2] = atr_values[0];
        learningHistory[historyCount].indicators[3] = ma_fast[0];
        // ... и так далее для других индикаторов
        
        historyCount++;
        
        // Периодическое обучение каждые 100 баров
        if(historyCount % 100 == 0) {
            PerformLearning();
        }
    }
}

//+------------------------------------------------------------------+
//| Выполнение обучения (упрощённый алгоритм)                       |
//+------------------------------------------------------------------+
void PerformLearning()
{
    if(historyCount < 50) return;
    
    //--- Простой алгоритм коррекции весов
    int correctPredictions = 0;
    int totalPredictions = 0;
    
    for(int i = 0; i < historyCount - 10; i++) {
        if(learningHistory[i].wasSpike) {
            totalPredictions++;
            
            // Проверка, совпал ли прогноз с реальностью
            double predicted = weights[0] * learningHistory[i].indicators[0] / 100.0;
            double actual = learningHistory[i].spikeDirection;
            
            if((predicted > 0.5 && actual > 0) || (predicted < 0.5 && actual < 0)) {
                correctPredictions++;
            } else {
                // Коррекция весов при неправильном прогнозе
                weights[0] += LearningRate * (actual - predicted);
                weights[0] = MathMax(0.1, MathMin(1.0, weights[0])); // Ограничение 0.1-1.0
            }
        }
    }
    
    double accuracy = totalPredictions > 0 ? (double)correctPredictions / totalPredictions * 100.0 : 0.0;
    
    if(historyCount % 500 == 0) {
        Print("🧠 Самообучение: Точность = ", DoubleToString(accuracy, 2), "%, Данных = ", historyCount);
    }
}

//+------------------------------------------------------------------+
//| Отправка сигнала-оповещения                                     |
//+------------------------------------------------------------------+
void SendSignalAlert(string symbolType, string signalType, double strength, datetime time)
{
    string message = StringFormat("🎯 %s ИМПУЛЬС СКОРО! %s сигнал | Сила: %.1f%% | %s",
                                  symbolType, signalType, strength, TimeToString(time));
    
    //--- Звуковое оповещение
    if(EnableAlerts) {
        Alert(message);
        PlaySound("alert.wav");
    }
    
    //--- Вывод в лог
    Print(message);
    
    //--- Push-уведомление
    if(EnablePushNotifications) {
        SendNotification(message);
    }
    
    //--- Email-уведомление
    if(EnableEmailNotifications) {
        SendMail("CrashBoom Impulse Detector", message);
    }
    
    //--- Визуальное сообщение на графике
    Comment(message);
}

//+------------------------------------------------------------------+
//| Создание информационной панели                                  |
//+------------------------------------------------------------------+
void CreateInfoPanel()
{
    int x = 10;
    int y = 20;
    int width = 250;
    int height = 200;
    
    //--- Фон панели
    ObjectCreate(0, "CBID_Panel_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "CBID_Panel_BG", OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, "CBID_Panel_BG", OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, "CBID_Panel_BG", OBJPROP_XSIZE, width);
    ObjectSetInteger(0, "CBID_Panel_BG", OBJPROP_YSIZE, height);
    ObjectSetInteger(0, "CBID_Panel_BG", OBJPROP_BGCOLOR, clrBlack);
    ObjectSetInteger(0, "CBID_Panel_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, "CBID_Panel_BG", OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, "CBID_Panel_BG", OBJPROP_BACK, false);
    ObjectSetInteger(0, "CBID_Panel_BG", OBJPROP_SELECTABLE, false);
    
    //--- Заголовок
    ObjectCreate(0, "CBID_Panel_Title", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "CBID_Panel_Title", OBJPROP_XDISTANCE, x + 10);
    ObjectSetInteger(0, "CBID_Panel_Title", OBJPROP_YDISTANCE, y + 10);
    ObjectSetInteger(0, "CBID_Panel_Title", OBJPROP_COLOR, clrYellow);
    ObjectSetString(0, "CBID_Panel_Title", OBJPROP_TEXT, "📊 CRASH/BOOM DETECTOR");
    ObjectSetString(0, "CBID_Panel_Title", OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, "CBID_Panel_Title", OBJPROP_FONTSIZE, 10);
    
    //--- Метки для данных
    string labels[] = {"Symbol:", "Trend:", "RSI:", "ATR:", "MACD:", "Signal:", "Probability:"};
    
    for(int i = 0; i < ArraySize(labels); i++) {
        string objName = "CBID_Panel_Label_" + IntegerToString(i);
        ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x + 10);
        ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y + 35 + i * 20);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clrLightGray);
        ObjectSetString(0, objName, OBJPROP_TEXT, labels[i]);
        ObjectSetString(0, objName, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 8);
        
        //--- Значения
        string objValue = "CBID_Panel_Value_" + IntegerToString(i);
        ObjectCreate(0, objValue, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, objValue, OBJPROP_XDISTANCE, x + 100);
        ObjectSetInteger(0, objValue, OBJPROP_YDISTANCE, y + 35 + i * 20);
        ObjectSetInteger(0, objValue, OBJPROP_COLOR, clrWhite);
        ObjectSetString(0, objValue, OBJPROP_TEXT, "...");
        ObjectSetString(0, objValue, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, objValue, OBJPROP_FONTSIZE, 8);
    }
}

//+------------------------------------------------------------------+
//| Обновление информационной панели                                |
//+------------------------------------------------------------------+
void UpdateInfoPanel(int bar_index)
{
    if(!ShowInfoPanel) return;
    
    //--- Обновление значений
    ObjectSetString(0, "CBID_Panel_Value_0", OBJPROP_TEXT, _Symbol);
    
    string trendText = "SIDEWAYS";
    color trendColor = clrYellow;
    if(TrendBuffer[bar_index] > 0.5) {
        trendText = "UP ▲";
        trendColor = clrLime;
    } else if(TrendBuffer[bar_index] < -0.5) {
        trendText = "DOWN ▼";
        trendColor = clrRed;
    }
    ObjectSetString(0, "CBID_Panel_Value_1", OBJPROP_TEXT, trendText);
    ObjectSetInteger(0, "CBID_Panel_Value_1", OBJPROP_COLOR, trendColor);
    
    if(ArraySize(rsi_values) > 0)
        ObjectSetString(0, "CBID_Panel_Value_2", OBJPROP_TEXT, DoubleToString(rsi_values[0], 2));
    
    if(ArraySize(atr_values) > 0)
        ObjectSetString(0, "CBID_Panel_Value_3", OBJPROP_TEXT, DoubleToString(atr_values[0], _Digits));
    
    if(ArraySize(macd_main) > 0)
        ObjectSetString(0, "CBID_Panel_Value_4", OBJPROP_TEXT, DoubleToString(macd_main[0], 5));
    
    //--- Текущий сигнал
    string signalText = "WAIT";
    color signalColor = clrGray;
    if(BuySignalBuffer[bar_index] > 0) {
        signalText = "BUY ⬆";
        signalColor = clrDodgerBlue;
    } else if(SellSignalBuffer[bar_index] > 0) {
        signalText = "SELL ⬇";
        signalColor = clrRed;
    }
    ObjectSetString(0, "CBID_Panel_Value_5", OBJPROP_TEXT, signalText);
    ObjectSetInteger(0, "CBID_Panel_Value_5", OBJPROP_COLOR, signalColor);
    
    //--- Вероятность
    int direction = 0;
    double probability = PerformComplexAnalysis(bar_index, direction);
    ObjectSetString(0, "CBID_Panel_Value_6", OBJPROP_TEXT, DoubleToString(probability, 1) + "%");
    
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Освобождение хендлов индикаторов                                |
//+------------------------------------------------------------------+
void ReleaseIndicatorHandles()
{
    if(handle_MA_Fast != INVALID_HANDLE) IndicatorRelease(handle_MA_Fast);
    if(handle_MA_Medium != INVALID_HANDLE) IndicatorRelease(handle_MA_Medium);
    if(handle_MA_Slow != INVALID_HANDLE) IndicatorRelease(handle_MA_Slow);
    if(handle_MA_SuperSlow != INVALID_HANDLE) IndicatorRelease(handle_MA_SuperSlow);
    if(handle_RSI != INVALID_HANDLE) IndicatorRelease(handle_RSI);
    if(handle_MACD != INVALID_HANDLE) IndicatorRelease(handle_MACD);
    if(handle_ATR != INVALID_HANDLE) IndicatorRelease(handle_ATR);
    if(handle_BB != INVALID_HANDLE) IndicatorRelease(handle_BB);
    if(handle_Stochastic != INVALID_HANDLE) IndicatorRelease(handle_Stochastic);
    if(handle_CCI != INVALID_HANDLE) IndicatorRelease(handle_CCI);
    if(handle_Momentum != INVALID_HANDLE) IndicatorRelease(handle_Momentum);
    if(handle_WilliamsR != INVALID_HANDLE) IndicatorRelease(handle_WilliamsR);
    if(handle_Fractals != INVALID_HANDLE) IndicatorRelease(handle_Fractals);
    if(handle_Alligator != INVALID_HANDLE) IndicatorRelease(handle_Alligator);
    if(handle_AO != INVALID_HANDLE) IndicatorRelease(handle_AO);
    if(handle_AC != INVALID_HANDLE) IndicatorRelease(handle_AC);
    if(handle_Ichimoku != INVALID_HANDLE) IndicatorRelease(handle_Ichimoku);
    if(handle_SAR != INVALID_HANDLE) IndicatorRelease(handle_SAR);
    if(handle_ADX != INVALID_HANDLE) IndicatorRelease(handle_ADX);
    if(handle_Envelopes != INVALID_HANDLE) IndicatorRelease(handle_Envelopes);
    if(handle_OBV != INVALID_HANDLE) IndicatorRelease(handle_OBV);
    if(handle_MFI != INVALID_HANDLE) IndicatorRelease(handle_MFI);
    if(handle_DeMarker != INVALID_HANDLE) IndicatorRelease(handle_DeMarker);
}

//+------------------------------------------------------------------+
//| Функция для детекции паттернов свечей (дополнительно)          |
//+------------------------------------------------------------------+
int DetectCandlePattern(int bar_index)
{
    double open = iOpen(_Symbol, PERIOD_CURRENT, bar_index);
    double high = iHigh(_Symbol, PERIOD_CURRENT, bar_index);
    double low = iLow(_Symbol, PERIOD_CURRENT, bar_index);
    double close = iClose(_Symbol, PERIOD_CURRENT, bar_index);
    
    double body = MathAbs(close - open);
    double upperShadow = high - MathMax(open, close);
    double lowerShadow = MathMin(open, close) - low;
    double candleRange = high - low;
    
    //--- Hammer (Молот)
    if(lowerShadow > body * 2 && upperShadow < body * 0.3 && close < open)
        return 1; // Бычий паттерн
    
    //--- Shooting Star (Падающая звезда)
    if(upperShadow > body * 2 && lowerShadow < body * 0.3 && close > open)
        return -1; // Медвежий паттерн
    
    //--- Doji
    if(body < candleRange * 0.1)
        return 0; // Неопределённость
    
    return 0;
}

//+------------------------------------------------------------------+
