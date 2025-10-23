//+------------------------------------------------------------------+
//|                                    CrashBoom_ImpulseDetector.mq5 |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "2.00"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   4

// Подключение дополнительных модулей
#include "CrashBoom_AdvancedAnalysis.mqh"
#include "CrashBoom_Utilities.mqh"

//--- Параметры индикатора
#property indicator_label1  "Boom Signal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

#property indicator_label2  "Crash Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  3

//+------------------------------------------------------------------+
//| Входные параметры                                                |
//+------------------------------------------------------------------+
input group "=== Основные настройки ==="
input int      SpikeDetectionDepth = 20;           // Глубина анализа фракталов/ZigZag
input double   SpikePredictionSensitivity = 0.7;   // Чувствительность определения импульса
input ENUM_TIMEFRAMES Timeframe = PERIOD_CURRENT;  // Таймфрейм анализа
input bool     EnableAlerts = true;                // Включить звуковые сигналы

input group "=== Скользящие средние ==="
input int      MovingAveragePeriod1 = 50;          // Период EMA 1
input int      MovingAveragePeriod2 = 100;         // Период EMA 2
input int      MovingAveragePeriod3 = 200;         // Период EMA 3

input group "=== Осцилляторы ==="
input int      RSI_Period = 14;                    // Период RSI
input int      MACD_Fast = 12;                     // Быстрая линия MACD
input int      MACD_Slow = 26;                     // Медленная линия MACD
input int      MACD_Signal = 9;                    // Сигнальная линия MACD
input int      Stochastic_K = 5;                   // Период %K Stochastic
input int      Stochastic_D = 3;                   // Период %D Stochastic
input int      Stochastic_Slowing = 3;             // Замедление Stochastic

input group "=== Волатильность ==="
input int      ATR_Period = 14;                    // Период ATR
input int      BB_Period = 20;                     // Период Bollinger Bands
input double   BB_Deviation = 2.0;                 // Отклонение Bollinger Bands

input group "=== Визуализация ==="
input int      ArrowSize = 3;                      // Размер стрелки
input int      ArrowDistance = 5;                  // Смещение стрелки от свечи
input bool     ShowFibonacciLevels = true;         // Показывать Фибо-уровни
input bool     ShowSupportResistance = true;       // Показывать уровни поддержки/сопротивления
input bool     ShowTrendLines = true;              // Показывать трендовые линии

input group "=== Самообучение ==="
input bool     EnableSelfLearning = true;          // Включить самообучение
input int      LearningPeriod = 100;               // Период обучения
input double   LearningRate = 0.1;                 // Скорость обучения

//+------------------------------------------------------------------+
//| Буферы индикатора                                                |
//+------------------------------------------------------------------+
double BoomSignalBuffer[];
double CrashSignalBuffer[];
double TrendBuffer[];
double ProbabilityBuffer[];
double AdvancedSignalBuffer[];
double MLPredictionBuffer[];

//--- Параметры индикатора
#property indicator_label3  "Advanced Signal"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrGreen
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

#property indicator_label4  "ML Prediction"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrOrange
#property indicator_style4  STYLE_DOT
#property indicator_width4  1

//+------------------------------------------------------------------+
//| Глобальные переменные                                            |
//+------------------------------------------------------------------+
int handle_ema1, handle_ema2, handle_ema3;
int handle_rsi, handle_macd, handle_stochastic;
int handle_atr, handle_bb, handle_zigzag;
int handle_obv, handle_mfi, handle_cci;
int handle_alligator, handle_awesome, handle_accelerator;

// Массивы для хранения данных индикаторов
double ema1[], ema2[], ema3[];
double rsi[], macd_main[], macd_signal[];
double stochastic_main[], stochastic_signal[];
double atr[], bb_upper[], bb_middle[], bb_lower[];
double zigzag[];
double obv[], mfi[], cci[];
double alligator_jaw[], alligator_teeth[], alligator_lips[];
double awesome[], accelerator[];

// Массивы для самообучения
double learning_weights[20];
double historical_accuracy[];
int learning_samples = 0;

// Экземпляры классов
CAdvancedAnalysis* advanced_analysis;
CChartObjects* chart_objects;
CNotifications* notifications;
CPerformanceStats* performance_stats;
CConfigManager* config_manager;

// Структуры для анализа
struct SupportResistanceLevel {
    double price;
    int strength;
    datetime time;
    bool is_support;
};

struct TrendLine {
    double start_price;
    double end_price;
    datetime start_time;
    datetime end_time;
    double slope;
    int strength;
};

struct FibonacciLevel {
    double level;
    double price;
    int type; // 0 - retracement, 1 - extension
};

// Массивы для хранения уровней
SupportResistanceLevel support_levels[50];
SupportResistanceLevel resistance_levels[50];
TrendLine trend_lines[20];
FibonacciLevel fib_levels[20];

int support_count = 0, resistance_count = 0;
int trend_count = 0, fib_count = 0;

//+------------------------------------------------------------------+
//| Инициализация индикатора                                         |
//+------------------------------------------------------------------+
int OnInit()
{
    // Настройка буферов
    SetIndexBuffer(0, BoomSignalBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, CrashSignalBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, TrendBuffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(3, ProbabilityBuffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(4, AdvancedSignalBuffer, INDICATOR_DATA);
    SetIndexBuffer(5, MLPredictionBuffer, INDICATOR_CALCULATIONS);
    
    // Настройка стрелок
    PlotIndexSetInteger(0, PLOT_ARROW, 233); // Стрелка вверх для Boom
    PlotIndexSetInteger(1, PLOT_ARROW, 234); // Стрелка вниз для Crash
    
    // Инициализация индикаторов
    if(!InitializeIndicators())
    {
        Print("Ошибка инициализации индикаторов");
        return INIT_FAILED;
    }
    
    // Инициализация самообучения
    if(EnableSelfLearning)
    {
        InitializeLearning();
    }
    
    // Инициализация классов
    advanced_analysis = new CAdvancedAnalysis();
    chart_objects = new CChartObjects("CrashBoom_");
    notifications = new CNotifications(EnableAlerts, false, false);
    performance_stats = new CPerformanceStats();
    config_manager = new CConfigManager();
    
    // Загрузка конфигурации
    config_manager.LoadConfig();
    
    // Инициализация массивов
    ArrayInitialize(BoomSignalBuffer, EMPTY_VALUE);
    ArrayInitialize(CrashSignalBuffer, EMPTY_VALUE);
    ArrayInitialize(TrendBuffer, 0);
    ArrayInitialize(ProbabilityBuffer, 0);
    ArrayInitialize(AdvancedSignalBuffer, EMPTY_VALUE);
    ArrayInitialize(MLPredictionBuffer, 0);
    
    Print("Индикатор CrashBoom_ImpulseDetector успешно инициализирован");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Инициализация индикаторов                                        |
//+------------------------------------------------------------------+
bool InitializeIndicators()
{
    // Скользящие средние
    handle_ema1 = iMA(_Symbol, Timeframe, MovingAveragePeriod1, 0, MODE_EMA, PRICE_CLOSE);
    handle_ema2 = iMA(_Symbol, Timeframe, MovingAveragePeriod2, 0, MODE_EMA, PRICE_CLOSE);
    handle_ema3 = iMA(_Symbol, Timeframe, MovingAveragePeriod3, 0, MODE_EMA, PRICE_CLOSE);
    
    // Осцилляторы
    handle_rsi = iRSI(_Symbol, Timeframe, RSI_Period, PRICE_CLOSE);
    handle_macd = iMACD(_Symbol, Timeframe, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
    handle_stochastic = iStochastic(_Symbol, Timeframe, Stochastic_K, Stochastic_D, Stochastic_Slowing, MODE_SMA, STO_LOWHIGH);
    
    // Волатильность
    handle_atr = iATR(_Symbol, Timeframe, ATR_Period);
    handle_bb = iBands(_Symbol, Timeframe, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
    handle_zigzag = iCustom(_Symbol, Timeframe, "Examples\\ZigZag", 12, 5, 3);
    
    // Объемы
    handle_obv = iOBV(_Symbol, Timeframe, PRICE_CLOSE);
    handle_mfi = iMFI(_Symbol, Timeframe, RSI_Period, PRICE_TYPICAL);
    handle_cci = iCCI(_Symbol, Timeframe, RSI_Period, PRICE_TYPICAL);
    
    // Bill Williams
    handle_alligator = iAlligator(_Symbol, Timeframe, 13, 8, 8, 5, 5, 3, MODE_SMMA, PRICE_MEDIAN);
    handle_awesome = iAO(_Symbol, Timeframe);
    handle_accelerator = iAC(_Symbol, Timeframe);
    
    // Проверка создания индикаторов
    if(handle_ema1 == INVALID_HANDLE || handle_ema2 == INVALID_HANDLE || handle_ema3 == INVALID_HANDLE ||
       handle_rsi == INVALID_HANDLE || handle_macd == INVALID_HANDLE || handle_stochastic == INVALID_HANDLE ||
       handle_atr == INVALID_HANDLE || handle_bb == INVALID_HANDLE || handle_zigzag == INVALID_HANDLE)
    {
        Print("Ошибка создания индикаторов");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Инициализация самообучения                                       |
//+------------------------------------------------------------------+
void InitializeLearning()
{
    // Инициализация весов для самообучения
    for(int i = 0; i < 20; i++)
    {
        learning_weights[i] = 0.1 + (i * 0.05); // Начальные веса
    }
    
    ArrayResize(historical_accuracy, LearningPeriod);
    ArrayInitialize(historical_accuracy, 0);
    learning_samples = 0;
}

//+------------------------------------------------------------------+
//| Основная функция расчета                                         |
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
    if(rates_total < 100) return 0;
    
    int start = MathMax(prev_calculated - 1, 0);
    if(start < 0) start = 0;
    
    // Получение данных индикаторов
    if(!GetIndicatorData(rates_total))
    {
        return prev_calculated;
    }
    
    // Основной цикл анализа
    for(int i = start; i < rates_total - 1; i++)
    {
        // Обновление уровней поддержки/сопротивления
        if(ShowSupportResistance)
        {
            UpdateSupportResistanceLevels(i, high, low, close);
        }
        
        // Обновление трендовых линий
        if(ShowTrendLines)
        {
            UpdateTrendLines(i, high, low, close);
        }
        
        // Обновление уровней Фибоначчи
        if(ShowFibonacciLevels)
        {
            UpdateFibonacciLevels(i, high, low, close);
        }
        
        // Комплексный анализ
        double boom_probability = 0;
        double crash_probability = 0;
        
        // Базовый анализ
        int trend_direction = AnalyzeTrend(i);
        double oscillator_signal = AnalyzeOscillators(i);
        double volatility_signal = AnalyzeVolatility(i);
        double volume_signal = AnalyzeVolume(i);
        double level_signal = AnalyzeSupportResistance(i, close[i]);
        double divergence_signal = AnalyzeDivergence(i);
        
        // Расширенный анализ
        double candlestick_signal = 0;
        double chart_pattern_signal = 0;
        double harmonic_signal = 0;
        double elliott_signal = 0;
        double cycle_signal = 0;
        double correlation_signal = 0;
        double seasonality_signal = 0;
        double ml_prediction = 0;
        
        if(advanced_analysis != NULL)
        {
            // Инициализация данных для расширенного анализа
            if(i == start)
            {
                advanced_analysis.InitializeAnalysis(high, low, close, open, time, rates_total);
            }
            
            // Анализ свечных паттернов
            candlestick_signal = advanced_analysis.AnalyzeCandlestickPatterns(i);
            
            // Анализ графических паттернов
            chart_pattern_signal = advanced_analysis.AnalyzeChartPatterns(i);
            
            // Анализ гармонических паттернов
            harmonic_signal = advanced_analysis.AnalyzeHarmonicPatterns(i);
            
            // Анализ волн Эллиотта
            elliott_signal = advanced_analysis.AnalyzeElliottWaves(i);
            
            // Анализ циклов
            cycle_signal = advanced_analysis.AnalyzeCycles(i);
            
            // Анализ корреляций
            correlation_signal = advanced_analysis.AnalyzeCorrelations(i);
            
            // Анализ сезонности
            seasonality_signal = advanced_analysis.AnalyzeSeasonality(i);
            
            // Машинное обучение
            ml_prediction = advanced_analysis.PredictWithML(i);
            MLPredictionBuffer[i] = ml_prediction;
        }
        
        // Самообучение
        if(EnableSelfLearning && i > LearningPeriod)
        {
            UpdateLearningWeights(i, boom_probability, crash_probability);
        }
        
        // Расчет итоговой вероятности с учетом расширенного анализа
        boom_probability = CalculateBoomProbability(i, trend_direction, oscillator_signal, 
                                                   volatility_signal, volume_signal, level_signal, divergence_signal,
                                                   candlestick_signal, chart_pattern_signal, harmonic_signal,
                                                   elliott_signal, cycle_signal, correlation_signal, seasonality_signal, ml_prediction);
        crash_probability = CalculateCrashProbability(i, trend_direction, oscillator_signal, 
                                                     volatility_signal, volume_signal, level_signal, divergence_signal,
                                                     candlestick_signal, chart_pattern_signal, harmonic_signal,
                                                     elliott_signal, cycle_signal, correlation_signal, seasonality_signal, ml_prediction);
        
        // Сохранение вероятностей
        ProbabilityBuffer[i] = MathMax(boom_probability, crash_probability);
        
        // Определение сигналов
        if(boom_probability > SpikePredictionSensitivity)
        {
            BoomSignalBuffer[i] = low[i] - ArrowDistance * _Point;
            TrendBuffer[i] = 1; // Boom тренд
            
            // Расширенный сигнал
            if(boom_probability > SpikePredictionSensitivity + 0.2)
            {
                AdvancedSignalBuffer[i] = low[i] - (ArrowDistance + 2) * _Point;
            }
            
            // Создание графических объектов
            if(chart_objects != NULL && i == rates_total - 2)
            {
                chart_objects.CreateArrow("BoomSignal_" + IntegerToString(i), time[i], low[i] - ArrowDistance * _Point, 233, clrBlue);
                chart_objects.CreateText("BoomText_" + IntegerToString(i), "BOOM SPIKE SOON", time[i], low[i] - (ArrowDistance + 5) * _Point, clrBlue);
            }
            
            // Оповещение
            if(i == rates_total - 2) // Только для последней свечи
            {
                string message = notifications.FormatMessage(_Symbol, "BOOM SPIKE", boom_probability, close[i]);
                notifications.SendAlert("BOOM SPIKE DETECTED", message);
                
                // Запись в статистику
                if(performance_stats != NULL)
                {
                    performance_stats.AddRecord("BOOM", boom_probability, 1.0);
                }
            }
        }
        else if(crash_probability > SpikePredictionSensitivity)
        {
            CrashSignalBuffer[i] = high[i] + ArrowDistance * _Point;
            TrendBuffer[i] = -1; // Crash тренд
            
            // Расширенный сигнал
            if(crash_probability > SpikePredictionSensitivity + 0.2)
            {
                AdvancedSignalBuffer[i] = high[i] + (ArrowDistance + 2) * _Point;
            }
            
            // Создание графических объектов
            if(chart_objects != NULL && i == rates_total - 2)
            {
                chart_objects.CreateArrow("CrashSignal_" + IntegerToString(i), time[i], high[i] + ArrowDistance * _Point, 234, clrRed);
                chart_objects.CreateText("CrashText_" + IntegerToString(i), "CRASH SPIKE SOON", time[i], high[i] + (ArrowDistance + 5) * _Point, clrRed);
            }
            
            // Оповещение
            if(i == rates_total - 2) // Только для последней свечи
            {
                string message = notifications.FormatMessage(_Symbol, "CRASH SPIKE", crash_probability, close[i]);
                notifications.SendAlert("CRASH SPIKE DETECTED", message);
                
                // Запись в статистику
                if(performance_stats != NULL)
                {
                    performance_stats.AddRecord("CRASH", crash_probability, -1.0);
                }
            }
        }
        else
        {
            TrendBuffer[i] = 0; // Нейтральный тренд
        }
    }
    
    return rates_total;
}

//+------------------------------------------------------------------+
//| Получение данных индикаторов                                     |
//+------------------------------------------------------------------+
bool GetIndicatorData(int rates_total)
{
    // Копирование данных индикаторов
    if(CopyBuffer(handle_ema1, 0, 0, rates_total, ema1) <= 0) return false;
    if(CopyBuffer(handle_ema2, 0, 0, rates_total, ema2) <= 0) return false;
    if(CopyBuffer(handle_ema3, 0, 0, rates_total, ema3) <= 0) return false;
    
    if(CopyBuffer(handle_rsi, 0, 0, rates_total, rsi) <= 0) return false;
    if(CopyBuffer(handle_macd, 0, 0, rates_total, macd_main) <= 0) return false;
    if(CopyBuffer(handle_macd, 1, 0, rates_total, macd_signal) <= 0) return false;
    if(CopyBuffer(handle_stochastic, 0, 0, rates_total, stochastic_main) <= 0) return false;
    if(CopyBuffer(handle_stochastic, 1, 0, rates_total, stochastic_signal) <= 0) return false;
    
    if(CopyBuffer(handle_atr, 0, 0, rates_total, atr) <= 0) return false;
    if(CopyBuffer(handle_bb, 0, 0, rates_total, bb_upper) <= 0) return false;
    if(CopyBuffer(handle_bb, 1, 0, rates_total, bb_middle) <= 0) return false;
    if(CopyBuffer(handle_bb, 2, 0, rates_total, bb_lower) <= 0) return false;
    
    if(CopyBuffer(handle_obv, 0, 0, rates_total, obv) <= 0) return false;
    if(CopyBuffer(handle_mfi, 0, 0, rates_total, mfi) <= 0) return false;
    if(CopyBuffer(handle_cci, 0, 0, rates_total, cci) <= 0) return false;
    
    if(CopyBuffer(handle_alligator, 0, 0, rates_total, alligator_jaw) <= 0) return false;
    if(CopyBuffer(handle_alligator, 1, 0, rates_total, alligator_teeth) <= 0) return false;
    if(CopyBuffer(handle_alligator, 2, 0, rates_total, alligator_lips) <= 0) return false;
    if(CopyBuffer(handle_awesome, 0, 0, rates_total, awesome) <= 0) return false;
    if(CopyBuffer(handle_accelerator, 0, 0, rates_total, accelerator) <= 0) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Анализ тренда                                                    |
//+------------------------------------------------------------------+
int AnalyzeTrend(int index)
{
    if(index < 2) return 0;
    
    double trend_score = 0;
    
    // Анализ расположения EMA
    if(ema1[index] > ema2[index] && ema2[index] > ema3[index])
        trend_score += 0.3; // Восходящий тренд
    else if(ema1[index] < ema2[index] && ema2[index] < ema3[index])
        trend_score -= 0.3; // Нисходящий тренд
    
    // Анализ наклона EMA
    double ema1_slope = (ema1[index] - ema1[index-1]) / ema1[index-1];
    double ema2_slope = (ema2[index] - ema2[index-1]) / ema2[index-1];
    double ema3_slope = (ema3[index] - ema3[index-1]) / ema3[index-1];
    
    trend_score += (ema1_slope + ema2_slope + ema3_slope) * 10;
    
    // Анализ Alligator
    if(alligator_lips[index] > alligator_teeth[index] && alligator_teeth[index] > alligator_jaw[index])
        trend_score += 0.2;
    else if(alligator_lips[index] < alligator_teeth[index] && alligator_teeth[index] < alligator_jaw[index])
        trend_score -= 0.2;
    
    return (int)MathRound(trend_score);
}

//+------------------------------------------------------------------+
//| Анализ осцилляторов                                              |
//+------------------------------------------------------------------+
double AnalyzeOscillators(int index)
{
    if(index < 2) return 0;
    
    double signal = 0;
    
    // RSI анализ
    if(rsi[index] < 30 && rsi[index] > rsi[index-1])
        signal += 0.2; // Перепроданность + рост
    else if(rsi[index] > 70 && rsi[index] < rsi[index-1])
        signal -= 0.2; // Перекупленность + падение
    
    // MACD анализ
    if(macd_main[index] > macd_signal[index] && macd_main[index-1] <= macd_signal[index-1])
        signal += 0.2; // Золотой крест MACD
    else if(macd_main[index] < macd_signal[index] && macd_main[index-1] >= macd_signal[index-1])
        signal -= 0.2; // Медвежий крест MACD
    
    // Stochastic анализ
    if(stochastic_main[index] < 20 && stochastic_main[index] > stochastic_signal[index])
        signal += 0.15;
    else if(stochastic_main[index] > 80 && stochastic_main[index] < stochastic_signal[index])
        signal -= 0.15;
    
    // CCI анализ
    if(cci[index] < -100 && cci[index] > cci[index-1])
        signal += 0.1;
    else if(cci[index] > 100 && cci[index] < cci[index-1])
        signal -= 0.1;
    
    // MFI анализ
    if(mfi[index] < 20 && mfi[index] > mfi[index-1])
        signal += 0.1;
    else if(mfi[index] > 80 && mfi[index] < mfi[index-1])
        signal -= 0.1;
    
    return signal;
}

//+------------------------------------------------------------------+
//| Анализ волатильности                                             |
//+------------------------------------------------------------------+
double AnalyzeVolatility(int index)
{
    if(index < 2) return 0;
    
    double signal = 0;
    
    // ATR анализ
    double atr_ratio = atr[index] / atr[index-1];
    if(atr_ratio > 1.2) // Рост волатильности
        signal += 0.3;
    else if(atr_ratio < 0.8) // Снижение волатильности
        signal -= 0.1;
    
    // Bollinger Bands анализ
    double bb_position = (close[index] - bb_lower[index]) / (bb_upper[index] - bb_lower[index]);
    if(bb_position < 0.1) // У нижней границы
        signal += 0.2;
    else if(bb_position > 0.9) // У верхней границы
        signal -= 0.2;
    
    // Сжатие полос Боллинджера
    double bb_width = (bb_upper[index] - bb_lower[index]) / bb_middle[index];
    double bb_width_prev = (bb_upper[index-1] - bb_lower[index-1]) / bb_middle[index-1];
    if(bb_width < bb_width_prev * 0.8)
        signal += 0.2; // Сжатие - предвестник взрыва
    
    return signal;
}

//+------------------------------------------------------------------+
//| Анализ объемов                                                   |
//+------------------------------------------------------------------+
double AnalyzeVolume(int index)
{
    if(index < 2) return 0;
    
    double signal = 0;
    
    // OBV анализ
    if(obv[index] > obv[index-1] && obv[index-1] > obv[index-2])
        signal += 0.2; // Рост объема покупок
    else if(obv[index] < obv[index-1] && obv[index-1] < obv[index-2])
        signal -= 0.2; // Рост объема продаж
    
    // MFI анализ объемов
    if(mfi[index] > 50 && mfi[index] > mfi[index-1])
        signal += 0.1;
    else if(mfi[index] < 50 && mfi[index] < mfi[index-1])
        signal -= 0.1;
    
    return signal;
}

//+------------------------------------------------------------------+
//| Анализ уровней поддержки/сопротивления                           |
//+------------------------------------------------------------------+
double AnalyzeSupportResistance(int index, double price)
{
    double signal = 0;
    
    // Проверка близости к уровням поддержки
    for(int i = 0; i < support_count; i++)
    {
        double distance = MathAbs(price - support_levels[i].price) / price;
        if(distance < 0.01) // В пределах 1%
        {
            signal += 0.3 * support_levels[i].strength / 10.0;
        }
    }
    
    // Проверка близости к уровням сопротивления
    for(int i = 0; i < resistance_count; i++)
    {
        double distance = MathAbs(price - resistance_levels[i].price) / price;
        if(distance < 0.01) // В пределах 1%
        {
            signal -= 0.3 * resistance_levels[i].strength / 10.0;
        }
    }
    
    return signal;
}

//+------------------------------------------------------------------+
//| Анализ дивергенций                                               |
//+------------------------------------------------------------------+
double AnalyzeDivergence(int index)
{
    if(index < 10) return 0;
    
    double signal = 0;
    
    // Поиск дивергенций RSI
    double price_high = 0, price_low = 0;
    double rsi_high = 0, rsi_low = 0;
    
    // Поиск локальных экстремумов за последние 10 баров
    for(int i = index - 10; i < index; i++)
    {
        if(high[i] > price_high)
        {
            price_high = high[i];
            rsi_high = rsi[i];
        }
        if(low[i] < price_low)
        {
            price_low = low[i];
            rsi_low = rsi[i];
        }
    }
    
    // Проверка бычьей дивергенции
    if(close[index] < price_low && rsi[index] > rsi_low)
        signal += 0.4;
    
    // Проверка медвежьей дивергенции
    if(close[index] > price_high && rsi[index] < rsi_high)
        signal -= 0.4;
    
    return signal;
}

//+------------------------------------------------------------------+
//| Расчет вероятности Boom импульса                                 |
//+------------------------------------------------------------------+
double CalculateBoomProbability(int index, int trend_direction, double oscillator_signal, 
                               double volatility_signal, double volume_signal, 
                               double level_signal, double divergence_signal,
                               double candlestick_signal, double chart_pattern_signal, 
                               double harmonic_signal, double elliott_signal, 
                               double cycle_signal, double correlation_signal, 
                               double seasonality_signal, double ml_prediction)
{
    double probability = 0;
    
    // Базовые условия для Boom
    if(trend_direction > 0) probability += 0.15; // Восходящий тренд
    if(oscillator_signal > 0) probability += 0.15; // Положительные осцилляторы
    if(volatility_signal > 0) probability += 0.15; // Рост волатильности
    if(volume_signal > 0) probability += 0.1; // Рост объемов
    if(level_signal > 0) probability += 0.1; // Поддержка от уровней
    if(divergence_signal > 0) probability += 0.1; // Бычья дивергенция
    
    // Расширенный анализ
    if(candlestick_signal > 0) probability += 0.1; // Бычьи свечные паттерны
    if(chart_pattern_signal > 0) probability += 0.1; // Бычьи графические паттерны
    if(harmonic_signal > 0) probability += 0.1; // Гармонические паттерны
    if(elliott_signal > 0) probability += 0.1; // Волны Эллиотта
    if(cycle_signal > 0) probability += 0.05; // Циклический анализ
    if(correlation_signal > 0) probability += 0.05; // Корреляционный анализ
    if(seasonality_signal > 0) probability += 0.05; // Сезонный анализ
    if(ml_prediction > 0) probability += 0.1; // Машинное обучение
    
    // Применение весов самообучения
    if(EnableSelfLearning)
    {
        probability *= learning_weights[0];
        probability += learning_weights[1] * trend_direction;
        probability += learning_weights[2] * oscillator_signal;
        probability += learning_weights[3] * volatility_signal;
    }
    
    return MathMax(0, MathMin(1, probability));
}

//+------------------------------------------------------------------+
//| Расчет вероятности Crash импульса                                |
//+------------------------------------------------------------------+
double CalculateCrashProbability(int index, int trend_direction, double oscillator_signal, 
                                double volatility_signal, double volume_signal, 
                                double level_signal, double divergence_signal,
                                double candlestick_signal, double chart_pattern_signal, 
                                double harmonic_signal, double elliott_signal, 
                                double cycle_signal, double correlation_signal, 
                                double seasonality_signal, double ml_prediction)
{
    double probability = 0;
    
    // Базовые условия для Crash
    if(trend_direction < 0) probability += 0.15; // Нисходящий тренд
    if(oscillator_signal < 0) probability += 0.15; // Отрицательные осцилляторы
    if(volatility_signal > 0) probability += 0.15; // Рост волатильности
    if(volume_signal < 0) probability += 0.1; // Рост объемов продаж
    if(level_signal < 0) probability += 0.1; // Сопротивление от уровней
    if(divergence_signal < 0) probability += 0.1; // Медвежья дивергенция
    
    // Расширенный анализ
    if(candlestick_signal < 0) probability += 0.1; // Медвежьи свечные паттерны
    if(chart_pattern_signal < 0) probability += 0.1; // Медвежьи графические паттерны
    if(harmonic_signal < 0) probability += 0.1; // Гармонические паттерны
    if(elliott_signal < 0) probability += 0.1; // Волны Эллиотта
    if(cycle_signal < 0) probability += 0.05; // Циклический анализ
    if(correlation_signal < 0) probability += 0.05; // Корреляционный анализ
    if(seasonality_signal < 0) probability += 0.05; // Сезонный анализ
    if(ml_prediction < 0) probability += 0.1; // Машинное обучение
    
    // Применение весов самообучения
    if(EnableSelfLearning)
    {
        probability *= learning_weights[4];
        probability += learning_weights[5] * MathAbs(trend_direction);
        probability += learning_weights[6] * MathAbs(oscillator_signal);
        probability += learning_weights[7] * volatility_signal;
    }
    
    return MathMax(0, MathMin(1, probability));
}

//+------------------------------------------------------------------+
//| Обновление уровней поддержки/сопротивления                       |
//+------------------------------------------------------------------+
void UpdateSupportResistanceLevels(int index, const double &high[], const double &low[], const double &close[])
{
    // Поиск локальных максимумов и минимумов
    if(index < 5) return;
    
    // Поиск локального максимума
    bool is_local_max = true;
    for(int i = index - 2; i <= index + 2; i++)
    {
        if(i != index && high[i] >= high[index])
        {
            is_local_max = false;
            break;
        }
    }
    
    if(is_local_max && resistance_count < 50)
    {
        resistance_levels[resistance_count].price = high[index];
        resistance_levels[resistance_count].strength = CalculateLevelStrength(index, high, true);
        resistance_levels[resistance_count].time = TimeCurrent();
        resistance_levels[resistance_count].is_support = false;
        resistance_count++;
    }
    
    // Поиск локального минимума
    bool is_local_min = true;
    for(int i = index - 2; i <= index + 2; i++)
    {
        if(i != index && low[i] <= low[index])
        {
            is_local_min = false;
            break;
        }
    }
    
    if(is_local_min && support_count < 50)
    {
        support_levels[support_count].price = low[index];
        support_levels[support_count].strength = CalculateLevelStrength(index, low, false);
        support_levels[support_count].time = TimeCurrent();
        support_levels[support_count].is_support = true;
        support_count++;
    }
}

//+------------------------------------------------------------------+
//| Расчет силы уровня                                               |
//+------------------------------------------------------------------+
int CalculateLevelStrength(int index, const double &price_array[], bool is_resistance)
{
    int strength = 1;
    
    // Подсчет касаний уровня
    for(int i = MathMax(0, index - 20); i < index; i++)
    {
        double distance = MathAbs(price_array[i] - price_array[index]) / price_array[index];
        if(distance < 0.005) // В пределах 0.5%
        {
            strength++;
        }
    }
    
    return MathMin(10, strength);
}

//+------------------------------------------------------------------+
//| Обновление трендовых линий                                       |
//+------------------------------------------------------------------+
void UpdateTrendLines(int index, const double &high[], const double &low[], const double &close[])
{
    // Упрощенная реализация - поиск основных трендовых линий
    if(index < 20) return;
    
    // Поиск восходящей трендовой линии
    double max_high = 0;
    int max_high_index = 0;
    for(int i = index - 20; i < index; i++)
    {
        if(high[i] > max_high)
        {
            max_high = high[i];
            max_high_index = i;
        }
    }
    
    // Поиск нисходящей трендовой линии
    double min_low = DBL_MAX;
    int min_low_index = 0;
    for(int i = index - 20; i < index; i++)
    {
        if(low[i] < min_low)
        {
            min_low = low[i];
            min_low_index = i;
        }
    }
    
    // Создание трендовых линий (упрощенная версия)
    if(trend_count < 20)
    {
        trend_lines[trend_count].start_price = min_low;
        trend_lines[trend_count].end_price = max_high;
        trend_lines[trend_count].start_time = TimeCurrent() - 20 * PeriodSeconds();
        trend_lines[trend_count].end_time = TimeCurrent();
        trend_lines[trend_count].slope = (max_high - min_low) / 20;
        trend_lines[trend_count].strength = 5;
        trend_count++;
    }
}

//+------------------------------------------------------------------+
//| Обновление уровней Фибоначчи                                     |
//+------------------------------------------------------------------+
void UpdateFibonacciLevels(int index, const double &high[], const double &low[], const double &close[])
{
    if(index < 20) return;
    
    // Поиск локального максимума и минимума за последние 20 баров
    double local_high = 0, local_low = DBL_MAX;
    for(int i = index - 20; i < index; i++)
    {
        if(high[i] > local_high) local_high = high[i];
        if(low[i] < local_low) local_low = low[i];
    }
    
    double range = local_high - local_low;
    
    // Расчет уровней Фибоначчи
    if(fib_count < 20)
    {
        fib_levels[fib_count].level = 0.236;
        fib_levels[fib_count].price = local_high - range * 0.236;
        fib_levels[fib_count].type = 0;
        fib_count++;
        
        if(fib_count < 20)
        {
            fib_levels[fib_count].level = 0.382;
            fib_levels[fib_count].price = local_high - range * 0.382;
            fib_levels[fib_count].type = 0;
            fib_count++;
        }
        
        if(fib_count < 20)
        {
            fib_levels[fib_count].level = 0.5;
            fib_levels[fib_count].price = local_high - range * 0.5;
            fib_levels[fib_count].type = 0;
            fib_count++;
        }
        
        if(fib_count < 20)
        {
            fib_levels[fib_count].level = 0.618;
            fib_levels[fib_count].price = local_high - range * 0.618;
            fib_levels[fib_count].type = 0;
            fib_count++;
        }
    }
}

//+------------------------------------------------------------------+
//| Обновление весов самообучения                                    |
//+------------------------------------------------------------------+
void UpdateLearningWeights(int index, double boom_probability, double crash_probability)
{
    if(learning_samples >= LearningPeriod) return;
    
    // Простая реализация самообучения на основе исторической точности
    double actual_boom = 0, actual_crash = 0;
    
    // Проверка фактического результата (упрощенная)
    if(index > 0)
    {
        double price_change = (close[index] - close[index-1]) / close[index-1];
        if(price_change > 0.01) actual_boom = 1; // Рост более 1%
        if(price_change < -0.01) actual_crash = 1; // Падение более 1%
    }
    
    // Обновление весов
    double error_boom = actual_boom - boom_probability;
    double error_crash = actual_crash - crash_probability;
    
    for(int i = 0; i < 8; i++)
    {
        learning_weights[i] += LearningRate * error_boom;
        learning_weights[i + 8] += LearningRate * error_crash;
    }
    
    // Нормализация весов
    for(int i = 0; i < 16; i++)
    {
        learning_weights[i] = MathMax(0.01, MathMin(1.0, learning_weights[i]));
    }
    
    learning_samples++;
}

//+------------------------------------------------------------------+
//| Отправка оповещений                                              |
//+------------------------------------------------------------------+
void SendAlert(string title, string message)
{
    if(!EnableAlerts) return;
    
    // Звуковое оповещение
    Alert(title + ": " + message);
    
    // Вывод в лог
    Print(TimeToString(TimeCurrent()) + " - " + title + ": " + message);
    
    // Визуальное оповещение
    MessageBox(message, title, MB_OK | MB_ICONINFORMATION);
}

//+------------------------------------------------------------------+
//| Деинициализация индикатора                                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Освобождение ресурсов индикаторов
    if(handle_ema1 != INVALID_HANDLE) IndicatorRelease(handle_ema1);
    if(handle_ema2 != INVALID_HANDLE) IndicatorRelease(handle_ema2);
    if(handle_ema3 != INVALID_HANDLE) IndicatorRelease(handle_ema3);
    if(handle_rsi != INVALID_HANDLE) IndicatorRelease(handle_rsi);
    if(handle_macd != INVALID_HANDLE) IndicatorRelease(handle_macd);
    if(handle_stochastic != INVALID_HANDLE) IndicatorRelease(handle_stochastic);
    if(handle_atr != INVALID_HANDLE) IndicatorRelease(handle_atr);
    if(handle_bb != INVALID_HANDLE) IndicatorRelease(handle_bb);
    if(handle_obv != INVALID_HANDLE) IndicatorRelease(handle_obv);
    if(handle_mfi != INVALID_HANDLE) IndicatorRelease(handle_mfi);
    if(handle_cci != INVALID_HANDLE) IndicatorRelease(handle_cci);
    if(handle_alligator != INVALID_HANDLE) IndicatorRelease(handle_alligator);
    if(handle_awesome != INVALID_HANDLE) IndicatorRelease(handle_awesome);
    if(handle_accelerator != INVALID_HANDLE) IndicatorRelease(handle_accelerator);
    
    // Освобождение памяти классов
    if(advanced_analysis != NULL) delete advanced_analysis;
    if(chart_objects != NULL) delete chart_objects;
    if(notifications != NULL) delete notifications;
    if(performance_stats != NULL) delete performance_stats;
    if(config_manager != NULL) delete config_manager;
    
    // Сохранение статистики
    if(performance_stats != NULL)
    {
        performance_stats.SaveToFile("CrashBoom_Performance_" + TimeToString(TimeCurrent(), TIME_DATE) + ".csv");
    }
    
    // Сохранение конфигурации
    if(config_manager != NULL)
    {
        config_manager.SaveConfig();
    }
    
    Print("Индикатор CrashBoom_ImpulseDetector деинициализирован");
}

//+------------------------------------------------------------------+
//| Обработка событий графика                                        |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    // Обработка событий графика (при необходимости)
}

//+------------------------------------------------------------------+