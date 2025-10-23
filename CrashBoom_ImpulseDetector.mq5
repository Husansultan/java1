//+------------------------------------------------------------------+
//|                                        CrashBoom_ImpulseDetector.mq5 |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2

//--- Буферы индикатора
double BuyArrowBuffer[];
double SellArrowBuffer[];
double TrendBuffer[];
double ProbabilityBuffer[];

//--- Входные параметры
input group "=== Основные настройки ==="
input int                    SpikeDetectionDepth = 20;           // Глубина анализа фракталов
input double                 SpikePredictionSensitivity = 0.75;  // Чувствительность детекции (0.1-1.0)
input ENUM_TIMEFRAMES        AnalysisTimeframe = PERIOD_CURRENT; // Таймфрейм анализа

input group "=== Скользящие средние ==="
input int                    MovingAveragePeriod1 = 50;          // Период EMA 1
input int                    MovingAveragePeriod2 = 100;         // Период EMA 2  
input int                    MovingAveragePeriod3 = 200;         // Период EMA 3
input ENUM_MA_METHOD         MA_Method = MODE_EMA;               // Метод скользящей средней

input group "=== Осцилляторы ==="
input int                    RSI_Period = 14;                   // Период RSI
input int                    MACD_Fast = 12;                    // MACD быстрая EMA
input int                    MACD_Slow = 26;                    // MACD медленная EMA
input int                    MACD_Signal = 9;                   // MACD сигнальная линия
input int                    Stoch_K = 5;                       // Stochastic %K период
input int                    Stoch_D = 3;                       // Stochastic %D период
input int                    Stoch_Slowing = 3;                 // Stochastic замедление

input group "=== Волатильность ==="
input int                    ATR_Period = 14;                   // Период ATR
input int                    BB_Period = 20;                    // Период Bollinger Bands
input double                 BB_Deviation = 2.0;               // Отклонение Bollinger Bands

input group "=== Визуализация ==="
input bool                   ShowFibonacciLevels = true;        // Показывать Фибо-уровни
input bool                   ShowTrendLines = true;             // Показывать линии тренда
input bool                   ShowSupportResistance = true;      // Показывать уровни поддержки/сопротивления
input int                    ArrowSize = 2;                     // Размер стрелки
input int                    ArrowDistance = 10;                // Смещение стрелки от свечи
input color                  BuyArrowColor = clrBlue;           // Цвет стрелки покупки
input color                  SellArrowColor = clrRed;           // Цвет стрелки продажи

input group "=== Оповещения ==="
input bool                   EnableAlerts = true;               // Включить звуковые сигналы
input bool                   EnablePushNotifications = false;   // Включить Push уведомления
input bool                   EnableEmailAlerts = false;         // Включить Email уведомления
input string                 AlertSoundFile = "alert.wav";      // Звуковой файл для оповещений

input group "=== Самообучение ==="
input bool                   EnableSelfLearning = true;         // Включить самообучение
input int                    LearningHistoryBars = 1000;        // Количество баров для обучения
input double                 LearningRate = 0.01;               // Скорость обучения

//--- Глобальные переменные
int ma1_handle, ma2_handle, ma3_handle;
int rsi_handle, macd_handle, atr_handle, bb_handle;
int stoch_handle, fractals_handle, zigzag_handle;
int alligator_handle, ao_handle, ac_handle;
int cci_handle, momentum_handle, williams_handle;

datetime lastAlertTime = 0;
double learningWeights[];
int totalPredictions = 0;
int correctPredictions = 0;

//--- Структуры для анализа
struct TechnicalSignal
{
    double strength;      // Сила сигнала (-1 до +1)
    double confidence;    // Уверенность в сигнале (0 до 1)
    string description;   // Описание сигнала
};

struct MarketAnalysis
{
    double trend_strength;        // Сила тренда
    double volatility;           // Волатильность
    double momentum;             // Моментум
    double support_level;        // Уровень поддержки
    double resistance_level;     // Уровень сопротивления
    double fibonacci_level;      // Фибо уровень
    bool is_crash_symbol;        // Является ли символом Crash
    bool is_boom_symbol;         // Является ли символом Boom
};

//+------------------------------------------------------------------+
//| Функция инициализации индикатора                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Настройка буферов индикатора
    SetIndexBuffer(0, BuyArrowBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, SellArrowBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, TrendBuffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(3, ProbabilityBuffer, INDICATOR_CALCULATIONS);
    
    //--- Настройка стилей отображения
    PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_ARROW);
    PlotIndexSetInteger(0, PLOT_ARROW, 233); // Стрелка вверх
    PlotIndexSetString(0, PLOT_LABEL, "Boom Signal");
    PlotIndexSetInteger(0, PLOT_LINE_COLOR, BuyArrowColor);
    PlotIndexSetInteger(0, PLOT_LINE_WIDTH, ArrowSize);
    
    PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_ARROW);
    PlotIndexSetInteger(1, PLOT_ARROW, 234); // Стрелка вниз
    PlotIndexSetString(1, PLOT_LABEL, "Crash Signal");
    PlotIndexSetInteger(1, PLOT_LINE_COLOR, SellArrowColor);
    PlotIndexSetInteger(1, PLOT_LINE_WIDTH, ArrowSize);
    
    //--- Инициализация технических индикаторов
    if(!InitializeTechnicalIndicators())
    {
        Print("Ошибка инициализации технических индикаторов");
        return INIT_FAILED;
    }
    
    //--- Инициализация системы самообучения
    if(EnableSelfLearning)
    {
        ArrayResize(learningWeights, 20); // 20 различных сигналов
        ArrayInitialize(learningWeights, 1.0);
    }
    
    //--- Проверка символа
    string symbol = Symbol();
    if(!IsValidCrashBoomSymbol(symbol))
    {
        Print("Предупреждение: Индикатор оптимизирован для символов Crash/Boom от Deriv");
    }
    
    Print("Индикатор CrashBoom_ImpulseDetector успешно инициализирован для символа: ", symbol);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Функция деинициализации                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Освобождение хендлов индикаторов
    ReleaseTechnicalIndicators();
    
    //--- Очистка графических объектов
    CleanupGraphicalObjects();
    
    Print("Индикатор CrashBoom_ImpulseDetector деинициализирован");
}

//+------------------------------------------------------------------+
//| Основная функция расчета индикатора                               |
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
    if(rates_total < 100)
        return 0;
    
    //--- Определение начальной позиции для расчета
    int start = MathMax(prev_calculated - 1, 50);
    if(start < 50) start = 50;
    
    //--- Основной цикл расчета
    for(int i = start; i < rates_total - 1; i++)
    {
        //--- Инициализация буферов
        BuyArrowBuffer[i] = EMPTY_VALUE;
        SellArrowBuffer[i] = EMPTY_VALUE;
        TrendBuffer[i] = 0;
        ProbabilityBuffer[i] = 0;
        
        //--- Комплексный технический анализ
        MarketAnalysis analysis = PerformComplexAnalysis(i, time, open, high, low, close, tick_volume);
        
        //--- Определение сигналов
        TechnicalSignal signal = AnalyzeSignals(analysis, i);
        
        //--- Сохранение данных в буферы
        TrendBuffer[i] = signal.strength;
        ProbabilityBuffer[i] = signal.confidence;
        
        //--- Проверка условий для генерации сигнала
        if(signal.confidence >= SpikePredictionSensitivity)
        {
            if(analysis.is_boom_symbol && signal.strength > 0)
            {
                // Сигнал на покупку для Boom
                BuyArrowBuffer[i] = low[i] - ArrowDistance * _Point;
                
                if(i == rates_total - 2) // Только для последней свечи
                {
                    SendAlert("BOOM SPIKE SOON", "Ожидается импульс вверх на " + Symbol(), signal.confidence);
                    
                    if(ShowFibonacciLevels)
                        DrawFibonacciLevels(i, high, low);
                    
                    if(ShowTrendLines)
                        DrawTrendLine(i, high, low, true);
                }
            }
            else if(analysis.is_crash_symbol && signal.strength < 0)
            {
                // Сигнал на продажу для Crash
                SellArrowBuffer[i] = high[i] + ArrowDistance * _Point;
                
                if(i == rates_total - 2) // Только для последней свечи
                {
                    SendAlert("CRASH SPIKE SOON", "Ожидается импульс вниз на " + Symbol(), signal.confidence);
                    
                    if(ShowFibonacciLevels)
                        DrawFibonacciLevels(i, high, low);
                    
                    if(ShowTrendLines)
                        DrawTrendLine(i, high, low, false);
                }
            }
        }
        
        //--- Обновление системы самообучения
        if(EnableSelfLearning && i > LearningHistoryBars)
        {
            UpdateLearningSystem(i, signal, close);
        }
    }
    
    return rates_total;
}

//+------------------------------------------------------------------+
//| Инициализация технических индикаторов                             |
//+------------------------------------------------------------------+
bool InitializeTechnicalIndicators()
{
    //--- Скользящие средние
    ma1_handle = iMA(Symbol(), AnalysisTimeframe, MovingAveragePeriod1, 0, MA_Method, PRICE_CLOSE);
    ma2_handle = iMA(Symbol(), AnalysisTimeframe, MovingAveragePeriod2, 0, MA_Method, PRICE_CLOSE);
    ma3_handle = iMA(Symbol(), AnalysisTimeframe, MovingAveragePeriod3, 0, MA_Method, PRICE_CLOSE);
    
    //--- Осцилляторы
    rsi_handle = iRSI(Symbol(), AnalysisTimeframe, RSI_Period, PRICE_CLOSE);
    macd_handle = iMACD(Symbol(), AnalysisTimeframe, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
    stoch_handle = iStochastic(Symbol(), AnalysisTimeframe, Stoch_K, Stoch_D, Stoch_Slowing, MODE_SMA, STO_LOWHIGH);
    
    //--- Волатильность
    atr_handle = iATR(Symbol(), AnalysisTimeframe, ATR_Period);
    bb_handle = iBands(Symbol(), AnalysisTimeframe, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
    
    //--- Дополнительные индикаторы
    fractals_handle = iFractals(Symbol(), AnalysisTimeframe);
    zigzag_handle = iCustom(Symbol(), AnalysisTimeframe, "Examples\\ZigZag", 12, 5, 3);
    alligator_handle = iAlligator(Symbol(), AnalysisTimeframe, 13, 8, 8, 5, 5, 3, MODE_SMMA, PRICE_MEDIAN);
    ao_handle = iAO(Symbol(), AnalysisTimeframe);
    ac_handle = iAC(Symbol(), AnalysisTimeframe);
    cci_handle = iCCI(Symbol(), AnalysisTimeframe, 14, PRICE_TYPICAL);
    momentum_handle = iMomentum(Symbol(), AnalysisTimeframe, 14, PRICE_CLOSE);
    williams_handle = iWPR(Symbol(), AnalysisTimeframe, 14);
    
    //--- Проверка успешности создания хендлов
    if(ma1_handle == INVALID_HANDLE || ma2_handle == INVALID_HANDLE || ma3_handle == INVALID_HANDLE ||
       rsi_handle == INVALID_HANDLE || macd_handle == INVALID_HANDLE || atr_handle == INVALID_HANDLE ||
       bb_handle == INVALID_HANDLE || stoch_handle == INVALID_HANDLE || fractals_handle == INVALID_HANDLE ||
       alligator_handle == INVALID_HANDLE || ao_handle == INVALID_HANDLE || ac_handle == INVALID_HANDLE ||
       cci_handle == INVALID_HANDLE || momentum_handle == INVALID_HANDLE || williams_handle == INVALID_HANDLE)
    {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Освобождение хендлов технических индикаторов                      |
//+------------------------------------------------------------------+
void ReleaseTechnicalIndicators()
{
    if(ma1_handle != INVALID_HANDLE) IndicatorRelease(ma1_handle);
    if(ma2_handle != INVALID_HANDLE) IndicatorRelease(ma2_handle);
    if(ma3_handle != INVALID_HANDLE) IndicatorRelease(ma3_handle);
    if(rsi_handle != INVALID_HANDLE) IndicatorRelease(rsi_handle);
    if(macd_handle != INVALID_HANDLE) IndicatorRelease(macd_handle);
    if(atr_handle != INVALID_HANDLE) IndicatorRelease(atr_handle);
    if(bb_handle != INVALID_HANDLE) IndicatorRelease(bb_handle);
    if(stoch_handle != INVALID_HANDLE) IndicatorRelease(stoch_handle);
    if(fractals_handle != INVALID_HANDLE) IndicatorRelease(fractals_handle);
    if(zigzag_handle != INVALID_HANDLE) IndicatorRelease(zigzag_handle);
    if(alligator_handle != INVALID_HANDLE) IndicatorRelease(alligator_handle);
    if(ao_handle != INVALID_HANDLE) IndicatorRelease(ao_handle);
    if(ac_handle != INVALID_HANDLE) IndicatorRelease(ac_handle);
    if(cci_handle != INVALID_HANDLE) IndicatorRelease(cci_handle);
    if(momentum_handle != INVALID_HANDLE) IndicatorRelease(momentum_handle);
    if(williams_handle != INVALID_HANDLE) IndicatorRelease(williams_handle);
}

//+------------------------------------------------------------------+
//| Комплексный технический анализ                                    |
//+------------------------------------------------------------------+
MarketAnalysis PerformComplexAnalysis(int index, 
                                     const datetime &time[],
                                     const double &open[],
                                     const double &high[],
                                     const double &low[],
                                     const double &close[],
                                     const long &tick_volume[])
{
    MarketAnalysis analysis;
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    //--- Определение типа символа
    string symbol = Symbol();
    analysis.is_crash_symbol = StringFind(symbol, "Crash") >= 0;
    analysis.is_boom_symbol = StringFind(symbol, "Boom") >= 0;
    
    //--- Анализ тренда через скользящие средние
    double ma1[], ma2[], ma3[];
    if(CopyBuffer(ma1_handle, 0, 0, 50, ma1) > 0 &&
       CopyBuffer(ma2_handle, 0, 0, 50, ma2) > 0 &&
       CopyBuffer(ma3_handle, 0, 0, 50, ma3) > 0)
    {
        ArraySetAsSeries(ma1, true);
        ArraySetAsSeries(ma2, true);
        ArraySetAsSeries(ma3, true);
        
        // Определение силы тренда
        if(ma1[0] > ma2[0] && ma2[0] > ma3[0])
            analysis.trend_strength = 1.0; // Сильный восходящий тренд
        else if(ma1[0] < ma2[0] && ma2[0] < ma3[0])
            analysis.trend_strength = -1.0; // Сильный нисходящий тренд
        else
            analysis.trend_strength = 0.0; // Боковой тренд
    }
    
    //--- Анализ волатильности через ATR
    double atr[];
    if(CopyBuffer(atr_handle, 0, 0, 20, atr) > 0)
    {
        ArraySetAsSeries(atr, true);
        analysis.volatility = atr[0];
    }
    
    //--- Анализ моментума
    double momentum_values[];
    if(CopyBuffer(momentum_handle, 0, 0, 10, momentum_values) > 0)
    {
        ArraySetAsSeries(momentum_values, true);
        analysis.momentum = momentum_values[0] - 100.0; // Нормализация
    }
    
    //--- Определение уровней поддержки и сопротивления
    analysis.support_level = FindSupportLevel(index, low, 20);
    analysis.resistance_level = FindResistanceLevel(index, high, 20);
    
    //--- Анализ Фибоначчи
    analysis.fibonacci_level = CalculateFibonacciLevel(index, high, low, 50);
    
    return analysis;
}

//+------------------------------------------------------------------+
//| Анализ сигналов на основе комплексных данных                      |
//+------------------------------------------------------------------+
TechnicalSignal AnalyzeSignals(MarketAnalysis &analysis, int index)
{
    TechnicalSignal signal;
    signal.strength = 0.0;
    signal.confidence = 0.0;
    signal.description = "";
    
    double signalSum = 0.0;
    double weightSum = 0.0;
    int signalCount = 0;
    
    //--- RSI анализ
    double rsi[];
    if(CopyBuffer(rsi_handle, 0, 0, 5, rsi) > 0)
    {
        ArraySetAsSeries(rsi, true);
        double rsiSignal = 0.0;
        
        if(analysis.is_crash_symbol)
        {
            if(rsi[0] > 70) rsiSignal = -0.8; // Перекупленность для Crash
            else if(rsi[0] < 30) rsiSignal = 0.2; // Перепроданность
        }
        else if(analysis.is_boom_symbol)
        {
            if(rsi[0] > 70) rsiSignal = 0.2; // Перекупленность для Boom
            else if(rsi[0] < 30) rsiSignal = 0.8; // Перепроданность
        }
        
        double weight = EnableSelfLearning ? learningWeights[0] : 1.0;
        signalSum += rsiSignal * weight;
        weightSum += weight;
        signalCount++;
    }
    
    //--- MACD анализ
    double macd_main[], macd_signal[];
    if(CopyBuffer(macd_handle, 0, 0, 5, macd_main) > 0 &&
       CopyBuffer(macd_handle, 1, 0, 5, macd_signal) > 0)
    {
        ArraySetAsSeries(macd_main, true);
        ArraySetAsSeries(macd_signal, true);
        
        double macdSignal = 0.0;
        if(macd_main[0] > macd_signal[0] && macd_main[1] <= macd_signal[1])
        {
            macdSignal = analysis.is_boom_symbol ? 0.7 : -0.7;
        }
        else if(macd_main[0] < macd_signal[0] && macd_main[1] >= macd_signal[1])
        {
            macdSignal = analysis.is_crash_symbol ? -0.7 : 0.7;
        }
        
        double weight = EnableSelfLearning ? learningWeights[1] : 1.0;
        signalSum += macdSignal * weight;
        weightSum += weight;
        signalCount++;
    }
    
    //--- Stochastic анализ
    double stoch_main[], stoch_signal_line[];
    if(CopyBuffer(stoch_handle, 0, 0, 5, stoch_main) > 0 &&
       CopyBuffer(stoch_handle, 1, 0, 5, stoch_signal_line) > 0)
    {
        ArraySetAsSeries(stoch_main, true);
        ArraySetAsSeries(stoch_signal_line, true);
        
        double stochSignal = 0.0;
        if(analysis.is_crash_symbol && stoch_main[0] > 80)
            stochSignal = -0.6;
        else if(analysis.is_boom_symbol && stoch_main[0] < 20)
            stochSignal = 0.6;
            
        double weight = EnableSelfLearning ? learningWeights[2] : 1.0;
        signalSum += stochSignal * weight;
        weightSum += weight;
        signalCount++;
    }
    
    //--- Bollinger Bands анализ
    double bb_upper[], bb_lower[], bb_middle[];
    if(CopyBuffer(bb_handle, 1, 0, 5, bb_upper) > 0 &&
       CopyBuffer(bb_handle, 2, 0, 5, bb_lower) > 0 &&
       CopyBuffer(bb_handle, 0, 0, 5, bb_middle) > 0)
    {
        ArraySetAsSeries(bb_upper, true);
        ArraySetAsSeries(bb_lower, true);
        ArraySetAsSeries(bb_middle, true);
        
        double close_price = iClose(Symbol(), AnalysisTimeframe, 0);
        double bbSignal = 0.0;
        
        if(close_price >= bb_upper[0])
        {
            bbSignal = analysis.is_crash_symbol ? -0.5 : 0.1;
        }
        else if(close_price <= bb_lower[0])
        {
            bbSignal = analysis.is_boom_symbol ? 0.5 : -0.1;
        }
        
        double weight = EnableSelfLearning ? learningWeights[3] : 1.0;
        signalSum += bbSignal * weight;
        weightSum += weight;
        signalCount++;
    }
    
    //--- Alligator анализ
    double alligator_jaw[], alligator_teeth[], alligator_lips[];
    if(CopyBuffer(alligator_handle, 0, 0, 5, alligator_jaw) > 0 &&
       CopyBuffer(alligator_handle, 1, 0, 5, alligator_teeth) > 0 &&
       CopyBuffer(alligator_handle, 2, 0, 5, alligator_lips) > 0)
    {
        ArraySetAsSeries(alligator_jaw, true);
        ArraySetAsSeries(alligator_teeth, true);
        ArraySetAsSeries(alligator_lips, true);
        
        double alligatorSignal = 0.0;
        if(alligator_lips[0] > alligator_teeth[0] && alligator_teeth[0] > alligator_jaw[0])
        {
            alligatorSignal = analysis.is_boom_symbol ? 0.4 : -0.4;
        }
        else if(alligator_lips[0] < alligator_teeth[0] && alligator_teeth[0] < alligator_jaw[0])
        {
            alligatorSignal = analysis.is_crash_symbol ? -0.4 : 0.4;
        }
        
        double weight = EnableSelfLearning ? learningWeights[4] : 1.0;
        signalSum += alligatorSignal * weight;
        weightSum += weight;
        signalCount++;
    }
    
    //--- Awesome Oscillator анализ
    double ao[];
    if(CopyBuffer(ao_handle, 0, 0, 5, ao) > 0)
    {
        ArraySetAsSeries(ao, true);
        
        double aoSignal = 0.0;
        if(ao[0] > ao[1] && ao[1] < ao[2]) // Блюдце
        {
            aoSignal = analysis.is_boom_symbol ? 0.3 : -0.3;
        }
        else if(ao[0] < ao[1] && ao[1] > ao[2]) // Обратное блюдце
        {
            aoSignal = analysis.is_crash_symbol ? -0.3 : 0.3;
        }
        
        double weight = EnableSelfLearning ? learningWeights[5] : 1.0;
        signalSum += aoSignal * weight;
        weightSum += weight;
        signalCount++;
    }
    
    //--- Фрактальный анализ
    double fractals_up[], fractals_down[];
    if(CopyBuffer(fractals_handle, 0, 0, 10, fractals_up) > 0 &&
       CopyBuffer(fractals_handle, 1, 0, 10, fractals_down) > 0)
    {
        ArraySetAsSeries(fractals_up, true);
        ArraySetAsSeries(fractals_down, true);
        
        double fractalSignal = 0.0;
        
        // Поиск последних фракталов
        for(int i = 0; i < 5; i++)
        {
            if(fractals_up[i] != EMPTY_VALUE && fractals_up[i] > 0)
            {
                fractalSignal += analysis.is_crash_symbol ? -0.2 : 0.2;
                break;
            }
            if(fractals_down[i] != EMPTY_VALUE && fractals_down[i] > 0)
            {
                fractalSignal += analysis.is_boom_symbol ? 0.2 : -0.2;
                break;
            }
        }
        
        double weight = EnableSelfLearning ? learningWeights[6] : 1.0;
        signalSum += fractalSignal * weight;
        weightSum += weight;
        signalCount++;
    }
    
    //--- Анализ волатильности через ATR
    if(analysis.volatility > 0)
    {
        double avgATR = GetAverageATR(20);
        double volatilitySignal = 0.0;
        
        if(analysis.volatility > avgATR * 1.5) // Высокая волатильность
        {
            volatilitySignal = analysis.is_crash_symbol ? -0.3 : 0.3;
        }
        else if(analysis.volatility < avgATR * 0.5) // Низкая волатильность
        {
            volatilitySignal = 0.1; // Ожидание движения
        }
        
        double weight = EnableSelfLearning ? learningWeights[7] : 1.0;
        signalSum += volatilitySignal * weight;
        weightSum += weight;
        signalCount++;
    }
    
    //--- Расчет итогового сигнала
    if(signalCount > 0 && weightSum > 0)
    {
        signal.strength = signalSum / weightSum;
        signal.confidence = MathMin(1.0, (double)signalCount / 8.0); // Максимум 8 сигналов
        
        // Корректировка уверенности на основе согласованности сигналов
        if(MathAbs(signal.strength) > 0.5)
            signal.confidence *= 1.2;
        
        signal.confidence = MathMin(1.0, signal.confidence);
        
        // Описание сигнала
        if(signal.strength > 0.3)
            signal.description = analysis.is_boom_symbol ? "Сильный сигнал BOOM" : "Сильный восходящий сигнал";
        else if(signal.strength < -0.3)
            signal.description = analysis.is_crash_symbol ? "Сильный сигнал CRASH" : "Сильный нисходящий сигнал";
        else
            signal.description = "Слабый сигнал";
    }
    
    return signal;
}

//+------------------------------------------------------------------+
//| Поиск уровня поддержки                                            |
//+------------------------------------------------------------------+
double FindSupportLevel(int index, const double &low[], int lookback)
{
    double minLow = DBL_MAX;
    int startIndex = MathMax(0, index - lookback);
    
    for(int i = startIndex; i <= index; i++)
    {
        if(low[i] < minLow)
            minLow = low[i];
    }
    
    return minLow;
}

//+------------------------------------------------------------------+
//| Поиск уровня сопротивления                                        |
//+------------------------------------------------------------------+
double FindResistanceLevel(int index, const double &high[], int lookback)
{
    double maxHigh = -DBL_MAX;
    int startIndex = MathMax(0, index - lookback);
    
    for(int i = startIndex; i <= index; i++)
    {
        if(high[i] > maxHigh)
            maxHigh = high[i];
    }
    
    return maxHigh;
}

//+------------------------------------------------------------------+
//| Расчет уровня Фибоначчи                                          |
//+------------------------------------------------------------------+
double CalculateFibonacciLevel(int index, const double &high[], const double &low[], int lookback)
{
    double maxHigh = -DBL_MAX;
    double minLow = DBL_MAX;
    int startIndex = MathMax(0, index - lookback);
    
    for(int i = startIndex; i <= index; i++)
    {
        if(high[i] > maxHigh) maxHigh = high[i];
        if(low[i] < minLow) minLow = low[i];
    }
    
    double range = maxHigh - minLow;
    return minLow + range * 0.618; // Золотое сечение
}

//+------------------------------------------------------------------+
//| Получение среднего значения ATR                                   |
//+------------------------------------------------------------------+
double GetAverageATR(int period)
{
    double atr[];
    if(CopyBuffer(atr_handle, 0, 0, period, atr) <= 0)
        return 0.0;
    
    ArraySetAsSeries(atr, true);
    double sum = 0.0;
    
    for(int i = 0; i < period; i++)
    {
        sum += atr[i];
    }
    
    return sum / period;
}

//+------------------------------------------------------------------+
//| Проверка валидности символа Crash/Boom                           |
//+------------------------------------------------------------------+
bool IsValidCrashBoomSymbol(string symbol)
{
    string validSymbols[] = {
        "Crash 150 Index", "Crash 300 Index", "Crash 500 Index", 
        "Crash 600 Index", "Crash 900 Index", "Crash 1000 Index",
        "Boom 150 Index", "Boom 300 Index", "Boom 500 Index",
        "Boom 600 Index", "Boom 900 Index", "Boom 1000 Index"
    };
    
    for(int i = 0; i < ArraySize(validSymbols); i++)
    {
        if(StringFind(symbol, validSymbols[i]) >= 0)
            return true;
    }
    
    // Проверка альтернативных названий
    if(StringFind(symbol, "Crash") >= 0 || StringFind(symbol, "Boom") >= 0)
        return true;
    
    return false;
}

//+------------------------------------------------------------------+
//| Отправка оповещений                                               |
//+------------------------------------------------------------------+
void SendAlert(string title, string message, double confidence)
{
    datetime currentTime = TimeCurrent();
    
    // Предотвращение спама оповещений
    if(currentTime - lastAlertTime < 60) // Минимум 1 минута между оповещениями
        return;
    
    lastAlertTime = currentTime;
    
    string fullMessage = StringFormat("%s - %s (Уверенность: %.1f%%)", 
                                     title, message, confidence * 100);
    
    if(EnableAlerts)
    {
        Alert(fullMessage);
        if(AlertSoundFile != "")
            PlaySound(AlertSoundFile);
    }
    
    Print(fullMessage);
    
    if(EnablePushNotifications)
    {
        SendNotification(fullMessage);
    }
    
    if(EnableEmailAlerts)
    {
        SendMail("CrashBoom Detector Alert", fullMessage);
    }
}

//+------------------------------------------------------------------+
//| Рисование уровней Фибоначчи                                      |
//+------------------------------------------------------------------+
void DrawFibonacciLevels(int index, const double &high[], const double &low[])
{
    if(!ShowFibonacciLevels) return;
    
    string objName = "Fibo_" + IntegerToString(index);
    
    // Удаление старого объекта
    ObjectDelete(0, objName);
    
    // Поиск максимума и минимума за последние 50 баров
    double maxPrice = -DBL_MAX;
    double minPrice = DBL_MAX;
    datetime maxTime = 0, minTime = 0;
    
    int startBar = MathMax(0, index - 50);
    
    for(int i = startBar; i <= index; i++)
    {
        if(high[i] > maxPrice)
        {
            maxPrice = high[i];
            maxTime = iTime(Symbol(), AnalysisTimeframe, i);
        }
        if(low[i] < minPrice)
        {
            minPrice = low[i];
            minTime = iTime(Symbol(), AnalysisTimeframe, i);
        }
    }
    
    // Создание объекта Фибоначчи
    if(ObjectCreate(0, objName, OBJ_FIBO, 0, minTime, minPrice, maxTime, maxPrice))
    {
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clrGold);
        ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, objName, OBJPROP_BACK, true);
        
        // Установка уровней Фибоначчи
        ObjectSetDouble(0, objName, OBJPROP_LEVELVALUE, 0, 0.0);
        ObjectSetDouble(0, objName, OBJPROP_LEVELVALUE, 1, 0.236);
        ObjectSetDouble(0, objName, OBJPROP_LEVELVALUE, 2, 0.382);
        ObjectSetDouble(0, objName, OBJPROP_LEVELVALUE, 3, 0.5);
        ObjectSetDouble(0, objName, OBJPROP_LEVELVALUE, 4, 0.618);
        ObjectSetDouble(0, objName, OBJPROP_LEVELVALUE, 5, 0.786);
        ObjectSetDouble(0, objName, OBJPROP_LEVELVALUE, 6, 1.0);
    }
}

//+------------------------------------------------------------------+
//| Рисование линии тренда                                            |
//+------------------------------------------------------------------+
void DrawTrendLine(int index, const double &high[], const double &low[], bool isBullish)
{
    if(!ShowTrendLines) return;
    
    string objName = "TrendLine_" + IntegerToString(index);
    
    // Удаление старого объекта
    ObjectDelete(0, objName);
    
    // Поиск двух точек для линии тренда
    datetime time1 = iTime(Symbol(), AnalysisTimeframe, index - 20);
    datetime time2 = iTime(Symbol(), AnalysisTimeframe, index);
    
    double price1, price2;
    
    if(isBullish)
    {
        price1 = FindSupportLevel(index - 20, low, 10);
        price2 = FindSupportLevel(index, low, 5);
    }
    else
    {
        price1 = FindResistanceLevel(index - 20, high, 10);
        price2 = FindResistanceLevel(index, high, 5);
    }
    
    // Создание линии тренда
    if(ObjectCreate(0, objName, OBJ_TREND, 0, time1, price1, time2, price2))
    {
        ObjectSetInteger(0, objName, OBJPROP_COLOR, isBullish ? clrBlue : clrRed);
        ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, true);
    }
}

//+------------------------------------------------------------------+
//| Очистка графических объектов                                      |
//+------------------------------------------------------------------+
void CleanupGraphicalObjects()
{
    int totalObjects = ObjectsTotal(0);
    
    for(int i = totalObjects - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i);
        
        if(StringFind(objName, "Fibo_") >= 0 || 
           StringFind(objName, "TrendLine_") >= 0 ||
           StringFind(objName, "Support_") >= 0 ||
           StringFind(objName, "Resistance_") >= 0)
        {
            ObjectDelete(0, objName);
        }
    }
}

//+------------------------------------------------------------------+
//| Обновление системы самообучения                                   |
//+------------------------------------------------------------------+
void UpdateLearningSystem(int index, TechnicalSignal &signal, const double &close[])
{
    if(!EnableSelfLearning || ArraySize(learningWeights) == 0)
        return;
    
    // Проверка результата предыдущего прогноза
    if(index >= 5)
    {
        double previousClose = close[index - 5];
        double currentClose = close[index];
        double priceChange = (currentClose - previousClose) / previousClose;
        
        bool wasCorrectPrediction = false;
        
        // Определение правильности прогноза
        if(signal.strength > 0.3 && priceChange > 0.001) // Прогноз роста был верным
            wasCorrectPrediction = true;
        else if(signal.strength < -0.3 && priceChange < -0.001) // Прогноз падения был верным
            wasCorrectPrediction = true;
        
        totalPredictions++;
        if(wasCorrectPrediction)
            correctPredictions++;
        
        // Обновление весов на основе результата
        for(int i = 0; i < ArraySize(learningWeights); i++)
        {
            if(wasCorrectPrediction)
            {
                learningWeights[i] += LearningRate;
            }
            else
            {
                learningWeights[i] -= LearningRate * 0.5;
            }
            
            // Ограничение весов
            if(learningWeights[i] < 0.1) learningWeights[i] = 0.1;
            if(learningWeights[i] > 2.0) learningWeights[i] = 2.0;
        }
        
        // Вывод статистики обучения каждые 100 прогнозов
        if(totalPredictions % 100 == 0)
        {
            double accuracy = (double)correctPredictions / totalPredictions * 100.0;
            Print(StringFormat("Статистика самообучения: %d прогнозов, точность: %.1f%%", 
                              totalPredictions, accuracy));
        }
    }
}

//+------------------------------------------------------------------+
//| Функция для отображения информационной панели                     |
//+------------------------------------------------------------------+
void ShowInfoPanel()
{
    string panelName = "CrashBoomPanel";
    
    // Создание фона панели
    if(ObjectFind(0, panelName) < 0)
    {
        ObjectCreate(0, panelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, panelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, panelName, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, panelName, OBJPROP_YDISTANCE, 30);
        ObjectSetInteger(0, panelName, OBJPROP_XSIZE, 250);
        ObjectSetInteger(0, panelName, OBJPROP_YSIZE, 120);
        ObjectSetInteger(0, panelName, OBJPROP_BGCOLOR, clrBlack);
        ObjectSetInteger(0, panelName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, panelName, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, panelName, OBJPROP_WIDTH, 1);
    }
    
    // Получение текущих данных
    double currentRSI = 0, currentATR = 0;
    string trendDirection = "Неопределен";
    
    double rsi[];
    if(CopyBuffer(rsi_handle, 0, 0, 1, rsi) > 0)
        currentRSI = rsi[0];
    
    double atr[];
    if(CopyBuffer(atr_handle, 0, 0, 1, atr) > 0)
        currentATR = atr[0];
    
    // Определение направления тренда
    double ma1[], ma2[];
    if(CopyBuffer(ma1_handle, 0, 0, 1, ma1) > 0 && CopyBuffer(ma2_handle, 0, 0, 1, ma2) > 0)
    {
        if(ma1[0] > ma2[0])
            trendDirection = "Восходящий";
        else
            trendDirection = "Нисходящий";
    }
    
    // Создание текстовых меток
    string infoText = StringFormat("Crash/Boom Detector\nТренд: %s\nRSI: %.1f\nATR: %.5f\nТочность: %.1f%%",
                                  trendDirection, currentRSI, currentATR,
                                  totalPredictions > 0 ? (double)correctPredictions / totalPredictions * 100.0 : 0.0);
    
    string labelName = panelName + "_Text";
    if(ObjectFind(0, labelName) < 0)
    {
        ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 15);
        ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, 35);
        ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
        ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
    }
    
    ObjectSetString(0, labelName, OBJPROP_TEXT, infoText);
}

//+------------------------------------------------------------------+
//| Обработчик событий                                                |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(id == CHARTEVENT_CHART_CHANGE)
    {
        ShowInfoPanel();
    }
}

//+------------------------------------------------------------------+