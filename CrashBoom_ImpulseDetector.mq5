//+------------------------------------------------------------------+
//|                                    CrashBoom_ImpulseDetector.mq5 |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

//--- Плоты индикатора
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

#property indicator_label3  "Boom Text"
#property indicator_type3   DRAW_TEXT
#property indicator_color3  clrBlue

#property indicator_label4  "Crash Text"
#property indicator_type4   DRAW_TEXT
#property indicator_color4  clrRed

//--- Входные параметры
input group "=== Основные настройки ==="
input int      SpikeDetectionDepth = 20;           // Глубина анализа фракталов/ZigZag
input double   SpikePredictionSensitivity = 0.7;   // Чувствительность определения импульса
input ENUM_TIMEFRAMES Timeframe = PERIOD_CURRENT;  // Таймфрейм анализа
input bool     EnableAlerts = true;                // Включить оповещения

input group "=== Скользящие средние ==="
input int      MovingAveragePeriod1 = 50;          // Период EMA 1
input int      MovingAveragePeriod2 = 100;         // Период EMA 2
input int      MovingAveragePeriod3 = 200;         // Период EMA 3

input group "=== Осцилляторы ==="
input int      RSI_Period = 14;                    // Период RSI
input int      MACD_Fast = 12;                     // Быстрый период MACD
input int      MACD_Slow = 26;                     // Медленный период MACD
input int      MACD_Signal = 9;                    // Сигнальный период MACD
input int      Stochastic_K = 5;                   // Период %K Stochastic
input int      Stochastic_D = 3;                   // Период %D Stochastic
input int      Stochastic_Slowing = 3;             // Замедление Stochastic

input group "=== Волатильность ==="
input int      ATR_Period = 14;                    // Период ATR
input int      Bollinger_Period = 20;              // Период Bollinger Bands
input double   Bollinger_Deviation = 2.0;          // Отклонение Bollinger Bands

input group "=== Визуализация ==="
input int      ArrowSize = 3;                      // Размер стрелки
input int      ArrowDistance = 20;                 // Смещение стрелки от свечи
input bool     ShowFibonacciLevels = true;         // Показывать Фибо-уровни
input bool     ShowSupportResistance = true;       // Показывать уровни поддержки/сопротивления

input group "=== Самообучение ==="
input bool     EnableMachineLearning = true;       // Включить самообучение
input int      LearningPeriod = 100;               // Период обучения
input double   LearningRate = 0.1;                 // Скорость обучения

//--- Буферы индикатора
double BoomSignalBuffer[];
double CrashSignalBuffer[];
double BoomTextBuffer[];
double CrashTextBuffer[];

//--- Глобальные переменные
int rsi_handle, macd_handle, atr_handle, bb_handle;
int ema1_handle, ema2_handle, ema3_handle;
int stoch_handle, mfi_handle, obv_handle;
int zigzag_handle, fractal_handle;

//--- Массивы для хранения данных индикаторов
double rsi_values[], macd_main[], macd_signal[], atr_values[];
double bb_upper[], bb_middle[], bb_lower[];
double ema1_values[], ema2_values[], ema3_values[];
double stoch_main[], stoch_signal[], mfi_values[], obv_values[];
double zigzag_values[], fractal_values[];

//--- Структуры для анализа
struct MarketAnalysis {
    double trend_strength;
    double volatility;
    double momentum;
    double volume_analysis;
    double support_resistance;
    double fibonacci_levels;
    double pattern_recognition;
    double spike_probability;
    int signal_type; // 1 = Boom, -1 = Crash, 0 = No signal
    datetime signal_time;
};

struct LearningData {
    double features[20];
    int outcome;
    datetime timestamp;
};

//--- Массивы для самообучения
LearningData learning_dataset[];
int learning_count = 0;

//+------------------------------------------------------------------+
//| Инициализация индикатора                                         |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Настройка буферов
    SetIndexBuffer(0, BoomSignalBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, CrashSignalBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, BoomTextBuffer, INDICATOR_DATA);
    SetIndexBuffer(3, CrashTextBuffer, INDICATOR_DATA);
    
    //--- Настройка стрелок
    PlotIndexSetInteger(0, PLOT_ARROW, 233); // Стрелка вверх для Boom
    PlotIndexSetInteger(1, PLOT_ARROW, 234); // Стрелка вниз для Crash
    
    //--- Инициализация индикаторов
    if(!InitializeIndicators()) {
        Print("Ошибка инициализации индикаторов");
        return INIT_FAILED;
    }
    
    //--- Инициализация массивов
    ArraySetAsSeries(rsi_values, true);
    ArraySetAsSeries(macd_main, true);
    ArraySetAsSeries(macd_signal, true);
    ArraySetAsSeries(atr_values, true);
    ArraySetAsSeries(bb_upper, true);
    ArraySetAsSeries(bb_middle, true);
    ArraySetAsSeries(bb_lower, true);
    ArraySetAsSeries(ema1_values, true);
    ArraySetAsSeries(ema2_values, true);
    ArraySetAsSeries(ema3_values, true);
    ArraySetAsSeries(stoch_main, true);
    ArraySetAsSeries(stoch_signal, true);
    ArraySetAsSeries(mfi_values, true);
    ArraySetAsSeries(obv_values, true);
    ArraySetAsSeries(zigzag_values, true);
    ArraySetAsSeries(fractal_values, true);
    
    //--- Инициализация самообучения
    if(EnableMachineLearning) {
        ArrayResize(learning_dataset, LearningPeriod);
        learning_count = 0;
    }
    
    Print("Индикатор CrashBoom_ImpulseDetector успешно инициализирован");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Инициализация технических индикаторов                           |
//+------------------------------------------------------------------+
bool InitializeIndicators()
{
    //--- RSI
    rsi_handle = iRSI(_Symbol, Timeframe, RSI_Period, PRICE_CLOSE);
    if(rsi_handle == INVALID_HANDLE) return false;
    
    //--- MACD
    macd_handle = iMACD(_Symbol, Timeframe, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
    if(macd_handle == INVALID_HANDLE) return false;
    
    //--- ATR
    atr_handle = iATR(_Symbol, Timeframe, ATR_Period);
    if(atr_handle == INVALID_HANDLE) return false;
    
    //--- Bollinger Bands
    bb_handle = iBands(_Symbol, Timeframe, Bollinger_Period, 0, Bollinger_Deviation, PRICE_CLOSE);
    if(bb_handle == INVALID_HANDLE) return false;
    
    //--- Скользящие средние
    ema1_handle = iMA(_Symbol, Timeframe, MovingAveragePeriod1, 0, MODE_EMA, PRICE_CLOSE);
    ema2_handle = iMA(_Symbol, Timeframe, MovingAveragePeriod2, 0, MODE_EMA, PRICE_CLOSE);
    ema3_handle = iMA(_Symbol, Timeframe, MovingAveragePeriod3, 0, MODE_EMA, PRICE_CLOSE);
    if(ema1_handle == INVALID_HANDLE || ema2_handle == INVALID_HANDLE || ema3_handle == INVALID_HANDLE) return false;
    
    //--- Stochastic
    stoch_handle = iStochastic(_Symbol, Timeframe, Stochastic_K, Stochastic_D, Stochastic_Slowing, MODE_SMA, STO_LOWHIGH);
    if(stoch_handle == INVALID_HANDLE) return false;
    
    //--- MFI
    mfi_handle = iMFI(_Symbol, Timeframe, 14, PRICE_TYPICAL);
    if(mfi_handle == INVALID_HANDLE) return false;
    
    //--- OBV
    obv_handle = iOBV(_Symbol, Timeframe, PRICE_CLOSE);
    if(obv_handle == INVALID_HANDLE) return false;
    
    //--- ZigZag
    zigzag_handle = iCustom(_Symbol, Timeframe, "Examples\\ZigZag", 12, 5, 3);
    if(zigzag_handle == INVALID_HANDLE) return false;
    
    //--- Fractals
    fractal_handle = iFractals(_Symbol, Timeframe);
    if(fractal_handle == INVALID_HANDLE) return false;
    
    return true;
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
    
    //--- Получение данных индикаторов
    if(!GetIndicatorData(rates_total)) return 0;
    
    //--- Анализ каждого бара
    for(int i = start; i < rates_total - 1; i++) {
        //--- Очистка предыдущих сигналов
        BoomSignalBuffer[i] = EMPTY_VALUE;
        CrashSignalBuffer[i] = EMPTY_VALUE;
        BoomTextBuffer[i] = EMPTY_VALUE;
        CrashTextBuffer[i] = EMPTY_VALUE;
        
        //--- Проведение комплексного анализа
        MarketAnalysis analysis = PerformComprehensiveAnalysis(i, rates_total, time, open, high, low, close, tick_volume);
        
        //--- Определение сигнала
        if(analysis.signal_type != 0 && analysis.spike_probability > SpikePredictionSensitivity) {
            //--- Прогнозирование на 1-3 бара вперед
            int prediction_bars = MathMin(3, rates_total - i - 1);
            for(int j = 1; j <= prediction_bars; j++) {
                if(i + j < rates_total) {
                    if(analysis.signal_type == 1) { // Boom
                        BoomSignalBuffer[i + j] = low[i + j] - ArrowDistance * _Point;
                        BoomTextBuffer[i + j] = low[i + j] - (ArrowDistance + 10) * _Point;
                    } else if(analysis.signal_type == -1) { // Crash
                        CrashSignalBuffer[i + j] = high[i + j] + ArrowDistance * _Point;
                        CrashTextBuffer[i + j] = high[i + j] + (ArrowDistance + 10) * _Point;
                    }
                }
            }
            
            //--- Отправка оповещения
            if(EnableAlerts && i == rates_total - 2) {
                SendAlert(analysis);
            }
            
            //--- Обновление данных для самообучения
            if(EnableMachineLearning) {
                UpdateLearningData(analysis, i);
            }
        }
    }
    
    return rates_total;
}

//+------------------------------------------------------------------+
//| Получение данных индикаторов                                     |
//+------------------------------------------------------------------+
bool GetIndicatorData(int rates_total)
{
    //--- RSI
    if(CopyBuffer(rsi_handle, 0, 0, rates_total, rsi_values) <= 0) return false;
    
    //--- MACD
    if(CopyBuffer(macd_handle, 0, 0, rates_total, macd_main) <= 0) return false;
    if(CopyBuffer(macd_handle, 1, 0, rates_total, macd_signal) <= 0) return false;
    
    //--- ATR
    if(CopyBuffer(atr_handle, 0, 0, rates_total, atr_values) <= 0) return false;
    
    //--- Bollinger Bands
    if(CopyBuffer(bb_handle, 0, 0, rates_total, bb_upper) <= 0) return false;
    if(CopyBuffer(bb_handle, 1, 0, rates_total, bb_middle) <= 0) return false;
    if(CopyBuffer(bb_handle, 2, 0, rates_total, bb_lower) <= 0) return false;
    
    //--- EMA
    if(CopyBuffer(ema1_handle, 0, 0, rates_total, ema1_values) <= 0) return false;
    if(CopyBuffer(ema2_handle, 0, 0, rates_total, ema2_values) <= 0) return false;
    if(CopyBuffer(ema3_handle, 0, 0, rates_total, ema3_values) <= 0) return false;
    
    //--- Stochastic
    if(CopyBuffer(stoch_handle, 0, 0, rates_total, stoch_main) <= 0) return false;
    if(CopyBuffer(stoch_handle, 1, 0, rates_total, stoch_signal) <= 0) return false;
    
    //--- MFI
    if(CopyBuffer(mfi_handle, 0, 0, rates_total, mfi_values) <= 0) return false;
    
    //--- OBV
    if(CopyBuffer(obv_handle, 0, 0, rates_total, obv_values) <= 0) return false;
    
    //--- ZigZag
    if(CopyBuffer(zigzag_handle, 0, 0, rates_total, zigzag_values) <= 0) return false;
    
    //--- Fractals
    if(CopyBuffer(fractal_handle, 0, 0, rates_total, fractal_values) <= 0) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Комплексный анализ рынка                                         |
//+------------------------------------------------------------------+
MarketAnalysis PerformComprehensiveAnalysis(int bar, int rates_total, 
                                          const datetime &time[], const double &open[], 
                                          const double &high[], const double &low[], 
                                          const double &close[], const long &tick_volume[])
{
    MarketAnalysis analysis;
    ZeroMemory(analysis);
    
    if(bar < 50) return analysis; // Недостаточно данных для анализа
    
    //--- 1. Анализ тренда
    analysis.trend_strength = AnalyzeTrend(bar);
    
    //--- 2. Анализ волатильности
    analysis.volatility = AnalyzeVolatility(bar);
    
    //--- 3. Анализ моментума
    analysis.momentum = AnalyzeMomentum(bar);
    
    //--- 4. Анализ объемов
    analysis.volume_analysis = AnalyzeVolume(bar, tick_volume);
    
    //--- 5. Анализ поддержки/сопротивления
    analysis.support_resistance = AnalyzeSupportResistance(bar, high, low, close);
    
    //--- 6. Анализ Фибоначчи
    analysis.fibonacci_levels = AnalyzeFibonacci(bar, high, low, close);
    
    //--- 7. Распознавание паттернов
    analysis.pattern_recognition = AnalyzePatterns(bar, open, high, low, close);
    
    //--- 8. Машинное обучение (если включено)
    if(EnableMachineLearning) {
        analysis.spike_probability = PredictWithML(bar);
    } else {
        //--- Классический анализ
        analysis.spike_probability = CalculateClassicProbability(analysis);
    }
    
    //--- 9. Определение типа сигнала
    analysis.signal_type = DetermineSignalType(analysis, bar, close);
    analysis.signal_time = time[bar];
    
    return analysis;
}

//+------------------------------------------------------------------+
//| Анализ тренда                                                    |
//+------------------------------------------------------------------+
double AnalyzeTrend(int bar)
{
    if(bar < 3) return 0;
    
    double trend_score = 0;
    
    //--- Анализ EMA
    if(ema1_values[bar] > ema2_values[bar] && ema2_values[bar] > ema3_values[bar]) {
        trend_score += 0.3; // Восходящий тренд
    } else if(ema1_values[bar] < ema2_values[bar] && ema2_values[bar] < ema3_values[bar]) {
        trend_score -= 0.3; // Нисходящий тренд
    }
    
    //--- Анализ MACD
    if(macd_main[bar] > macd_signal[bar] && macd_main[bar-1] <= macd_signal[bar-1]) {
        trend_score += 0.2; // Пересечение MACD вверх
    } else if(macd_main[bar] < macd_signal[bar] && macd_main[bar-1] >= macd_signal[bar-1]) {
        trend_score -= 0.2; // Пересечение MACD вниз
    }
    
    //--- Анализ RSI
    if(rsi_values[bar] > 50 && rsi_values[bar] > rsi_values[bar-1]) {
        trend_score += 0.1;
    } else if(rsi_values[bar] < 50 && rsi_values[bar] < rsi_values[bar-1]) {
        trend_score -= 0.1;
    }
    
    return MathMax(-1, MathMin(1, trend_score));
}

//+------------------------------------------------------------------+
//| Анализ волатильности                                             |
//+------------------------------------------------------------------+
double AnalyzeVolatility(int bar)
{
    if(bar < 10) return 0;
    
    double volatility_score = 0;
    
    //--- ATR анализ
    double atr_current = atr_values[bar];
    double atr_avg = 0;
    for(int i = 0; i < 10; i++) {
        atr_avg += atr_values[bar - i];
    }
    atr_avg /= 10;
    
    if(atr_current > atr_avg * 1.2) {
        volatility_score += 0.5; // Высокая волатильность
    } else if(atr_current < atr_avg * 0.8) {
        volatility_score -= 0.3; // Низкая волатильность
    }
    
    //--- Bollinger Bands анализ
    double bb_width = (bb_upper[bar] - bb_lower[bar]) / bb_middle[bar];
    if(bb_width > 0.02) { // Широкие полосы
        volatility_score += 0.3;
    } else if(bb_width < 0.01) { // Узкие полосы
        volatility_score -= 0.2;
    }
    
    return MathMax(-1, MathMin(1, volatility_score));
}

//+------------------------------------------------------------------+
//| Анализ моментума                                                 |
//+------------------------------------------------------------------+
double AnalyzeMomentum(int bar)
{
    if(bar < 5) return 0;
    
    double momentum_score = 0;
    
    //--- RSI анализ
    if(rsi_values[bar] > 70) {
        momentum_score += 0.3; // Перекупленность
    } else if(rsi_values[bar] < 30) {
        momentum_score -= 0.3; // Перепроданность
    }
    
    //--- Stochastic анализ
    if(stoch_main[bar] > 80 && stoch_signal[bar] > 80) {
        momentum_score += 0.2;
    } else if(stoch_main[bar] < 20 && stoch_signal[bar] < 20) {
        momentum_score -= 0.2;
    }
    
    //--- MACD анализ
    if(macd_main[bar] > 0 && macd_main[bar] > macd_main[bar-1]) {
        momentum_score += 0.2;
    } else if(macd_main[bar] < 0 && macd_main[bar] < macd_main[bar-1]) {
        momentum_score -= 0.2;
    }
    
    return MathMax(-1, MathMin(1, momentum_score));
}

//+------------------------------------------------------------------+
//| Анализ объемов                                                   |
//+------------------------------------------------------------------+
double AnalyzeVolume(int bar, const long &tick_volume[])
{
    if(bar < 10) return 0;
    
    double volume_score = 0;
    
    //--- Анализ текущего объема относительно среднего
    long current_volume = tick_volume[bar];
    long avg_volume = 0;
    for(int i = 1; i <= 10; i++) {
        avg_volume += tick_volume[bar - i];
    }
    avg_volume /= 10;
    
    if(current_volume > avg_volume * 1.5) {
        volume_score += 0.4; // Высокий объем
    } else if(current_volume < avg_volume * 0.5) {
        volume_score -= 0.2; // Низкий объем
    }
    
    //--- MFI анализ
    if(mfi_values[bar] > 80) {
        volume_score += 0.3;
    } else if(mfi_values[bar] < 20) {
        volume_score -= 0.3;
    }
    
    return MathMax(-1, MathMin(1, volume_score));
}

//+------------------------------------------------------------------+
//| Анализ поддержки/сопротивления                                   |
//+------------------------------------------------------------------+
double AnalyzeSupportResistance(int bar, const double &high[], const double &low[], const double &close[])
{
    if(bar < 20) return 0;
    
    double sr_score = 0;
    
    //--- Поиск локальных максимумов и минимумов
    double current_high = high[bar];
    double current_low = low[bar];
    
    //--- Проверка на сопротивление
    int resistance_count = 0;
    for(int i = 1; i <= 20; i++) {
        if(MathAbs(high[bar - i] - current_high) < 10 * _Point) {
            resistance_count++;
        }
    }
    
    if(resistance_count >= 2) {
        sr_score += 0.4; // Сильное сопротивление
    }
    
    //--- Проверка на поддержку
    int support_count = 0;
    for(int i = 1; i <= 20; i++) {
        if(MathAbs(low[bar - i] - current_low) < 10 * _Point) {
            support_count++;
        }
    }
    
    if(support_count >= 2) {
        sr_score -= 0.4; // Сильная поддержка
    }
    
    return MathMax(-1, MathMin(1, sr_score));
}

//+------------------------------------------------------------------+
//| Анализ Фибоначчи                                                 |
//+------------------------------------------------------------------+
double AnalyzeFibonacci(int bar, const double &high[], const double &low[], const double &close[])
{
    if(bar < 20) return 0;
    
    double fib_score = 0;
    
    //--- Поиск локального максимума и минимума за последние 20 баров
    double max_price = high[bar];
    double min_price = low[bar];
    int max_bar = bar;
    int min_bar = bar;
    
    for(int i = 1; i <= 20; i++) {
        if(high[bar - i] > max_price) {
            max_price = high[bar - i];
            max_bar = bar - i;
        }
        if(low[bar - i] < min_price) {
            min_price = low[bar - i];
            min_bar = bar - i;
        }
    }
    
    //--- Расчет уровней Фибоначчи
    double range = max_price - min_price;
    double fib_236 = max_price - range * 0.236;
    double fib_382 = max_price - range * 0.382;
    double fib_500 = max_price - range * 0.500;
    double fib_618 = max_price - range * 0.618;
    double fib_764 = max_price - range * 0.764;
    
    double current_price = close[bar];
    
    //--- Проверка близости к уровням Фибоначчи
    if(MathAbs(current_price - fib_236) < 5 * _Point) {
        fib_score += 0.2;
    } else if(MathAbs(current_price - fib_382) < 5 * _Point) {
        fib_score += 0.3;
    } else if(MathAbs(current_price - fib_500) < 5 * _Point) {
        fib_score += 0.4;
    } else if(MathAbs(current_price - fib_618) < 5 * _Point) {
        fib_score += 0.3;
    } else if(MathAbs(current_price - fib_764) < 5 * _Point) {
        fib_score += 0.2;
    }
    
    return MathMax(-1, MathMin(1, fib_score));
}

//+------------------------------------------------------------------+
//| Анализ паттернов                                                 |
//+------------------------------------------------------------------+
double AnalyzePatterns(int bar, const double &open[], const double &high[], const double &low[], const double &close[])
{
    if(bar < 10) return 0;
    
    double pattern_score = 0;
    
    //--- Анализ свечных паттернов
    //--- Doji
    if(MathAbs(close[bar] - open[bar]) < (high[bar] - low[bar]) * 0.1) {
        pattern_score += 0.2; // Неопределенность
    }
    
    //--- Hammer
    if(close[bar] > open[bar] && 
       (close[bar] - low[bar]) > 2 * (high[bar] - close[bar]) &&
       (open[bar] - low[bar]) > 2 * (high[bar] - open[bar])) {
        pattern_score += 0.3; // Бычий сигнал
    }
    
    //--- Shooting Star
    if(open[bar] > close[bar] && 
       (high[bar] - open[bar]) > 2 * (open[bar] - low[bar]) &&
       (high[bar] - close[bar]) > 2 * (close[bar] - low[bar])) {
        pattern_score -= 0.3; // Медвежий сигнал
    }
    
    //--- Анализ дивергенций
    if(bar >= 5) {
        //--- RSI дивергенция
        if(close[bar] > close[bar-5] && rsi_values[bar] < rsi_values[bar-5]) {
            pattern_score -= 0.4; // Медвежья дивергенция
        } else if(close[bar] < close[bar-5] && rsi_values[bar] > rsi_values[bar-5]) {
            pattern_score += 0.4; // Бычья дивергенция
        }
    }
    
    return MathMax(-1, MathMin(1, pattern_score));
}

//+------------------------------------------------------------------+
//| Классический расчет вероятности                                  |
//+------------------------------------------------------------------+
double CalculateClassicProbability(const MarketAnalysis &analysis)
{
    double probability = 0;
    
    //--- Взвешенная сумма всех факторов
    probability += analysis.trend_strength * 0.25;
    probability += analysis.volatility * 0.20;
    probability += analysis.momentum * 0.20;
    probability += analysis.volume_analysis * 0.15;
    probability += analysis.support_resistance * 0.10;
    probability += analysis.fibonacci_levels * 0.05;
    probability += analysis.pattern_recognition * 0.05;
    
    //--- Нормализация к диапазону 0-1
    return (probability + 1) / 2;
}

//+------------------------------------------------------------------+
//| Определение типа сигнала                                         |
//+------------------------------------------------------------------+
int DetermineSignalType(const MarketAnalysis &analysis, int bar, const double &close[])
{
    //--- Проверка на Boom (рост)
    if(analysis.trend_strength > 0.3 && 
       analysis.momentum > 0.2 && 
       analysis.volume_analysis > 0.1) {
        return 1; // Boom
    }
    
    //--- Проверка на Crash (падение)
    if(analysis.trend_strength < -0.3 && 
       analysis.momentum < -0.2 && 
       analysis.volume_analysis > 0.1) {
        return -1; // Crash
    }
    
    return 0; // Нет сигнала
}

//+------------------------------------------------------------------+
//| Машинное обучение - предсказание                                |
//+------------------------------------------------------------------+
double PredictWithML(int bar)
{
    if(learning_count < 10) {
        return CalculateClassicProbability(PerformComprehensiveAnalysis(bar, 0, NULL, NULL, NULL, NULL, NULL, NULL));
    }
    
    //--- Подготовка признаков для текущего бара
    double features[20];
    PrepareFeatures(bar, features);
    
    //--- Простое машинное обучение (линейная регрессия)
    double prediction = 0;
    for(int i = 0; i < 20; i++) {
        prediction += features[i] * GetLearnedWeight(i);
    }
    
    return MathMax(0, MathMin(1, prediction));
}

//+------------------------------------------------------------------+
//| Подготовка признаков для машинного обучения                     |
//+------------------------------------------------------------------+
void PrepareFeatures(int bar, double &features[])
{
    //--- Нормализованные признаки
    features[0] = (rsi_values[bar] - 50) / 50;
    features[1] = macd_main[bar] / 0.001;
    features[2] = (macd_main[bar] - macd_signal[bar]) / 0.001;
    features[3] = atr_values[bar] / 0.001;
    features[4] = (bb_upper[bar] - bb_lower[bar]) / bb_middle[bar];
    features[5] = (ema1_values[bar] - ema2_values[bar]) / _Point;
    features[6] = (ema2_values[bar] - ema3_values[bar]) / _Point;
    features[7] = stoch_main[bar] / 100;
    features[8] = (stoch_main[bar] - stoch_signal[bar]) / 100;
    features[9] = mfi_values[bar] / 100;
    features[10] = obv_values[bar] / 1000000;
    features[11] = zigzag_values[bar] / _Point;
    features[12] = fractal_values[bar] / _Point;
    
    //--- Дополнительные признаки
    if(bar > 0) {
        features[13] = (rsi_values[bar] - rsi_values[bar-1]) / 50;
        features[14] = (macd_main[bar] - macd_main[bar-1]) / 0.001;
        features[15] = (atr_values[bar] - atr_values[bar-1]) / 0.001;
    }
    
    //--- Заполнение оставшихся признаков нулями
    for(int i = 16; i < 20; i++) {
        features[i] = 0;
    }
}

//+------------------------------------------------------------------+
//| Получение весов для машинного обучения                           |
//+------------------------------------------------------------------+
double GetLearnedWeight(int feature_index)
{
    //--- Простая реализация - в реальности здесь должна быть более сложная логика
    static double weights[20] = {0.1, 0.15, 0.1, 0.05, 0.1, 0.1, 0.1, 0.1, 0.05, 0.05, 0.05, 0.02, 0.02, 0.01, 0.01, 0.01, 0, 0, 0, 0};
    return weights[feature_index];
}

//+------------------------------------------------------------------+
//| Обновление данных для самообучения                              |
//+------------------------------------------------------------------+
void UpdateLearningData(const MarketAnalysis &analysis, int bar)
{
    if(learning_count >= LearningPeriod) return;
    
    LearningData data;
    PrepareFeatures(bar, data.features);
    data.outcome = analysis.signal_type;
    data.timestamp = TimeCurrent();
    
    learning_dataset[learning_count] = data;
    learning_count++;
    
    //--- Простое обновление весов
    if(learning_count > 10) {
        UpdateWeights();
    }
}

//+------------------------------------------------------------------+
//| Обновление весов машинного обучения                              |
//+------------------------------------------------------------------+
void UpdateWeights()
{
    //--- Простая реализация градиентного спуска
    static double weights[20] = {0.1, 0.15, 0.1, 0.05, 0.1, 0.1, 0.1, 0.1, 0.05, 0.05, 0.05, 0.02, 0.02, 0.01, 0.01, 0.01, 0, 0, 0, 0};
    
    for(int i = 0; i < MathMin(learning_count, 20); i++) {
        double prediction = 0;
        for(int j = 0; j < 20; j++) {
            prediction += learning_dataset[i].features[j] * weights[j];
        }
        
        double error = learning_dataset[i].outcome - prediction;
        
        for(int j = 0; j < 20; j++) {
            weights[j] += LearningRate * error * learning_dataset[i].features[j];
        }
    }
}

//+------------------------------------------------------------------+
//| Отправка оповещения                                              |
//+------------------------------------------------------------------+
void SendAlert(const MarketAnalysis &analysis)
{
    string message = "";
    string symbol_name = _Symbol;
    
    if(analysis.signal_type == 1) {
        message = "🔵 BOOM SPIKE PREDICTED for " + symbol_name + 
                 "\nProbability: " + DoubleToString(analysis.spike_probability * 100, 1) + "%" +
                 "\nTime: " + TimeToString(analysis.signal_time);
    } else if(analysis.signal_type == -1) {
        message = "🔴 CRASH SPIKE PREDICTED for " + symbol_name + 
                 "\nProbability: " + DoubleToString(analysis.spike_probability * 100, 1) + "%" +
                 "\nTime: " + TimeToString(analysis.signal_time);
    }
    
    if(message != "") {
        Alert(message);
        Print(message);
        
        //--- Отправка в лог
        Print("=== CRASH/BOOM ANALYSIS ===");
        Print("Trend Strength: ", DoubleToString(analysis.trend_strength, 3));
        Print("Volatility: ", DoubleToString(analysis.volatility, 3));
        Print("Momentum: ", DoubleToString(analysis.momentum, 3));
        Print("Volume Analysis: ", DoubleToString(analysis.volume_analysis, 3));
        Print("Support/Resistance: ", DoubleToString(analysis.support_resistance, 3));
        Print("Fibonacci Levels: ", DoubleToString(analysis.fibonacci_levels, 3));
        Print("Pattern Recognition: ", DoubleToString(analysis.pattern_recognition, 3));
        Print("Spike Probability: ", DoubleToString(analysis.spike_probability * 100, 1), "%");
    }
}

//+------------------------------------------------------------------+
//| Деинициализация индикатора                                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Освобождение ресурсов
    if(rsi_handle != INVALID_HANDLE) IndicatorRelease(rsi_handle);
    if(macd_handle != INVALID_HANDLE) IndicatorRelease(macd_handle);
    if(atr_handle != INVALID_HANDLE) IndicatorRelease(atr_handle);
    if(bb_handle != INVALID_HANDLE) IndicatorRelease(bb_handle);
    if(ema1_handle != INVALID_HANDLE) IndicatorRelease(ema1_handle);
    if(ema2_handle != INVALID_HANDLE) IndicatorRelease(ema2_handle);
    if(ema3_handle != INVALID_HANDLE) IndicatorRelease(ema3_handle);
    if(stoch_handle != INVALID_HANDLE) IndicatorRelease(stoch_handle);
    if(mfi_handle != INVALID_HANDLE) IndicatorRelease(mfi_handle);
    if(obv_handle != INVALID_HANDLE) IndicatorRelease(obv_handle);
    if(zigzag_handle != INVALID_HANDLE) IndicatorRelease(zigzag_handle);
    if(fractal_handle != INVALID_HANDLE) IndicatorRelease(fractal_handle);
    
    Print("Индикатор CrashBoom_ImpulseDetector деинициализирован");
}

//+------------------------------------------------------------------+
//| Обработчик событий                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    //--- Обработка событий графика (если необходимо)
}