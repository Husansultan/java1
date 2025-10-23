//+------------------------------------------------------------------+
//|                                    CrashBoom_AdvancedAnalysis.mqh |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| Расширенная структура анализа                                    |
//+------------------------------------------------------------------+
struct AdvancedMarketAnalysis {
    //--- Основные компоненты
    double trend_analysis;
    double volatility_analysis;
    double momentum_analysis;
    double volume_analysis;
    double support_resistance_analysis;
    double fibonacci_analysis;
    double pattern_analysis;
    double market_structure_analysis;
    double time_analysis;
    double correlation_analysis;
    
    //--- Дополнительные метрики
    double spike_probability;
    double confidence_level;
    int signal_type;
    datetime signal_time;
    string signal_description;
    
    //--- Детализированные данные
    double rsi_value;
    double macd_value;
    double atr_value;
    double bb_position;
    double ema_alignment;
    double volume_ratio;
    double price_position;
    double time_factor;
};

//+------------------------------------------------------------------+
//| Класс для расширенного анализа                                   |
//+------------------------------------------------------------------+
class CAdvancedAnalyzer
{
private:
    //--- Хэндлы индикаторов
    int m_rsi_handle, m_macd_handle, m_atr_handle, m_bb_handle;
    int m_ema1_handle, m_ema2_handle, m_ema3_handle;
    int m_stoch_handle, m_mfi_handle, m_obv_handle;
    int m_zigzag_handle, m_fractal_handle;
    int m_ichimoku_handle, m_sar_handle;
    int m_williams_handle, m_cci_handle;
    int m_alligator_handle, m_ao_handle;
    
    //--- Массивы данных
    double m_rsi_values[], m_macd_main[], m_macd_signal[];
    double m_atr_values[], m_bb_upper[], m_bb_middle[], m_bb_lower[];
    double m_ema1_values[], m_ema2_values[], m_ema3_values[];
    double m_stoch_main[], m_stoch_signal[], m_mfi_values[], m_obv_values[];
    double m_zigzag_values[], m_fractal_values[];
    double m_ichimoku_tenkan[], m_ichimoku_kijun[], m_ichimoku_senkou_a[], m_ichimoku_senkou_b[];
    double m_sar_values[], m_williams_values[], m_cci_values[];
    double m_alligator_jaw[], m_alligator_teeth[], m_alligator_lips[];
    double m_ao_values[];
    
    //--- Параметры
    string m_symbol;
    ENUM_TIMEFRAMES m_timeframe;
    
public:
    CAdvancedAnalyzer();
    ~CAdvancedAnalyzer();
    
    bool Initialize(string symbol, ENUM_TIMEFRAMES timeframe);
    void Deinitialize();
    
    AdvancedMarketAnalysis PerformAdvancedAnalysis(int bar, int rates_total,
                                                  const datetime &time[],
                                                  const double &open[],
                                                  const double &high[],
                                                  const double &low[],
                                                  const double &close[],
                                                  const long &tick_volume[]);
    
private:
    bool InitializeIndicators();
    bool GetIndicatorData(int rates_total);
    
    //--- Методы анализа
    double AnalyzeTrendAdvanced(int bar);
    double AnalyzeVolatilityAdvanced(int bar);
    double AnalyzeMomentumAdvanced(int bar);
    double AnalyzeVolumeAdvanced(int bar, const long &tick_volume[]);
    double AnalyzeSupportResistanceAdvanced(int bar, const double &high[], const double &low[], const double &close[]);
    double AnalyzeFibonacciAdvanced(int bar, const double &high[], const double &low[], const double &close[]);
    double AnalyzePatternsAdvanced(int bar, const double &open[], const double &high[], const double &low[], const double &close[]);
    double AnalyzeMarketStructure(int bar, const double &high[], const double &low[], const double &close[]);
    double AnalyzeTimeFactors(int bar, const datetime &time[]);
    double AnalyzeCorrelations(int bar);
    
    //--- Вспомогательные методы
    double CalculateRSIDivergence(int bar, const double &close[]);
    double CalculateMACDDivergence(int bar, const double &close[]);
    double CalculateVolumeProfile(int bar, const long &tick_volume[]);
    double CalculatePriceAction(int bar, const double &open[], const double &high[], const double &low[], const double &close[]);
    double CalculateMarketMicrostructure(int bar, const double &high[], const double &low[], const double &close[]);
    
    //--- Методы для работы с уровнями
    double FindKeyLevels(int bar, const double &high[], const double &low[], const double &close[]);
    double CalculateLevelStrength(double level, int bar, const double &high[], const double &low[], const double &close[]);
    
    //--- Методы для работы с паттернами
    double DetectCandlestickPatterns(int bar, const double &open[], const double &high[], const double &low[], const double &close[]);
    double DetectChartPatterns(int bar, const double &high[], const double &low[], const double &close[]);
    double DetectHarmonicPatterns(int bar, const double &high[], const double &low[], const double &close[]);
};

//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
CAdvancedAnalyzer::CAdvancedAnalyzer()
{
    m_rsi_handle = m_macd_handle = m_atr_handle = m_bb_handle = INVALID_HANDLE;
    m_ema1_handle = m_ema2_handle = m_ema3_handle = INVALID_HANDLE;
    m_stoch_handle = m_mfi_handle = m_obv_handle = INVALID_HANDLE;
    m_zigzag_handle = m_fractal_handle = INVALID_HANDLE;
    m_ichimoku_handle = m_sar_handle = INVALID_HANDLE;
    m_williams_handle = m_cci_handle = INVALID_HANDLE;
    m_alligator_handle = m_ao_handle = INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| Деструктор                                                       |
//+------------------------------------------------------------------+
CAdvancedAnalyzer::~CAdvancedAnalyzer()
{
    Deinitialize();
}

//+------------------------------------------------------------------+
//| Инициализация                                                    |
//+------------------------------------------------------------------+
bool CAdvancedAnalyzer::Initialize(string symbol, ENUM_TIMEFRAMES timeframe)
{
    m_symbol = symbol;
    m_timeframe = timeframe;
    
    return InitializeIndicators();
}

//+------------------------------------------------------------------+
//| Инициализация индикаторов                                        |
//+------------------------------------------------------------------+
bool CAdvancedAnalyzer::InitializeIndicators()
{
    //--- RSI
    m_rsi_handle = iRSI(m_symbol, m_timeframe, 14, PRICE_CLOSE);
    if(m_rsi_handle == INVALID_HANDLE) return false;
    
    //--- MACD
    m_macd_handle = iMACD(m_symbol, m_timeframe, 12, 26, 9, PRICE_CLOSE);
    if(m_macd_handle == INVALID_HANDLE) return false;
    
    //--- ATR
    m_atr_handle = iATR(m_symbol, m_timeframe, 14);
    if(m_atr_handle == INVALID_HANDLE) return false;
    
    //--- Bollinger Bands
    m_bb_handle = iBands(m_symbol, m_timeframe, 20, 0, 2.0, PRICE_CLOSE);
    if(m_bb_handle == INVALID_HANDLE) return false;
    
    //--- EMA
    m_ema1_handle = iMA(m_symbol, m_timeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
    m_ema2_handle = iMA(m_symbol, m_timeframe, 100, 0, MODE_EMA, PRICE_CLOSE);
    m_ema3_handle = iMA(m_symbol, m_timeframe, 200, 0, MODE_EMA, PRICE_CLOSE);
    if(m_ema1_handle == INVALID_HANDLE || m_ema2_handle == INVALID_HANDLE || m_ema3_handle == INVALID_HANDLE) return false;
    
    //--- Stochastic
    m_stoch_handle = iStochastic(m_symbol, m_timeframe, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
    if(m_stoch_handle == INVALID_HANDLE) return false;
    
    //--- MFI
    m_mfi_handle = iMFI(m_symbol, m_timeframe, 14, PRICE_TYPICAL);
    if(m_mfi_handle == INVALID_HANDLE) return false;
    
    //--- OBV
    m_obv_handle = iOBV(m_symbol, m_timeframe, PRICE_CLOSE);
    if(m_obv_handle == INVALID_HANDLE) return false;
    
    //--- ZigZag
    m_zigzag_handle = iCustom(m_symbol, m_timeframe, "Examples\\ZigZag", 12, 5, 3);
    if(m_zigzag_handle == INVALID_HANDLE) return false;
    
    //--- Fractals
    m_fractal_handle = iFractals(m_symbol, m_timeframe);
    if(m_fractal_handle == INVALID_HANDLE) return false;
    
    //--- Ichimoku
    m_ichimoku_handle = iIchimoku(m_symbol, m_timeframe, 9, 26, 52);
    if(m_ichimoku_handle == INVALID_HANDLE) return false;
    
    //--- Parabolic SAR
    m_sar_handle = iSAR(m_symbol, m_timeframe, 0.02, 0.2);
    if(m_sar_handle == INVALID_HANDLE) return false;
    
    //--- Williams %R
    m_williams_handle = iWPR(m_symbol, m_timeframe, 14);
    if(m_williams_handle == INVALID_HANDLE) return false;
    
    //--- CCI
    m_cci_handle = iCCI(m_symbol, m_timeframe, 14, PRICE_TYPICAL);
    if(m_cci_handle == INVALID_HANDLE) return false;
    
    //--- Alligator
    m_alligator_handle = iAlligator(m_symbol, m_timeframe, 13, 8, 8, 5, 5, 3, MODE_SMMA, PRICE_MEDIAN);
    if(m_alligator_handle == INVALID_HANDLE) return false;
    
    //--- Awesome Oscillator
    m_ao_handle = iAO(m_symbol, m_timeframe);
    if(m_ao_handle == INVALID_HANDLE) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Деинициализация                                                  |
//+------------------------------------------------------------------+
void CAdvancedAnalyzer::Deinitialize()
{
    if(m_rsi_handle != INVALID_HANDLE) { IndicatorRelease(m_rsi_handle); m_rsi_handle = INVALID_HANDLE; }
    if(m_macd_handle != INVALID_HANDLE) { IndicatorRelease(m_macd_handle); m_macd_handle = INVALID_HANDLE; }
    if(m_atr_handle != INVALID_HANDLE) { IndicatorRelease(m_atr_handle); m_atr_handle = INVALID_HANDLE; }
    if(m_bb_handle != INVALID_HANDLE) { IndicatorRelease(m_bb_handle); m_bb_handle = INVALID_HANDLE; }
    if(m_ema1_handle != INVALID_HANDLE) { IndicatorRelease(m_ema1_handle); m_ema1_handle = INVALID_HANDLE; }
    if(m_ema2_handle != INVALID_HANDLE) { IndicatorRelease(m_ema2_handle); m_ema2_handle = INVALID_HANDLE; }
    if(m_ema3_handle != INVALID_HANDLE) { IndicatorRelease(m_ema3_handle); m_ema3_handle = INVALID_HANDLE; }
    if(m_stoch_handle != INVALID_HANDLE) { IndicatorRelease(m_stoch_handle); m_stoch_handle = INVALID_HANDLE; }
    if(m_mfi_handle != INVALID_HANDLE) { IndicatorRelease(m_mfi_handle); m_mfi_handle = INVALID_HANDLE; }
    if(m_obv_handle != INVALID_HANDLE) { IndicatorRelease(m_obv_handle); m_obv_handle = INVALID_HANDLE; }
    if(m_zigzag_handle != INVALID_HANDLE) { IndicatorRelease(m_zigzag_handle); m_zigzag_handle = INVALID_HANDLE; }
    if(m_fractal_handle != INVALID_HANDLE) { IndicatorRelease(m_fractal_handle); m_fractal_handle = INVALID_HANDLE; }
    if(m_ichimoku_handle != INVALID_HANDLE) { IndicatorRelease(m_ichimoku_handle); m_ichimoku_handle = INVALID_HANDLE; }
    if(m_sar_handle != INVALID_HANDLE) { IndicatorRelease(m_sar_handle); m_sar_handle = INVALID_HANDLE; }
    if(m_williams_handle != INVALID_HANDLE) { IndicatorRelease(m_williams_handle); m_williams_handle = INVALID_HANDLE; }
    if(m_cci_handle != INVALID_HANDLE) { IndicatorRelease(m_cci_handle); m_cci_handle = INVALID_HANDLE; }
    if(m_alligator_handle != INVALID_HANDLE) { IndicatorRelease(m_alligator_handle); m_alligator_handle = INVALID_HANDLE; }
    if(m_ao_handle != INVALID_HANDLE) { IndicatorRelease(m_ao_handle); m_ao_handle = INVALID_HANDLE; }
}

//+------------------------------------------------------------------+
//| Расширенный анализ рынка                                         |
//+------------------------------------------------------------------+
AdvancedMarketAnalysis CAdvancedAnalyzer::PerformAdvancedAnalysis(int bar, int rates_total,
                                                                 const datetime &time[],
                                                                 const double &open[],
                                                                 const double &high[],
                                                                 const double &low[],
                                                                 const double &close[],
                                                                 const long &tick_volume[])
{
    AdvancedMarketAnalysis analysis;
    ZeroMemory(analysis);
    
    if(bar < 100) return analysis; // Недостаточно данных для анализа
    
    //--- Получение данных индикаторов
    if(!GetIndicatorData(rates_total)) return analysis;
    
    //--- Выполнение всех видов анализа
    analysis.trend_analysis = AnalyzeTrendAdvanced(bar);
    analysis.volatility_analysis = AnalyzeVolatilityAdvanced(bar);
    analysis.momentum_analysis = AnalyzeMomentumAdvanced(bar);
    analysis.volume_analysis = AnalyzeVolumeAdvanced(bar, tick_volume);
    analysis.support_resistance_analysis = AnalyzeSupportResistanceAdvanced(bar, high, low, close);
    analysis.fibonacci_analysis = AnalyzeFibonacciAdvanced(bar, high, low, close);
    analysis.pattern_analysis = AnalyzePatternsAdvanced(bar, open, high, low, close);
    analysis.market_structure_analysis = AnalyzeMarketStructure(bar, high, low, close);
    analysis.time_analysis = AnalyzeTimeFactors(bar, time);
    analysis.correlation_analysis = AnalyzeCorrelations(bar);
    
    //--- Расчет общей вероятности
    analysis.spike_probability = CalculateOverallProbability(analysis);
    analysis.confidence_level = CalculateConfidenceLevel(analysis);
    
    //--- Определение типа сигнала
    analysis.signal_type = DetermineAdvancedSignalType(analysis);
    analysis.signal_time = time[bar];
    
    //--- Описание сигнала
    analysis.signal_description = GenerateSignalDescription(analysis);
    
    //--- Детализированные данные
    analysis.rsi_value = m_rsi_values[bar];
    analysis.macd_value = m_macd_main[bar];
    analysis.atr_value = m_atr_values[bar];
    analysis.bb_position = (close[bar] - m_bb_lower[bar]) / (m_bb_upper[bar] - m_bb_lower[bar]);
    analysis.ema_alignment = CalculateEMAAlignment(bar);
    analysis.volume_ratio = CalculateVolumeRatio(bar, tick_volume);
    analysis.price_position = CalculatePricePosition(bar, high, low, close);
    analysis.time_factor = CalculateTimeFactor(bar, time);
    
    return analysis;
}

//+------------------------------------------------------------------+
//| Получение данных индикаторов                                     |
//+------------------------------------------------------------------+
bool CAdvancedAnalyzer::GetIndicatorData(int rates_total)
{
    //--- RSI
    if(CopyBuffer(m_rsi_handle, 0, 0, rates_total, m_rsi_values) <= 0) return false;
    
    //--- MACD
    if(CopyBuffer(m_macd_handle, 0, 0, rates_total, m_macd_main) <= 0) return false;
    if(CopyBuffer(m_macd_handle, 1, 0, rates_total, m_macd_signal) <= 0) return false;
    
    //--- ATR
    if(CopyBuffer(m_atr_handle, 0, 0, rates_total, m_atr_values) <= 0) return false;
    
    //--- Bollinger Bands
    if(CopyBuffer(m_bb_handle, 0, 0, rates_total, m_bb_upper) <= 0) return false;
    if(CopyBuffer(m_bb_handle, 1, 0, rates_total, m_bb_middle) <= 0) return false;
    if(CopyBuffer(m_bb_handle, 2, 0, rates_total, m_bb_lower) <= 0) return false;
    
    //--- EMA
    if(CopyBuffer(m_ema1_handle, 0, 0, rates_total, m_ema1_values) <= 0) return false;
    if(CopyBuffer(m_ema2_handle, 0, 0, rates_total, m_ema2_values) <= 0) return false;
    if(CopyBuffer(m_ema3_handle, 0, 0, rates_total, m_ema3_values) <= 0) return false;
    
    //--- Stochastic
    if(CopyBuffer(m_stoch_handle, 0, 0, rates_total, m_stoch_main) <= 0) return false;
    if(CopyBuffer(m_stoch_handle, 1, 0, rates_total, m_stoch_signal) <= 0) return false;
    
    //--- MFI
    if(CopyBuffer(m_mfi_handle, 0, 0, rates_total, m_mfi_values) <= 0) return false;
    
    //--- OBV
    if(CopyBuffer(m_obv_handle, 0, 0, rates_total, m_obv_values) <= 0) return false;
    
    //--- ZigZag
    if(CopyBuffer(m_zigzag_handle, 0, 0, rates_total, m_zigzag_values) <= 0) return false;
    
    //--- Fractals
    if(CopyBuffer(m_fractal_handle, 0, 0, rates_total, m_fractal_values) <= 0) return false;
    
    //--- Ichimoku
    if(CopyBuffer(m_ichimoku_handle, 0, 0, rates_total, m_ichimoku_tenkan) <= 0) return false;
    if(CopyBuffer(m_ichimoku_handle, 1, 0, rates_total, m_ichimoku_kijun) <= 0) return false;
    if(CopyBuffer(m_ichimoku_handle, 2, 0, rates_total, m_ichimoku_senkou_a) <= 0) return false;
    if(CopyBuffer(m_ichimoku_handle, 3, 0, rates_total, m_ichimoku_senkou_b) <= 0) return false;
    
    //--- Parabolic SAR
    if(CopyBuffer(m_sar_handle, 0, 0, rates_total, m_sar_values) <= 0) return false;
    
    //--- Williams %R
    if(CopyBuffer(m_williams_handle, 0, 0, rates_total, m_williams_values) <= 0) return false;
    
    //--- CCI
    if(CopyBuffer(m_cci_handle, 0, 0, rates_total, m_cci_values) <= 0) return false;
    
    //--- Alligator
    if(CopyBuffer(m_alligator_handle, 0, 0, rates_total, m_alligator_jaw) <= 0) return false;
    if(CopyBuffer(m_alligator_handle, 1, 0, rates_total, m_alligator_teeth) <= 0) return false;
    if(CopyBuffer(m_alligator_handle, 2, 0, rates_total, m_alligator_lips) <= 0) return false;
    
    //--- Awesome Oscillator
    if(CopyBuffer(m_ao_handle, 0, 0, rates_total, m_ao_values) <= 0) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Расширенный анализ тренда                                        |
//+------------------------------------------------------------------+
double CAdvancedAnalyzer::AnalyzeTrendAdvanced(int bar)
{
    if(bar < 10) return 0;
    
    double trend_score = 0;
    
    //--- Анализ EMA
    if(m_ema1_values[bar] > m_ema2_values[bar] && m_ema2_values[bar] > m_ema3_values[bar]) {
        trend_score += 0.2; // Восходящий тренд
    } else if(m_ema1_values[bar] < m_ema2_values[bar] && m_ema2_values[bar] < m_ema3_values[bar]) {
        trend_score -= 0.2; // Нисходящий тренд
    }
    
    //--- Анализ Ichimoku
    if(m_ichimoku_tenkan[bar] > m_ichimoku_kijun[bar]) {
        trend_score += 0.15;
    } else if(m_ichimoku_tenkan[bar] < m_ichimoku_kijun[bar]) {
        trend_score -= 0.15;
    }
    
    //--- Анализ Alligator
    if(m_alligator_lips[bar] > m_alligator_teeth[bar] && m_alligator_teeth[bar] > m_alligator_jaw[bar]) {
        trend_score += 0.1;
    } else if(m_alligator_lips[bar] < m_alligator_teeth[bar] && m_alligator_teeth[bar] < m_alligator_jaw[bar]) {
        trend_score -= 0.1;
    }
    
    //--- Анализ Parabolic SAR
    if(m_sar_values[bar] < 0) { // Восходящий тренд
        trend_score += 0.1;
    } else if(m_sar_values[bar] > 0) { // Нисходящий тренд
        trend_score -= 0.1;
    }
    
    //--- Анализ Awesome Oscillator
    if(m_ao_values[bar] > m_ao_values[bar-1] && m_ao_values[bar] > 0) {
        trend_score += 0.1;
    } else if(m_ao_values[bar] < m_ao_values[bar-1] && m_ao_values[bar] < 0) {
        trend_score -= 0.1;
    }
    
    return MathMax(-1, MathMin(1, trend_score));
}

//+------------------------------------------------------------------+
//| Расширенный анализ волатильности                                 |
//+------------------------------------------------------------------+
double CAdvancedAnalyzer::AnalyzeVolatilityAdvanced(int bar)
{
    if(bar < 20) return 0;
    
    double volatility_score = 0;
    
    //--- ATR анализ
    double atr_current = m_atr_values[bar];
    double atr_avg = 0;
    for(int i = 0; i < 20; i++) {
        atr_avg += m_atr_values[bar - i];
    }
    atr_avg /= 20;
    
    if(atr_current > atr_avg * 1.5) {
        volatility_score += 0.4; // Высокая волатильность
    } else if(atr_current < atr_avg * 0.7) {
        volatility_score -= 0.3; // Низкая волатильность
    }
    
    //--- Bollinger Bands анализ
    double bb_width = (m_bb_upper[bar] - m_bb_lower[bar]) / m_bb_middle[bar];
    if(bb_width > 0.03) { // Широкие полосы
        volatility_score += 0.3;
    } else if(bb_width < 0.01) { // Узкие полосы
        volatility_score -= 0.2;
    }
    
    //--- Анализ сжатия Bollinger Bands
    double bb_width_prev = (m_bb_upper[bar-5] - m_bb_lower[bar-5]) / m_bb_middle[bar-5];
    if(bb_width < bb_width_prev * 0.8) {
        volatility_score += 0.3; // Сжатие полос - предвестник волатильности
    }
    
    return MathMax(-1, MathMin(1, volatility_score));
}

//+------------------------------------------------------------------+
//| Расширенный анализ моментума                                     |
//+------------------------------------------------------------------+
double CAdvancedAnalyzer::AnalyzeMomentumAdvanced(int bar)
{
    if(bar < 10) return 0;
    
    double momentum_score = 0;
    
    //--- RSI анализ
    if(m_rsi_values[bar] > 70) {
        momentum_score += 0.2; // Перекупленность
    } else if(m_rsi_values[bar] < 30) {
        momentum_score -= 0.2; // Перепроданность
    }
    
    //--- Stochastic анализ
    if(m_stoch_main[bar] > 80 && m_stoch_signal[bar] > 80) {
        momentum_score += 0.15;
    } else if(m_stoch_main[bar] < 20 && m_stoch_signal[bar] < 20) {
        momentum_score -= 0.15;
    }
    
    //--- Williams %R анализ
    if(m_williams_values[bar] > -20) {
        momentum_score += 0.1;
    } else if(m_williams_values[bar] < -80) {
        momentum_score -= 0.1;
    }
    
    //--- CCI анализ
    if(m_cci_values[bar] > 100) {
        momentum_score += 0.1;
    } else if(m_cci_values[bar] < -100) {
        momentum_score -= 0.1;
    }
    
    //--- MACD анализ
    if(m_macd_main[bar] > 0 && m_macd_main[bar] > m_macd_main[bar-1]) {
        momentum_score += 0.15;
    } else if(m_macd_main[bar] < 0 && m_macd_main[bar] < m_macd_main[bar-1]) {
        momentum_score -= 0.15;
    }
    
    //--- Анализ дивергенций
    double rsi_divergence = CalculateRSIDivergence(bar, NULL);
    double macd_divergence = CalculateMACDDivergence(bar, NULL);
    
    momentum_score += rsi_divergence * 0.1;
    momentum_score += macd_divergence * 0.1;
    
    return MathMax(-1, MathMin(1, momentum_score));
}

//+------------------------------------------------------------------+
//| Расширенный анализ объемов                                       |
//+------------------------------------------------------------------+
double CAdvancedAnalyzer::AnalyzeVolumeAdvanced(int bar, const long &tick_volume[])
{
    if(bar < 20) return 0;
    
    double volume_score = 0;
    
    //--- Анализ текущего объема относительно среднего
    long current_volume = tick_volume[bar];
    long avg_volume = 0;
    for(int i = 1; i <= 20; i++) {
        avg_volume += tick_volume[bar - i];
    }
    avg_volume /= 20;
    
    if(current_volume > avg_volume * 2.0) {
        volume_score += 0.4; // Очень высокий объем
    } else if(current_volume > avg_volume * 1.5) {
        volume_score += 0.2; // Высокий объем
    } else if(current_volume < avg_volume * 0.5) {
        volume_score -= 0.2; // Низкий объем
    }
    
    //--- MFI анализ
    if(m_mfi_values[bar] > 80) {
        volume_score += 0.2;
    } else if(m_mfi_values[bar] < 20) {
        volume_score -= 0.2;
    }
    
    //--- OBV анализ
    if(m_obv_values[bar] > m_obv_values[bar-1]) {
        volume_score += 0.1;
    } else if(m_obv_values[bar] < m_obv_values[bar-1]) {
        volume_score -= 0.1;
    }
    
    //--- Анализ профиля объемов
    double volume_profile = CalculateVolumeProfile(bar, tick_volume);
    volume_score += volume_profile * 0.2;
    
    return MathMax(-1, MathMin(1, volume_score));
}

//+------------------------------------------------------------------+
//| Расширенный анализ поддержки/сопротивления                      |
//+------------------------------------------------------------------+
double CAdvancedAnalyzer::AnalyzeSupportResistanceAdvanced(int bar, const double &high[], const double &low[], const double &close[])
{
    if(bar < 50) return 0;
    
    double sr_score = 0;
    
    //--- Поиск ключевых уровней
    double key_levels = FindKeyLevels(bar, high, low, close);
    sr_score += key_levels * 0.3;
    
    //--- Анализ фракталов
    if(m_fractal_values[bar] > 0) {
        double fractal_strength = CalculateLevelStrength(high[bar], bar, high, low, close);
        sr_score += fractal_strength * 0.2;
    }
    
    //--- Анализ ZigZag
    if(m_zigzag_values[bar] > 0) {
        double zigzag_strength = CalculateLevelStrength(m_zigzag_values[bar], bar, high, low, close);
        sr_score += zigzag_strength * 0.2;
    }
    
    //--- Анализ близости к уровням
    double current_price = close[bar];
    double level_proximity = 0;
    
    for(int i = 1; i <= 50; i++) {
        if(MathAbs(high[bar - i] - current_price) < 20 * _Point) {
            level_proximity += 0.1;
        }
        if(MathAbs(low[bar - i] - current_price) < 20 * _Point) {
            level_proximity += 0.1;
        }
    }
    
    sr_score += MathMin(1.0, level_proximity) * 0.3;
    
    return MathMax(-1, MathMin(1, sr_score));
}

//+------------------------------------------------------------------+
//| Расширенный анализ Фибоначчи                                     |
//+------------------------------------------------------------------+
double CAdvancedAnalyzer::AnalyzeFibonacciAdvanced(int bar, const double &high[], const double &low[], const double &close[])
{
    if(bar < 50) return 0;
    
    double fib_score = 0;
    
    //--- Поиск локального максимума и минимума за последние 50 баров
    double max_price = high[bar];
    double min_price = low[bar];
    int max_bar = bar;
    int min_bar = bar;
    
    for(int i = 1; i <= 50; i++) {
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
    if(range < 10 * _Point) return 0; // Слишком малый диапазон
    
    double fib_levels[8] = {0.236, 0.382, 0.500, 0.618, 0.764, 1.0, 1.272, 1.618};
    double fib_prices[8];
    
    for(int i = 0; i < 8; i++) {
        fib_prices[i] = max_price - range * fib_levels[i];
    }
    
    double current_price = close[bar];
    
    //--- Проверка близости к уровням Фибоначчи
    for(int i = 0; i < 8; i++) {
        double distance = MathAbs(current_price - fib_prices[i]);
        if(distance < 10 * _Point) {
            fib_score += 0.2; // Близко к уровню Фибоначчи
        } else if(distance < 20 * _Point) {
            fib_score += 0.1; // Умеренно близко к уровню
        }
    }
    
    //--- Анализ отскоков от уровней Фибоначчи
    for(int i = 1; i <= 10; i++) {
        for(int j = 0; j < 8; j++) {
            if(MathAbs(close[bar - i] - fib_prices[j]) < 5 * _Point) {
                fib_score += 0.05; // Исторические отскоки
            }
        }
    }
    
    return MathMax(-1, MathMin(1, fib_score));
}

//+------------------------------------------------------------------+
//| Расширенный анализ паттернов                                     |
//+------------------------------------------------------------------+
double CAdvancedAnalyzer::AnalyzePatternsAdvanced(int bar, const double &open[], const double &high[], const double &low[], const double &close[])
{
    if(bar < 20) return 0;
    
    double pattern_score = 0;
    
    //--- Анализ свечных паттернов
    double candlestick_patterns = DetectCandlestickPatterns(bar, open, high, low, close);
    pattern_score += candlestick_patterns * 0.4;
    
    //--- Анализ графических паттернов
    double chart_patterns = DetectChartPatterns(bar, high, low, close);
    pattern_score += chart_patterns * 0.3;
    
    //--- Анализ гармонических паттернов
    double harmonic_patterns = DetectHarmonicPatterns(bar, high, low, close);
    pattern_score += harmonic_patterns * 0.3;
    
    return MathMax(-1, MathMin(1, pattern_score));
}

//+------------------------------------------------------------------+
//| Анализ структуры рынка                                           |
//+------------------------------------------------------------------+
double CAdvancedAnalyzer::AnalyzeMarketStructure(int bar, const double &high[], const double &low[], const double &close[])
{
    if(bar < 30) return 0;
    
    double structure_score = 0;
    
    //--- Анализ высших максимумов и минимумов
    int higher_highs = 0;
    int lower_lows = 0;
    
    for(int i = 1; i <= 30; i++) {
        if(high[bar] > high[bar - i]) higher_highs++;
        if(low[bar] < low[bar - i]) lower_lows++;
    }
    
    if(higher_highs > 20) {
        structure_score += 0.3; // Сильная восходящая структура
    } else if(lower_lows > 20) {
        structure_score -= 0.3; // Сильная нисходящая структура
    }
    
    //--- Анализ микроструктуры
    double microstructure = CalculateMarketMicrostructure(bar, high, low, close);
    structure_score += microstructure * 0.4;
    
    //--- Анализ ценового действия
    double price_action = CalculatePriceAction(bar, NULL, high, low, close);
    structure_score += price_action * 0.3;
    
    return MathMax(-1, MathMin(1, structure_score));
}

//+------------------------------------------------------------------+
//| Анализ временных факторов                                        |
//+------------------------------------------------------------------+
double CAdvancedAnalyzer::AnalyzeTimeFactors(int bar, const datetime &time[])
{
    if(bar < 10) return 0;
    
    double time_score = 0;
    
    //--- Анализ времени дня
    MqlDateTime dt;
    TimeToStruct(time[bar], dt);
    
    //--- Азиатская сессия (низкая волатильность)
    if(dt.hour >= 0 && dt.hour < 8) {
        time_score -= 0.1;
    }
    //--- Европейская сессия (высокая волатильность)
    else if(dt.hour >= 8 && dt.hour < 16) {
        time_score += 0.2;
    }
    //--- Американская сессия (максимальная волатильность)
    else if(dt.hour >= 16 && dt.hour < 24) {
        time_score += 0.3;
    }
    
    //--- Анализ дня недели
    if(dt.day_of_week == 1) { // Понедельник
        time_score -= 0.1;
    } else if(dt.day_of_week == 5) { // Пятница
        time_score -= 0.1;
    }
    
    //--- Анализ времени до закрытия
    double time_factor = CalculateTimeFactor(bar, time);
    time_score += time_factor * 0.2;
    
    return MathMax(-1, MathMin(1, time_score));
}

//+------------------------------------------------------------------+
//| Анализ корреляций                                                |
//+------------------------------------------------------------------+
double CAdvancedAnalyzer::AnalyzeCorrelations(int bar)
{
    if(bar < 20) return 0;
    
    double correlation_score = 0;
    
    //--- Корреляция между RSI и ценой
    double rsi_price_corr = 0;
    for(int i = 0; i < 20; i++) {
        if(m_rsi_values[bar - i] > m_rsi_values[bar - i - 1]) {
            rsi_price_corr += 1;
        } else {
            rsi_price_corr -= 1;
        }
    }
    correlation_score += (rsi_price_corr / 20) * 0.2;
    
    //--- Корреляция между MACD и ценой
    double macd_price_corr = 0;
    for(int i = 0; i < 20; i++) {
        if(m_macd_main[bar - i] > m_macd_main[bar - i - 1]) {
            macd_price_corr += 1;
        } else {
            macd_price_corr -= 1;
        }
    }
    correlation_score += (macd_price_corr / 20) * 0.2;
    
    //--- Корреляция между объемом и ценой
    double volume_price_corr = 0;
    for(int i = 0; i < 20; i++) {
        if(m_obv_values[bar - i] > m_obv_values[bar - i - 1]) {
            volume_price_corr += 1;
        } else {
            volume_price_corr -= 1;
        }
    }
    correlation_score += (volume_price_corr / 20) * 0.2;
    
    return MathMax(-1, MathMin(1, correlation_score));
}

//+------------------------------------------------------------------+
//| Расчет общей вероятности                                         |
//+------------------------------------------------------------------+
double CalculateOverallProbability(const AdvancedMarketAnalysis &analysis)
{
    double probability = 0;
    
    //--- Взвешенная сумма всех факторов
    probability += analysis.trend_analysis * 0.20;
    probability += analysis.volatility_analysis * 0.15;
    probability += analysis.momentum_analysis * 0.15;
    probability += analysis.volume_analysis * 0.15;
    probability += analysis.support_resistance_analysis * 0.10;
    probability += analysis.fibonacci_analysis * 0.10;
    probability += analysis.pattern_analysis * 0.10;
    probability += analysis.market_structure_analysis * 0.05;
    probability += analysis.time_analysis * 0.05;
    probability += analysis.correlation_analysis * 0.05;
    
    //--- Нормализация к диапазону 0-1
    return (probability + 1) / 2;
}

//+------------------------------------------------------------------+
//| Расчет уровня уверенности                                        |
//+------------------------------------------------------------------+
double CalculateConfidenceLevel(const AdvancedMarketAnalysis &analysis)
{
    double confidence = 0;
    
    //--- Анализ согласованности сигналов
    int positive_signals = 0;
    int negative_signals = 0;
    
    if(analysis.trend_analysis > 0.1) positive_signals++; else if(analysis.trend_analysis < -0.1) negative_signals++;
    if(analysis.momentum_analysis > 0.1) positive_signals++; else if(analysis.momentum_analysis < -0.1) negative_signals++;
    if(analysis.volume_analysis > 0.1) positive_signals++; else if(analysis.volume_analysis < -0.1) negative_signals++;
    if(analysis.pattern_analysis > 0.1) positive_signals++; else if(analysis.pattern_analysis < -0.1) negative_signals++;
    
    int total_signals = positive_signals + negative_signals;
    if(total_signals > 0) {
        confidence = MathMax(positive_signals, negative_signals) / (double)total_signals;
    }
    
    return confidence;
}

//+------------------------------------------------------------------+
//| Определение типа сигнала                                         |
//+------------------------------------------------------------------+
int DetermineAdvancedSignalType(const AdvancedMarketAnalysis &analysis)
{
    //--- Проверка на Boom (рост)
    if(analysis.trend_analysis > 0.2 && 
       analysis.momentum_analysis > 0.15 && 
       analysis.volume_analysis > 0.1 &&
       analysis.confidence_level > 0.6) {
        return 1; // Boom
    }
    
    //--- Проверка на Crash (падение)
    if(analysis.trend_analysis < -0.2 && 
       analysis.momentum_analysis < -0.15 && 
       analysis.volume_analysis > 0.1 &&
       analysis.confidence_level > 0.6) {
        return -1; // Crash
    }
    
    return 0; // Нет сигнала
}

//+------------------------------------------------------------------+
//| Генерация описания сигнала                                       |
//+------------------------------------------------------------------+
string GenerateSignalDescription(const AdvancedMarketAnalysis &analysis)
{
    string description = "";
    
    if(analysis.signal_type == 1) {
        description = "🔵 BOOM SPIKE PREDICTED";
        if(analysis.trend_analysis > 0.3) description += " - Strong Uptrend";
        if(analysis.momentum_analysis > 0.2) description += " - High Momentum";
        if(analysis.volume_analysis > 0.2) description += " - High Volume";
    } else if(analysis.signal_type == -1) {
        description = "🔴 CRASH SPIKE PREDICTED";
        if(analysis.trend_analysis < -0.3) description += " - Strong Downtrend";
        if(analysis.momentum_analysis < -0.2) description += " - High Momentum";
        if(analysis.volume_analysis > 0.2) description += " - High Volume";
    }
    
    return description;
}

//+------------------------------------------------------------------+
//| Вспомогательные функции                                          |
//+------------------------------------------------------------------+

double CalculateRSIDivergence(int bar, const double &close[])
{
    // Простая реализация анализа дивергенции RSI
    if(bar < 10) return 0;
    
    double rsi_slope = m_rsi_values[bar] - m_rsi_values[bar-5];
    // Здесь должна быть логика сравнения с ценовым движением
    return rsi_slope * 0.1;
}

double CalculateMACDDivergence(int bar, const double &close[])
{
    // Простая реализация анализа дивергенции MACD
    if(bar < 10) return 0;
    
    double macd_slope = m_macd_main[bar] - m_macd_main[bar-5];
    // Здесь должна быть логика сравнения с ценовым движением
    return macd_slope * 0.1;
}

double CalculateVolumeProfile(int bar, const long &tick_volume[])
{
    // Простая реализация анализа профиля объемов
    if(bar < 10) return 0;
    
    long current_volume = tick_volume[bar];
    long avg_volume = 0;
    for(int i = 1; i <= 10; i++) {
        avg_volume += tick_volume[bar - i];
    }
    avg_volume /= 10;
    
    return (current_volume - avg_volume) / (double)avg_volume;
}

double CalculatePriceAction(int bar, const double &open[], const double &high[], const double &low[], const double &close[])
{
    // Простая реализация анализа ценового действия
    if(bar < 5) return 0;
    
    double price_action_score = 0;
    
    // Анализ свечных паттернов
    for(int i = 0; i < 5; i++) {
        if(close[bar - i] > open[bar - i]) {
            price_action_score += 0.1; // Бычья свеча
        } else {
            price_action_score -= 0.1; // Медвежья свеча
        }
    }
    
    return MathMax(-1, MathMin(1, price_action_score));
}

double CalculateMarketMicrostructure(int bar, const double &high[], const double &low[], const double &close[])
{
    // Простая реализация анализа микроструктуры
    if(bar < 10) return 0;
    
    double microstructure_score = 0;
    
    // Анализ спредов
    double avg_spread = 0;
    for(int i = 0; i < 10; i++) {
        avg_spread += (high[bar - i] - low[bar - i]);
    }
    avg_spread /= 10;
    
    double current_spread = high[bar] - low[bar];
    if(current_spread > avg_spread * 1.5) {
        microstructure_score += 0.3; // Высокая волатильность
    }
    
    return MathMax(-1, MathMin(1, microstructure_score));
}

double FindKeyLevels(int bar, const double &high[], const double &low[], const double &close[])
{
    // Простая реализация поиска ключевых уровней
    if(bar < 20) return 0;
    
    double level_score = 0;
    
    // Поиск повторяющихся уровней
    for(int i = 1; i <= 20; i++) {
        for(int j = i + 1; j <= 20; j++) {
            if(MathAbs(high[bar - i] - high[bar - j]) < 10 * _Point) {
                level_score += 0.1; // Найден повторяющийся уровень
            }
            if(MathAbs(low[bar - i] - low[bar - j]) < 10 * _Point) {
                level_score += 0.1; // Найден повторяющийся уровень
            }
        }
    }
    
    return MathMax(-1, MathMin(1, level_score));
}

double CalculateLevelStrength(double level, int bar, const double &high[], const double &low[], const double &close[])
{
    // Простая реализация расчета силы уровня
    if(bar < 10) return 0;
    
    double strength = 0;
    
    for(int i = 1; i <= 10; i++) {
        if(MathAbs(high[bar - i] - level) < 5 * _Point) {
            strength += 0.1; // Уровень был протестирован
        }
        if(MathAbs(low[bar - i] - level) < 5 * _Point) {
            strength += 0.1; // Уровень был протестирован
        }
    }
    
    return MathMax(0, MathMin(1, strength));
}

double DetectCandlestickPatterns(int bar, const double &open[], const double &high[], const double &low[], const double &close[])
{
    // Простая реализация детекции свечных паттернов
    if(bar < 3) return 0;
    
    double pattern_score = 0;
    
    // Hammer
    if(close[bar] > open[bar] && 
       (close[bar] - low[bar]) > 2 * (high[bar] - close[bar]) &&
       (open[bar] - low[bar]) > 2 * (high[bar] - open[bar])) {
        pattern_score += 0.3; // Бычий сигнал
    }
    
    // Shooting Star
    if(open[bar] > close[bar] && 
       (high[bar] - open[bar]) > 2 * (open[bar] - low[bar]) &&
       (high[bar] - close[bar]) > 2 * (close[bar] - low[bar])) {
        pattern_score -= 0.3; // Медвежий сигнал
    }
    
    return MathMax(-1, MathMin(1, pattern_score));
}

double DetectChartPatterns(int bar, const double &high[], const double &low[], const double &close[])
{
    // Простая реализация детекции графических паттернов
    if(bar < 10) return 0;
    
    double pattern_score = 0;
    
    // Простой анализ трендовых линий
    double trend_slope = (close[bar] - close[bar-10]) / 10;
    if(trend_slope > 0) {
        pattern_score += 0.2; // Восходящий тренд
    } else if(trend_slope < 0) {
        pattern_score -= 0.2; // Нисходящий тренд
    }
    
    return MathMax(-1, MathMin(1, pattern_score));
}

double DetectHarmonicPatterns(int bar, const double &high[], const double &low[], const double &close[])
{
    // Простая реализация детекции гармонических паттернов
    if(bar < 20) return 0;
    
    double pattern_score = 0;
    
    // Простой анализ волн Эллиотта
    double wave_analysis = 0;
    for(int i = 0; i < 20; i++) {
        if(close[bar - i] > close[bar - i - 1]) {
            wave_analysis += 0.05;
        } else {
            wave_analysis -= 0.05;
        }
    }
    
    pattern_score += wave_analysis;
    
    return MathMax(-1, MathMin(1, pattern_score));
}

double CalculateEMAAlignment(int bar)
{
    if(bar < 1) return 0;
    
    double alignment = 0;
    
    if(m_ema1_values[bar] > m_ema2_values[bar] && m_ema2_values[bar] > m_ema3_values[bar]) {
        alignment = 1; // Идеальное выравнивание вверх
    } else if(m_ema1_values[bar] < m_ema2_values[bar] && m_ema2_values[bar] < m_ema3_values[bar]) {
        alignment = -1; // Идеальное выравнивание вниз
    }
    
    return alignment;
}

double CalculateVolumeRatio(int bar, const long &tick_volume[])
{
    if(bar < 10) return 0;
    
    long current_volume = tick_volume[bar];
    long avg_volume = 0;
    for(int i = 1; i <= 10; i++) {
        avg_volume += tick_volume[bar - i];
    }
    avg_volume /= 10;
    
    return (current_volume - avg_volume) / (double)avg_volume;
}

double CalculatePricePosition(int bar, const double &high[], const double &low[], const double &close[])
{
    if(bar < 1) return 0;
    
    double current_price = close[bar];
    double range_high = high[bar];
    double range_low = low[bar];
    
    if(range_high - range_low < 1 * _Point) return 0;
    
    return (current_price - range_low) / (range_high - range_low);
}

double CalculateTimeFactor(int bar, const datetime &time[])
{
    if(bar < 1) return 0;
    
    // Простая реализация временного фактора
    MqlDateTime dt;
    TimeToStruct(time[bar], dt);
    
    double time_factor = 0;
    
    // Фактор времени дня
    if(dt.hour >= 8 && dt.hour <= 16) {
        time_factor += 0.5; // Рабочие часы
    }
    
    // Фактор дня недели
    if(dt.day_of_week >= 1 && dt.day_of_week <= 5) {
        time_factor += 0.3; // Рабочие дни
    }
    
    return MathMax(0, MathMin(1, time_factor));
}