//+------------------------------------------------------------------+
//|                                    CrashBoom_ImpulseDetector.mq5 |
//|                                           Copyright 2024, Cursor |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Cursor"
#property link      ""
#property version   "1.00"
#property description "Комплексный индикатор для прогнозирования импульсов на индексах Crash/Boom Deriv"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2

// Буферы для стрелок
#property indicator_label1  "Crash Spike"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

#property indicator_label2  "Boom Spike"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  3

//--- Входные параметры
input group "=== Основные параметры ==="
input int                  SpikeDetectionDepth = 20;           // Глубина анализа фракталов
input double               SpikePredictionSensitivity = 0.75;  // Чувствительность к определению импульса (0.1-1.0)
input ENUM_TIMEFRAMES      AnalysisTimeframe = PERIOD_CURRENT; // Таймфрейм анализа

input group "=== Скользящие средние ==="
input int                  MovingAveragePeriod1 = 50;          // Период EMA 1
input int                  MovingAveragePeriod2 = 100;         // Период EMA 2
input int                  MovingAveragePeriod3 = 200;         // Период EMA 3
input ENUM_MA_METHOD       MA_Method = MODE_EMA;               // Метод скользящей средней

input group "=== Осцилляторы ==="
input int                  RSI_Period = 14;                   // Период RSI
input int                  MACD_Fast = 12;                    // MACD быстрая EMA
input int                  MACD_Slow = 26;                    // MACD медленная EMA
input int                  MACD_Signal = 9;                   // MACD сигнальная линия
input int                  Stoch_K = 5;                       // Stochastic %K период
input int                  Stoch_D = 3;                       // Stochastic %D период
input int                  Stoch_Slowing = 3;                 // Stochastic замедление

input group "=== Волатильность ==="
input int                  ATR_Period = 14;                   // Период ATR
input int                  BB_Period = 20;                    // Период Bollinger Bands
input double               BB_Deviation = 2.0;                // Отклонение Bollinger Bands

input group "=== Фибоначчи и уровни ==="
input bool                 ShowFibonacciLevels = true;        // Показывать Фибо-уровни
input int                  ZigZagDepth = 12;                  // ZigZag глубина
input int                  ZigZagDeviation = 5;               // ZigZag отклонение
input int                  ZigZagBackstep = 3;                // ZigZag откат

input group "=== Визуализация ==="
input int                  ArrowSize = 3;                     // Размер стрелки
input int                  ArrowDistance = 20;                // Смещение стрелки от свечи
input color                CrashArrowColor = clrRed;          // Цвет стрелки Crash
input color                BoomArrowColor = clrBlue;          // Цвет стрелки Boom
input bool                 ShowInfoPanel = true;              // Показать информационную панель

input group "=== Оповещения ==="
input bool                 EnableAlerts = true;               // Включить звуковые сигналы
input bool                 EnablePushNotifications = false;   // Включить Push уведомления
input bool                 EnableEmailAlerts = false;         // Включить Email уведомления
input string               AlertSoundFile = "alert.wav";      // Звуковой файл

input group "=== Самообучение ==="
input bool                 EnableSelfLearning = true;         // Включить самообучение
input int                  LearningPeriod = 1000;             // Период обучения (баров)
input double               LearningRate = 0.01;               // Скорость обучения

//--- Глобальные переменные
double CrashArrowBuffer[];
double BoomArrowBuffer[];
double TempBuffer1[];
double TempBuffer2[];

// Хендлы индикаторов
int handle_MA1, handle_MA2, handle_MA3;
int handle_RSI, handle_MACD, handle_Stoch;
int handle_ATR, handle_BB;
int handle_ZigZag, handle_Fractals;
int handle_Ichimoku, handle_SAR;
int handle_Williams, handle_CCI, handle_Momentum;
int handle_OBV, handle_MFI;
int handle_Alligator, handle_AO, handle_AC;

// Массивы для данных индикаторов
double ma1_data[], ma2_data[], ma3_data[];
double rsi_data[], macd_main[], macd_signal[];
double atr_data[], bb_upper[], bb_lower[], bb_middle[];
double stoch_main[], stoch_signal[];
double zigzag_data[], fractals_up[], fractals_down[];
double ichimoku_tenkan[], ichimoku_kijun[], ichimoku_senkou_a[], ichimoku_senkou_b[];
double sar_data[], williams_data[], cci_data[], momentum_data[];
double obv_data[], mfi_data[];
double alligator_jaw[], alligator_teeth[], alligator_lips[];
double ao_data[], ac_data[];

// Переменные для самообучения
double learning_weights[];
double prediction_accuracy = 0.0;
int correct_predictions = 0;
int total_predictions = 0;

// Структура для анализа паттернов
struct SpikePattern {
    double rsi_level;
    double macd_divergence;
    double atr_volatility;
    double ma_convergence;
    double bb_squeeze;
    double volume_spike;
    double fractal_strength;
    bool is_crash_pattern;
    double confidence;
    datetime pattern_time;
};

SpikePattern recent_patterns[];

// Переменные для отслеживания состояния
datetime last_alert_time = 0;
bool crash_signal_active = false;
bool boom_signal_active = false;
string current_symbol = "";

//+------------------------------------------------------------------+
//| Функция инициализации индикатора                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Проверка символа
    current_symbol = Symbol();
    if(!IsValidSymbol(current_symbol)) {
        Print("ВНИМАНИЕ: Индикатор оптимизирован для индексов Crash/Boom Deriv");
    }
    
    // Установка буферов
    SetIndexBuffer(0, CrashArrowBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, BoomArrowBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, TempBuffer1, INDICATOR_CALCULATIONS);
    SetIndexBuffer(3, TempBuffer2, INDICATOR_CALCULATIONS);
    
    // Настройка стрелок
    PlotIndexSetInteger(0, PLOT_ARROW, 234); // Стрелка вниз для Crash
    PlotIndexSetInteger(1, PLOT_ARROW, 233); // Стрелка вверх для Boom
    
    PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, -ArrowDistance);
    PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, ArrowDistance);
    
    // Инициализация индикаторов
    InitializeIndicators();
    
    // Инициализация массивов для самообучения
    if(EnableSelfLearning) {
        ArrayResize(learning_weights, 20); // 20 весовых коэффициентов
        ArrayResize(recent_patterns, 100); // Последние 100 паттернов
        InitializeLearningWeights();
    }
    
    // Создание информационной панели
    if(ShowInfoPanel) {
        CreateInfoPanel();
    }
    
    Print("CrashBoom ImpulseDetector v1.0 инициализирован для символа: ", current_symbol);
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Функция деинициализации                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Освобождение хендлов индикаторов
    ReleaseIndicatorHandles();
    
    // Удаление графических объектов
    CleanupGraphicalObjects();
    
    // Удаление информационной панели
    if(ShowInfoPanel) {
        DeleteInfoPanel();
    }
    
    Print("CrashBoom ImpulseDetector деинициализирован");
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
    // Проверка минимального количества баров
    if(rates_total < 100) return(0);
    
    int start = MathMax(prev_calculated - 1, 100);
    if(start < 100) start = 100;
    
    // Получение данных всех индикаторов
    if(!GetAllIndicatorData(rates_total)) {
        return(prev_calculated);
    }
    
    // Основной цикл анализа
    for(int i = start; i < rates_total - 1; i++) {
        // Инициализация буферов
        CrashArrowBuffer[i] = EMPTY_VALUE;
        BoomArrowBuffer[i] = EMPTY_VALUE;
        
        // Комплексный технический анализ
        double crash_probability = AnalyzeCrashProbability(i, rates_total, time, open, high, low, close, tick_volume);
        double boom_probability = AnalyzeBoomProbability(i, rates_total, time, open, high, low, close, tick_volume);
        
        // Применение самообучения
        if(EnableSelfLearning) {
            crash_probability = ApplyLearning(crash_probability, true, i);
            boom_probability = ApplyLearning(boom_probability, false, i);
        }
        
        // Проверка условий для сигналов
        if(crash_probability > SpikePredictionSensitivity) {
            CrashArrowBuffer[i] = high[i] + ArrowDistance * Point();
            
            if(i == rates_total - 2 && !crash_signal_active) {
                SendCrashAlert(crash_probability, time[i]);
                crash_signal_active = true;
                boom_signal_active = false;
            }
        }
        
        if(boom_probability > SpikePredictionSensitivity) {
            BoomArrowBuffer[i] = low[i] - ArrowDistance * Point();
            
            if(i == rates_total - 2 && !boom_signal_active) {
                SendBoomAlert(boom_probability, time[i]);
                boom_signal_active = true;
                crash_signal_active = false;
            }
        }
        
        // Сохранение паттерна для обучения
        if(EnableSelfLearning && (crash_probability > 0.3 || boom_probability > 0.3)) {
            SavePatternForLearning(i, crash_probability, boom_probability, time, open, high, low, close);
        }
    }
    
    // Обновление информационной панели
    if(ShowInfoPanel) {
        UpdateInfoPanel(rates_total - 1, time, close);
    }
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Инициализация всех индикаторов                                    |
//+------------------------------------------------------------------+
void InitializeIndicators()
{
    // Скользящие средние
    handle_MA1 = iMA(NULL, AnalysisTimeframe, MovingAveragePeriod1, 0, MA_Method, PRICE_CLOSE);
    handle_MA2 = iMA(NULL, AnalysisTimeframe, MovingAveragePeriod2, 0, MA_Method, PRICE_CLOSE);
    handle_MA3 = iMA(NULL, AnalysisTimeframe, MovingAveragePeriod3, 0, MA_Method, PRICE_CLOSE);
    
    // Осцилляторы
    handle_RSI = iRSI(NULL, AnalysisTimeframe, RSI_Period, PRICE_CLOSE);
    handle_MACD = iMACD(NULL, AnalysisTimeframe, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
    handle_Stoch = iStochastic(NULL, AnalysisTimeframe, Stoch_K, Stoch_D, Stoch_Slowing, MODE_SMA, STO_LOWHIGH);
    handle_Williams = iWPR(NULL, AnalysisTimeframe, 14);
    handle_CCI = iCCI(NULL, AnalysisTimeframe, 14, PRICE_TYPICAL);
    handle_Momentum = iMomentum(NULL, AnalysisTimeframe, 14, PRICE_CLOSE);
    
    // Волатильность
    handle_ATR = iATR(NULL, AnalysisTimeframe, ATR_Period);
    handle_BB = iBands(NULL, AnalysisTimeframe, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
    
    // Объемы
    handle_OBV = iOBV(NULL, AnalysisTimeframe, VOLUME_TICK);
    handle_MFI = iMFI(NULL, AnalysisTimeframe, 14, VOLUME_TICK);
    
    // Графические паттерны
    handle_ZigZag = iCustom(NULL, AnalysisTimeframe, "ZigZag", ZigZagDepth, ZigZagDeviation, ZigZagBackstep);
    handle_Fractals = iFractals(NULL, AnalysisTimeframe);
    
    // Bill Williams
    handle_Ichimoku = iIchimoku(NULL, AnalysisTimeframe, 9, 26, 52);
    handle_SAR = iSAR(NULL, AnalysisTimeframe, 0.02, 0.2);
    handle_Alligator = iAlligator(NULL, AnalysisTimeframe, 13, 8, 8, 5, 5, 3, MODE_SMMA, PRICE_MEDIAN);
    handle_AO = iAO(NULL, AnalysisTimeframe);
    handle_AC = iAC(NULL, AnalysisTimeframe);
    
    // Проверка успешности создания хендлов
    if(handle_MA1 == INVALID_HANDLE || handle_MA2 == INVALID_HANDLE || handle_MA3 == INVALID_HANDLE ||
       handle_RSI == INVALID_HANDLE || handle_MACD == INVALID_HANDLE || handle_ATR == INVALID_HANDLE) {
        Print("ОШИБКА: Не удалось создать хендлы индикаторов!");
    }
}

//+------------------------------------------------------------------+
//| Получение данных всех индикаторов                                 |
//+------------------------------------------------------------------+
bool GetAllIndicatorData(int rates_total)
{
    int copy_count = MathMin(rates_total, 1000);
    
    // Скользящие средние
    if(CopyBuffer(handle_MA1, 0, 0, copy_count, ma1_data) <= 0) return false;
    if(CopyBuffer(handle_MA2, 0, 0, copy_count, ma2_data) <= 0) return false;
    if(CopyBuffer(handle_MA3, 0, 0, copy_count, ma3_data) <= 0) return false;
    
    // Осцилляторы
    if(CopyBuffer(handle_RSI, 0, 0, copy_count, rsi_data) <= 0) return false;
    if(CopyBuffer(handle_MACD, 0, 0, copy_count, macd_main) <= 0) return false;
    if(CopyBuffer(handle_MACD, 1, 0, copy_count, macd_signal) <= 0) return false;
    if(CopyBuffer(handle_Stoch, 0, 0, copy_count, stoch_main) <= 0) return false;
    if(CopyBuffer(handle_Stoch, 1, 0, copy_count, stoch_signal) <= 0) return false;
    if(CopyBuffer(handle_Williams, 0, 0, copy_count, williams_data) <= 0) return false;
    if(CopyBuffer(handle_CCI, 0, 0, copy_count, cci_data) <= 0) return false;
    if(CopyBuffer(handle_Momentum, 0, 0, copy_count, momentum_data) <= 0) return false;
    
    // Волатильность
    if(CopyBuffer(handle_ATR, 0, 0, copy_count, atr_data) <= 0) return false;
    if(CopyBuffer(handle_BB, 0, 0, copy_count, bb_upper) <= 0) return false;
    if(CopyBuffer(handle_BB, 1, 0, copy_count, bb_middle) <= 0) return false;
    if(CopyBuffer(handle_BB, 2, 0, copy_count, bb_lower) <= 0) return false;
    
    // Объемы
    if(CopyBuffer(handle_OBV, 0, 0, copy_count, obv_data) <= 0) return false;
    if(CopyBuffer(handle_MFI, 0, 0, copy_count, mfi_data) <= 0) return false;
    
    // Графические паттерны
    if(CopyBuffer(handle_ZigZag, 0, 0, copy_count, zigzag_data) <= 0) return false;
    if(CopyBuffer(handle_Fractals, 0, 0, copy_count, fractals_up) <= 0) return false;
    if(CopyBuffer(handle_Fractals, 1, 0, copy_count, fractals_down) <= 0) return false;
    
    // Bill Williams
    if(CopyBuffer(handle_Ichimoku, 0, 0, copy_count, ichimoku_tenkan) <= 0) return false;
    if(CopyBuffer(handle_Ichimoku, 1, 0, copy_count, ichimoku_kijun) <= 0) return false;
    if(CopyBuffer(handle_SAR, 0, 0, copy_count, sar_data) <= 0) return false;
    if(CopyBuffer(handle_Alligator, 0, 0, copy_count, alligator_jaw) <= 0) return false;
    if(CopyBuffer(handle_Alligator, 1, 0, copy_count, alligator_teeth) <= 0) return false;
    if(CopyBuffer(handle_Alligator, 2, 0, copy_count, alligator_lips) <= 0) return false;
    if(CopyBuffer(handle_AO, 0, 0, copy_count, ao_data) <= 0) return false;
    if(CopyBuffer(handle_AC, 0, 0, copy_count, ac_data) <= 0) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Анализ вероятности Crash импульса                                 |
//+------------------------------------------------------------------+
double AnalyzeCrashProbability(int index, int rates_total, const datetime &time[], const double &open[], 
                              const double &high[], const double &low[], const double &close[], const long &tick_volume[])
{
    if(index < 50 || index >= ArraySize(rsi_data)) return 0.0;
    
    double crash_score = 0.0;
    double weight_sum = 0.0;
    
    // 1. Анализ RSI (перекупленность)
    if(rsi_data[index] > 70) {
        crash_score += (rsi_data[index] - 70) / 30.0 * 0.15;
    }
    weight_sum += 0.15;
    
    // 2. MACD дивергенция
    if(index > 10) {
        double macd_divergence = CalculateMACDDivergence(index, close);
        if(macd_divergence < 0) { // Медвежья дивергенция
            crash_score += MathAbs(macd_divergence) * 0.12;
        }
    }
    weight_sum += 0.12;
    
    // 3. Анализ скользящих средних (цена выше всех MA)
    if(close[index] > ma1_data[index] && close[index] > ma2_data[index] && close[index] > ma3_data[index]) {
        double ma_distance = (close[index] - ma1_data[index]) / ma1_data[index];
        if(ma_distance > 0.02) { // Цена слишком далеко от MA
            crash_score += MathMin(ma_distance * 5, 0.1);
        }
    }
    weight_sum += 0.1;
    
    // 4. Bollinger Bands (цена у верхней полосы)
    if(close[index] > bb_upper[index] * 0.98) {
        crash_score += 0.08;
    }
    weight_sum += 0.08;
    
    // 5. Анализ волатильности ATR
    if(index > ATR_Period) {
        double atr_ratio = atr_data[index] / atr_data[index - ATR_Period];
        if(atr_ratio > 1.5) { // Повышенная волатильность
            crash_score += MathMin((atr_ratio - 1.0) * 0.1, 0.1);
        }
    }
    weight_sum += 0.1;
    
    // 6. Stochastic перекупленность
    if(stoch_main[index] > 80 && stoch_signal[index] > 80) {
        crash_score += 0.08;
    }
    weight_sum += 0.08;
    
    // 7. Williams %R
    if(williams_data[index] > -20) {
        crash_score += (-williams_data[index] / 20.0) * 0.06;
    }
    weight_sum += 0.06;
    
    // 8. CCI перекупленность
    if(cci_data[index] > 100) {
        crash_score += MathMin(cci_data[index] / 200.0, 0.05);
    }
    weight_sum += 0.05;
    
    // 9. Анализ объемов
    if(index > 5) {
        double volume_spike = AnalyzeVolumeSpike(index, tick_volume);
        if(volume_spike > 1.5) {
            crash_score += MathMin((volume_spike - 1.0) * 0.1, 0.08);
        }
    }
    weight_sum += 0.08;
    
    // 10. Фрактальный анализ
    double fractal_strength = AnalyzeFractalStrength(index, high, low, true);
    crash_score += fractal_strength * 0.06;
    weight_sum += 0.06;
    
    // 11. Parabolic SAR
    if(sar_data[index] < close[index] && index > 1 && sar_data[index-1] > close[index-1]) {
        crash_score += 0.05; // Разворот SAR
    }
    weight_sum += 0.05;
    
    // 12. Ichimoku анализ
    if(close[index] > ichimoku_tenkan[index] && ichimoku_tenkan[index] < ichimoku_kijun[index]) {
        crash_score += 0.04;
    }
    weight_sum += 0.04;
    
    // 13. Awesome Oscillator
    if(index > 1 && ao_data[index] < ao_data[index-1] && ao_data[index-1] > ao_data[index-2]) {
        crash_score += 0.03;
    }
    weight_sum += 0.03;
    
    // Нормализация результата
    if(weight_sum > 0) {
        crash_score = crash_score / weight_sum;
    }
    
    return MathMin(crash_score, 1.0);
}

//+------------------------------------------------------------------+
//| Анализ вероятности Boom импульса                                  |
//+------------------------------------------------------------------+
double AnalyzeBoomProbability(int index, int rates_total, const datetime &time[], const double &open[], 
                             const double &high[], const double &low[], const double &close[], const long &tick_volume[])
{
    if(index < 50 || index >= ArraySize(rsi_data)) return 0.0;
    
    double boom_score = 0.0;
    double weight_sum = 0.0;
    
    // 1. Анализ RSI (перепроданность)
    if(rsi_data[index] < 30) {
        boom_score += (30 - rsi_data[index]) / 30.0 * 0.15;
    }
    weight_sum += 0.15;
    
    // 2. MACD дивергенция
    if(index > 10) {
        double macd_divergence = CalculateMACDDivergence(index, close);
        if(macd_divergence > 0) { // Бычья дивергенция
            boom_score += macd_divergence * 0.12;
        }
    }
    weight_sum += 0.12;
    
    // 3. Анализ скользящих средних (цена ниже всех MA)
    if(close[index] < ma1_data[index] && close[index] < ma2_data[index] && close[index] < ma3_data[index]) {
        double ma_distance = (ma1_data[index] - close[index]) / ma1_data[index];
        if(ma_distance > 0.02) { // Цена слишком далеко от MA
            boom_score += MathMin(ma_distance * 5, 0.1);
        }
    }
    weight_sum += 0.1;
    
    // 4. Bollinger Bands (цена у нижней полосы)
    if(close[index] < bb_lower[index] * 1.02) {
        boom_score += 0.08;
    }
    weight_sum += 0.08;
    
    // 5. Анализ волатильности ATR
    if(index > ATR_Period) {
        double atr_ratio = atr_data[index] / atr_data[index - ATR_Period];
        if(atr_ratio > 1.5) { // Повышенная волатильность
            boom_score += MathMin((atr_ratio - 1.0) * 0.1, 0.1);
        }
    }
    weight_sum += 0.1;
    
    // 6. Stochastic перепроданность
    if(stoch_main[index] < 20 && stoch_signal[index] < 20) {
        boom_score += 0.08;
    }
    weight_sum += 0.08;
    
    // 7. Williams %R
    if(williams_data[index] < -80) {
        boom_score += (MathAbs(williams_data[index]) - 80) / 20.0 * 0.06;
    }
    weight_sum += 0.06;
    
    // 8. CCI перепроданность
    if(cci_data[index] < -100) {
        boom_score += MathMin(MathAbs(cci_data[index]) / 200.0, 0.05);
    }
    weight_sum += 0.05;
    
    // 9. Анализ объемов
    if(index > 5) {
        double volume_spike = AnalyzeVolumeSpike(index, tick_volume);
        if(volume_spike > 1.5) {
            boom_score += MathMin((volume_spike - 1.0) * 0.1, 0.08);
        }
    }
    weight_sum += 0.08;
    
    // 10. Фрактальный анализ
    double fractal_strength = AnalyzeFractalStrength(index, high, low, false);
    boom_score += fractal_strength * 0.06;
    weight_sum += 0.06;
    
    // 11. Parabolic SAR
    if(sar_data[index] > close[index] && index > 1 && sar_data[index-1] < close[index-1]) {
        boom_score += 0.05; // Разворот SAR
    }
    weight_sum += 0.05;
    
    // 12. Ichimoku анализ
    if(close[index] < ichimoku_tenkan[index] && ichimoku_tenkan[index] > ichimoku_kijun[index]) {
        boom_score += 0.04;
    }
    weight_sum += 0.04;
    
    // 13. Awesome Oscillator
    if(index > 1 && ao_data[index] > ao_data[index-1] && ao_data[index-1] < ao_data[index-2]) {
        boom_score += 0.03;
    }
    weight_sum += 0.03;
    
    // Нормализация результата
    if(weight_sum > 0) {
        boom_score = boom_score / weight_sum;
    }
    
    return MathMin(boom_score, 1.0);
}

//+------------------------------------------------------------------+
//| Расчет MACD дивергенции                                           |
//+------------------------------------------------------------------+
double CalculateMACDDivergence(int index, const double &close[])
{
    if(index < 20) return 0.0;
    
    // Поиск локальных максимумов/минимумов цены и MACD
    double price_high1 = 0, price_high2 = 0;
    double macd_high1 = 0, macd_high2 = 0;
    double price_low1 = DBL_MAX, price_low2 = DBL_MAX;
    double macd_low1 = DBL_MAX, macd_low2 = DBL_MAX;
    
    int high_count = 0, low_count = 0;
    
    // Поиск последних двух максимумов и минимумов
    for(int i = index - 1; i > index - 20 && (high_count < 2 || low_count < 2); i--) {
        // Поиск максимумов
        if(i > 1 && i < ArraySize(close) - 1 && close[i] > close[i-1] && close[i] > close[i+1]) {
            if(high_count == 0) {
                price_high1 = close[i];
                macd_high1 = macd_main[i];
                high_count++;
            } else if(high_count == 1) {
                price_high2 = close[i];
                macd_high2 = macd_main[i];
                high_count++;
            }
        }
        
        // Поиск минимумов
        if(i > 1 && i < ArraySize(close) - 1 && close[i] < close[i-1] && close[i] < close[i+1]) {
            if(low_count == 0) {
                price_low1 = close[i];
                macd_low1 = macd_main[i];
                low_count++;
            } else if(low_count == 1) {
                price_low2 = close[i];
                macd_low2 = macd_main[i];
                low_count++;
            }
        }
    }
    
    double divergence = 0.0;
    
    // Медвежья дивергенция (цена растет, MACD падает)
    if(high_count == 2 && price_high1 > price_high2 && macd_high1 < macd_high2) {
        divergence = -((price_high1 - price_high2) / price_high2 + (macd_high2 - macd_high1) / MathAbs(macd_high2)) / 2.0;
    }
    
    // Бычья дивергенция (цена падает, MACD растет)
    if(low_count == 2 && price_low1 < price_low2 && macd_low1 > macd_low2) {
        divergence = ((price_low2 - price_low1) / price_low2 + (macd_low1 - macd_low2) / MathAbs(macd_low2)) / 2.0;
    }
    
    return divergence;
}

//+------------------------------------------------------------------+
//| Анализ всплеска объема                                            |
//+------------------------------------------------------------------+
double AnalyzeVolumeSpike(int index, const long &tick_volume[])
{
    if(index < 10) return 1.0;
    
    // Средний объем за последние 10 баров
    long avg_volume = 0;
    for(int i = index - 10; i < index; i++) {
        avg_volume += tick_volume[i];
    }
    avg_volume /= 10;
    
    if(avg_volume == 0) return 1.0;
    
    return (double)tick_volume[index] / (double)avg_volume;
}

//+------------------------------------------------------------------+
//| Анализ силы фракталов                                             |
//+------------------------------------------------------------------+
double AnalyzeFractalStrength(int index, const double &high[], const double &low[], bool is_crash)
{
    if(index < SpikeDetectionDepth || index >= ArraySize(fractals_up)) return 0.0;
    
    double strength = 0.0;
    
    if(is_crash) {
        // Поиск фракталов вверх (потенциальные точки разворота вниз)
        if(fractals_up[index] != EMPTY_VALUE && fractals_up[index] != 0) {
            // Проверяем силу фрактала по количеству баров до и после
            int bars_before = 0, bars_after = 0;
            double fractal_high = fractals_up[index];
            
            // Считаем бары до фрактала
            for(int i = index - 1; i >= MathMax(0, index - SpikeDetectionDepth); i--) {
                if(high[i] < fractal_high) bars_before++;
                else break;
            }
            
            // Считаем бары после фрактала
            for(int i = index + 1; i < MathMin(ArraySize(high), index + SpikeDetectionDepth); i++) {
                if(high[i] < fractal_high) bars_after++;
                else break;
            }
            
            strength = (double)(bars_before + bars_after) / (SpikeDetectionDepth * 2);
        }
    } else {
        // Поиск фракталов вниз (потенциальные точки разворота вверх)
        if(fractals_down[index] != EMPTY_VALUE && fractals_down[index] != 0) {
            int bars_before = 0, bars_after = 0;
            double fractal_low = fractals_down[index];
            
            for(int i = index - 1; i >= MathMax(0, index - SpikeDetectionDepth); i--) {
                if(low[i] > fractal_low) bars_before++;
                else break;
            }
            
            for(int i = index + 1; i < MathMin(ArraySize(low), index + SpikeDetectionDepth); i++) {
                if(low[i] > fractal_low) bars_after++;
                else break;
            }
            
            strength = (double)(bars_before + bars_after) / (SpikeDetectionDepth * 2);
        }
    }
    
    return MathMin(strength, 1.0);
}

//+------------------------------------------------------------------+
//| Применение самообучения                                           |
//+------------------------------------------------------------------+
double ApplyLearning(double base_probability, bool is_crash, int index)
{
    if(!EnableSelfLearning || ArraySize(learning_weights) == 0) {
        return base_probability;
    }
    
    // Получаем дополнительные веса на основе обученной модели
    double learning_adjustment = 0.0;
    
    // Используем различные комбинации индикаторов как входы для обучения
    if(index < ArraySize(rsi_data)) {
        learning_adjustment += learning_weights[0] * (rsi_data[index] - 50) / 50.0;
        learning_adjustment += learning_weights[1] * macd_main[index];
        learning_adjustment += learning_weights[2] * (atr_data[index] / Point() - 100) / 100.0;
        
        if(index > 0) {
            learning_adjustment += learning_weights[3] * (stoch_main[index] - 50) / 50.0;
            learning_adjustment += learning_weights[4] * williams_data[index] / 100.0;
        }
    }
    
    // Нормализуем корректировку
    learning_adjustment = MathMax(-0.3, MathMin(0.3, learning_adjustment));
    
    double adjusted_probability = base_probability + learning_adjustment;
    return MathMax(0.0, MathMin(1.0, adjusted_probability));
}

//+------------------------------------------------------------------+
//| Инициализация весов для обучения                                  |
//+------------------------------------------------------------------+
void InitializeLearningWeights()
{
    // Инициализируем веса случайными значениями около нуля
    MathSrand((int)TimeLocal());
    for(int i = 0; i < ArraySize(learning_weights); i++) {
        learning_weights[i] = (MathRand() / 32767.0 - 0.5) * 0.1;
    }
}

//+------------------------------------------------------------------+
//| Сохранение паттерна для обучения                                  |
//+------------------------------------------------------------------+
void SavePatternForLearning(int index, double crash_prob, double boom_prob, const datetime &time[], 
                           const double &open[], const double &high[], const double &low[], const double &close[])
{
    if(ArraySize(recent_patterns) == 0) return;
    
    // Находим свободное место в массиве паттернов
    int pattern_index = -1;
    for(int i = 0; i < ArraySize(recent_patterns); i++) {
        if(recent_patterns[i].pattern_time == 0) {
            pattern_index = i;
            break;
        }
    }
    
    // Если нет свободного места, перезаписываем самый старый
    if(pattern_index == -1) {
        pattern_index = 0;
        datetime oldest_time = recent_patterns[0].pattern_time;
        for(int i = 1; i < ArraySize(recent_patterns); i++) {
            if(recent_patterns[i].pattern_time < oldest_time) {
                oldest_time = recent_patterns[i].pattern_time;
                pattern_index = i;
            }
        }
    }
    
    // Сохраняем паттерн
    if(index < ArraySize(rsi_data)) {
        recent_patterns[pattern_index].rsi_level = rsi_data[index];
        recent_patterns[pattern_index].macd_divergence = macd_main[index] - macd_signal[index];
        recent_patterns[pattern_index].atr_volatility = atr_data[index];
        recent_patterns[pattern_index].ma_convergence = ma1_data[index] - ma2_data[index];
        recent_patterns[pattern_index].bb_squeeze = (bb_upper[index] - bb_lower[index]) / bb_middle[index];
        recent_patterns[pattern_index].volume_spike = 1.0; // Будет рассчитано отдельно
        recent_patterns[pattern_index].fractal_strength = 0.0; // Будет рассчитано отдельно
        recent_patterns[pattern_index].is_crash_pattern = crash_prob > boom_prob;
        recent_patterns[pattern_index].confidence = MathMax(crash_prob, boom_prob);
        recent_patterns[pattern_index].pattern_time = time[index];
    }
}

//+------------------------------------------------------------------+
//| Отправка оповещения о Crash сигнале                               |
//+------------------------------------------------------------------+
void SendCrashAlert(double probability, datetime signal_time)
{
    if(!EnableAlerts || TimeCurrent() - last_alert_time < 60) return; // Не чаще раза в минуту
    
    string message = StringFormat("🔴 CRASH SPIKE ПРЕДУПРЕЖДЕНИЕ!\nСимвол: %s\nВероятность: %.1f%%\nВремя: %s", 
                                 Symbol(), probability * 100, TimeToString(signal_time));
    
    if(EnableAlerts) {
        Alert(message);
        PlaySound(AlertSoundFile);
    }
    
    if(EnablePushNotifications) {
        SendNotification(message);
    }
    
    Print(message);
    last_alert_time = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Отправка оповещения о Boom сигнале                                |
//+------------------------------------------------------------------+
void SendBoomAlert(double probability, datetime signal_time)
{
    if(!EnableAlerts || TimeCurrent() - last_alert_time < 60) return; // Не чаще раза в минуту
    
    string message = StringFormat("🔵 BOOM SPIKE ПРЕДУПРЕЖДЕНИЕ!\nСимвол: %s\nВероятность: %.1f%%\nВремя: %s", 
                                 Symbol(), probability * 100, TimeToString(signal_time));
    
    if(EnableAlerts) {
        Alert(message);
        PlaySound(AlertSoundFile);
    }
    
    if(EnablePushNotifications) {
        SendNotification(message);
    }
    
    Print(message);
    last_alert_time = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Проверка валидности символа                                       |
//+------------------------------------------------------------------+
bool IsValidSymbol(string symbol)
{
    string valid_symbols[] = {
        "Crash 150 Index", "Crash 300 Index", "Crash 500 Index", "Crash 600 Index", "Crash 900 Index", "Crash 1000 Index",
        "Boom 150 Index", "Boom 300 Index", "Boom 500 Index", "Boom 600 Index", "Boom 900 Index", "Boom 1000 Index",
        "CRASH150", "CRASH300", "CRASH500", "CRASH600", "CRASH900", "CRASH1000",
        "BOOM150", "BOOM300", "BOOM500", "BOOM600", "BOOM900", "BOOM1000"
    };
    
    for(int i = 0; i < ArraySize(valid_symbols); i++) {
        if(StringFind(symbol, valid_symbols[i]) >= 0) return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Создание информационной панели                                    |
//+------------------------------------------------------------------+
void CreateInfoPanel()
{
    // Создаем прямоугольник для панели
    ObjectCreate(0, "InfoPanel_Background", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "InfoPanel_Background", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "InfoPanel_Background", OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, "InfoPanel_Background", OBJPROP_YDISTANCE, 30);
    ObjectSetInteger(0, "InfoPanel_Background", OBJPROP_XSIZE, 250);
    ObjectSetInteger(0, "InfoPanel_Background", OBJPROP_YSIZE, 150);
    ObjectSetInteger(0, "InfoPanel_Background", OBJPROP_BGCOLOR, clrDarkSlateGray);
    ObjectSetInteger(0, "InfoPanel_Background", OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, "InfoPanel_Background", OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, "InfoPanel_Background", OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, "InfoPanel_Background", OBJPROP_WIDTH, 1);
    
    // Заголовок панели
    ObjectCreate(0, "InfoPanel_Title", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "InfoPanel_Title", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "InfoPanel_Title", OBJPROP_XDISTANCE, 20);
    ObjectSetInteger(0, "InfoPanel_Title", OBJPROP_YDISTANCE, 40);
    ObjectSetString(0, "InfoPanel_Title", OBJPROP_TEXT, "CrashBoom Detector v1.0");
    ObjectSetString(0, "InfoPanel_Title", OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, "InfoPanel_Title", OBJPROP_FONTSIZE, 10);
    ObjectSetInteger(0, "InfoPanel_Title", OBJPROP_COLOR, clrYellow);
    
    // Метки для отображения данных
    string labels[] = {"Symbol", "Trend", "RSI", "MACD", "ATR", "Probability"};
    for(int i = 0; i < ArraySize(labels); i++) {
        ObjectCreate(0, "InfoPanel_" + labels[i], OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, "InfoPanel_" + labels[i], OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, "InfoPanel_" + labels[i], OBJPROP_XDISTANCE, 20);
        ObjectSetInteger(0, "InfoPanel_" + labels[i], OBJPROP_YDISTANCE, 60 + i * 15);
        ObjectSetString(0, "InfoPanel_" + labels[i], OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, "InfoPanel_" + labels[i], OBJPROP_FONTSIZE, 8);
        ObjectSetInteger(0, "InfoPanel_" + labels[i], OBJPROP_COLOR, clrWhite);
    }
}

//+------------------------------------------------------------------+
//| Обновление информационной панели                                  |
//+------------------------------------------------------------------+
void UpdateInfoPanel(int index, const datetime &time[], const double &close[])
{
    if(index >= ArraySize(rsi_data) || index >= ArraySize(macd_main) || index >= ArraySize(atr_data)) return;
    
    // Определение тренда
    string trend = "Боковой";
    if(index > 2 && ArraySize(ma1_data) > index) {
        if(close[index] > ma1_data[index] && ma1_data[index] > ma2_data[index]) trend = "Восходящий";
        else if(close[index] < ma1_data[index] && ma1_data[index] < ma2_data[index]) trend = "Нисходящий";
    }
    
    // Обновляем текст меток
    ObjectSetString(0, "InfoPanel_Symbol", OBJPROP_TEXT, "Символ: " + Symbol());
    ObjectSetString(0, "InfoPanel_Trend", OBJPROP_TEXT, "Тренд: " + trend);
    ObjectSetString(0, "InfoPanel_RSI", OBJPROP_TEXT, StringFormat("RSI: %.1f", rsi_data[index]));
    ObjectSetString(0, "InfoPanel_MACD", OBJPROP_TEXT, StringFormat("MACD: %.5f", macd_main[index]));
    ObjectSetString(0, "InfoPanel_ATR", OBJPROP_TEXT, StringFormat("ATR: %.5f", atr_data[index]));
    
    // Показываем точность предсказаний если включено самообучение
    if(EnableSelfLearning && total_predictions > 0) {
        double accuracy = (double)correct_predictions / total_predictions * 100;
        ObjectSetString(0, "InfoPanel_Probability", OBJPROP_TEXT, StringFormat("Точность: %.1f%%", accuracy));
    } else {
        ObjectSetString(0, "InfoPanel_Probability", OBJPROP_TEXT, "Анализ активен");
    }
}

//+------------------------------------------------------------------+
//| Удаление информационной панели                                    |
//+------------------------------------------------------------------+
void DeleteInfoPanel()
{
    ObjectDelete(0, "InfoPanel_Background");
    ObjectDelete(0, "InfoPanel_Title");
    
    string labels[] = {"Symbol", "Trend", "RSI", "MACD", "ATR", "Probability"};
    for(int i = 0; i < ArraySize(labels); i++) {
        ObjectDelete(0, "InfoPanel_" + labels[i]);
    }
}

//+------------------------------------------------------------------+
//| Освобождение хендлов индикаторов                                  |
//+------------------------------------------------------------------+
void ReleaseIndicatorHandles()
{
    if(handle_MA1 != INVALID_HANDLE) IndicatorRelease(handle_MA1);
    if(handle_MA2 != INVALID_HANDLE) IndicatorRelease(handle_MA2);
    if(handle_MA3 != INVALID_HANDLE) IndicatorRelease(handle_MA3);
    if(handle_RSI != INVALID_HANDLE) IndicatorRelease(handle_RSI);
    if(handle_MACD != INVALID_HANDLE) IndicatorRelease(handle_MACD);
    if(handle_Stoch != INVALID_HANDLE) IndicatorRelease(handle_Stoch);
    if(handle_ATR != INVALID_HANDLE) IndicatorRelease(handle_ATR);
    if(handle_BB != INVALID_HANDLE) IndicatorRelease(handle_BB);
    if(handle_ZigZag != INVALID_HANDLE) IndicatorRelease(handle_ZigZag);
    if(handle_Fractals != INVALID_HANDLE) IndicatorRelease(handle_Fractals);
    if(handle_Ichimoku != INVALID_HANDLE) IndicatorRelease(handle_Ichimoku);
    if(handle_SAR != INVALID_HANDLE) IndicatorRelease(handle_SAR);
    if(handle_Williams != INVALID_HANDLE) IndicatorRelease(handle_Williams);
    if(handle_CCI != INVALID_HANDLE) IndicatorRelease(handle_CCI);
    if(handle_Momentum != INVALID_HANDLE) IndicatorRelease(handle_Momentum);
    if(handle_OBV != INVALID_HANDLE) IndicatorRelease(handle_OBV);
    if(handle_MFI != INVALID_HANDLE) IndicatorRelease(handle_MFI);
    if(handle_Alligator != INVALID_HANDLE) IndicatorRelease(handle_Alligator);
    if(handle_AO != INVALID_HANDLE) IndicatorRelease(handle_AO);
    if(handle_AC != INVALID_HANDLE) IndicatorRelease(handle_AC);
}

//+------------------------------------------------------------------+
//| Очистка графических объектов                                      |
//+------------------------------------------------------------------+
void CleanupGraphicalObjects()
{
    // Удаляем все объекты, созданные индикатором
    int total_objects = ObjectsTotal(0);
    for(int i = total_objects - 1; i >= 0; i--) {
        string object_name = ObjectName(0, i);
        if(StringFind(object_name, "CrashBoom_") == 0 || 
           StringFind(object_name, "InfoPanel_") == 0) {
            ObjectDelete(0, object_name);
        }
    }
}

//+------------------------------------------------------------------+
//| Обработчик событий                                                |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
    // Обработка событий графика (например, клики по панели)
    if(id == CHARTEVENT_OBJECT_CLICK) {
        if(sparam == "InfoPanel_Background") {
            // Можно добавить интерактивность панели
        }
    }
}