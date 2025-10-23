//+------------------------------------------------------------------+
//|                                    CrashBoom_AdvancedAnalysis.mqh |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Расширенные функции анализа для индикатора CrashBoom            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Структура для хранения паттернов                                |
//+------------------------------------------------------------------+
struct PatternData {
    string name;
    double probability;
    int strength;
    datetime time;
    double price;
};

//+------------------------------------------------------------------+
//| Структура для анализа волн Эллиотта                             |
//+------------------------------------------------------------------+
struct ElliottWave {
    int wave_number;
    double start_price;
    double end_price;
    datetime start_time;
    datetime end_time;
    int degree;
    bool is_impulse;
};

//+------------------------------------------------------------------+
//| Класс для расширенного анализа                                  |
//+------------------------------------------------------------------+
class CAdvancedAnalysis
{
private:
    // Массивы для хранения данных
    double m_high[];
    double m_low[];
    double m_close[];
    double m_open[];
    datetime m_time[];
    
    // Массивы для паттернов
    PatternData m_patterns[100];
    ElliottWave m_elliott_waves[50];
    
    int m_pattern_count;
    int m_wave_count;
    
public:
    CAdvancedAnalysis();
    ~CAdvancedAnalysis();
    
    // Основные функции анализа
    bool InitializeAnalysis(const double &high[], const double &low[], 
                           const double &close[], const double &open[], 
                           const datetime &time[], int bars_total);
    
    // Анализ паттернов
    double AnalyzeCandlestickPatterns(int index);
    double AnalyzeChartPatterns(int index);
    double AnalyzeHarmonicPatterns(int index);
    
    // Анализ волн Эллиотта
    double AnalyzeElliottWaves(int index);
    bool IdentifyElliottWave(int index);
    
    // Анализ циклов
    double AnalyzeCycles(int index);
    double AnalyzeTimeCycles(int index);
    
    // Анализ корреляций
    double AnalyzeCorrelations(int index);
    double AnalyzeSeasonality(int index);
    
    // Машинное обучение
    double PredictWithML(int index);
    bool UpdateMLModel(int index, double actual_result);
    
    // Вспомогательные функции
    bool IsDoji(int index);
    bool IsHammer(int index);
    bool IsShootingStar(int index);
    bool IsEngulfing(int index);
    bool IsHarami(int index);
    bool IsMorningStar(int index);
    bool IsEveningStar(int index);
    
    // Анализ треугольников
    bool IsAscendingTriangle(int index);
    bool IsDescendingTriangle(int index);
    bool IsSymmetricalTriangle(int index);
    bool IsWedge(int index);
    
    // Анализ гармонических паттернов
    bool IsGartley(int index);
    bool IsButterfly(int index);
    bool IsBat(int index);
    bool IsCrab(int index);
    
    // Расчет уровней Фибоначчи
    double CalculateFibonacciRetracement(double high, double low, double level);
    double CalculateFibonacciExtension(double high, double low, double level);
    
    // Анализ объемного профиля
    double AnalyzeVolumeProfile(int index);
    double CalculatePOC(int index); // Point of Control
    double CalculateVAH(int index); // Value Area High
    double CalculateVAL(int index); // Value Area Low
};

//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
CAdvancedAnalysis::CAdvancedAnalysis()
{
    m_pattern_count = 0;
    m_wave_count = 0;
    ArrayResize(m_patterns, 100);
    ArrayResize(m_elliott_waves, 50);
}

//+------------------------------------------------------------------+
//| Деструктор                                                       |
//+------------------------------------------------------------------+
CAdvancedAnalysis::~CAdvancedAnalysis()
{
    ArrayFree(m_high);
    ArrayFree(m_low);
    ArrayFree(m_close);
    ArrayFree(m_open);
    ArrayFree(m_time);
}

//+------------------------------------------------------------------+
//| Инициализация анализа                                            |
//+------------------------------------------------------------------+
bool CAdvancedAnalysis::InitializeAnalysis(const double &high[], const double &low[], 
                                          const double &close[], const double &open[], 
                                          const datetime &time[], int bars_total)
{
    ArrayResize(m_high, bars_total);
    ArrayResize(m_low, bars_total);
    ArrayResize(m_close, bars_total);
    ArrayResize(m_open, bars_total);
    ArrayResize(m_time, bars_total);
    
    ArrayCopy(m_high, high);
    ArrayCopy(m_low, low);
    ArrayCopy(m_close, close);
    ArrayCopy(m_open, open);
    ArrayCopy(m_time, time);
    
    return true;
}

//+------------------------------------------------------------------+
//| Анализ свечных паттернов                                         |
//+------------------------------------------------------------------+
double CAdvancedAnalysis::AnalyzeCandlestickPatterns(int index)
{
    if(index < 3) return 0;
    
    double signal = 0;
    
    // Анализ отдельных свечей
    if(IsDoji(index)) signal += 0.1; // Неопределенность
    if(IsHammer(index)) signal += 0.2; // Бычий разворот
    if(IsShootingStar(index)) signal -= 0.2; // Медвежий разворот
    
    // Анализ комбинаций свечей
    if(IsEngulfing(index)) 
    {
        if(m_close[index] > m_open[index] && m_close[index-1] < m_open[index-1])
            signal += 0.3; // Бычье поглощение
        else if(m_close[index] < m_open[index] && m_close[index-1] > m_open[index-1])
            signal -= 0.3; // Медвежье поглощение
    }
    
    if(IsHarami(index))
    {
        if(m_close[index] > m_open[index] && m_close[index-1] < m_open[index-1])
            signal += 0.15; // Бычья харами
        else if(m_close[index] < m_open[index] && m_close[index-1] > m_open[index-1])
            signal -= 0.15; // Медвежья харами
    }
    
    if(IsMorningStar(index)) signal += 0.4; // Утренняя звезда
    if(IsEveningStar(index)) signal -= 0.4; // Вечерняя звезда
    
    return signal;
}

//+------------------------------------------------------------------+
//| Анализ графических паттернов                                     |
//+------------------------------------------------------------------+
double CAdvancedAnalysis::AnalyzeChartPatterns(int index)
{
    if(index < 20) return 0;
    
    double signal = 0;
    
    // Анализ треугольников
    if(IsAscendingTriangle(index)) signal += 0.3; // Бычий треугольник
    if(IsDescendingTriangle(index)) signal -= 0.3; // Медвежий треугольник
    if(IsSymmetricalTriangle(index)) signal += 0.1; // Нейтральный треугольник
    
    // Анализ клиньев
    if(IsWedge(index)) signal += 0.2; // Клинья часто предшествуют разворотам
    
    return signal;
}

//+------------------------------------------------------------------+
//| Анализ гармонических паттернов                                   |
//+------------------------------------------------------------------+
double CAdvancedAnalysis::AnalyzeHarmonicPatterns(int index)
{
    if(index < 50) return 0;
    
    double signal = 0;
    
    // Анализ гармонических паттернов
    if(IsGartley(index)) signal += 0.4; // Гартли
    if(IsButterfly(index)) signal += 0.3; // Бабочка
    if(IsBat(index)) signal += 0.35; // Летучая мышь
    if(IsCrab(index)) signal += 0.4; // Краб
    
    return signal;
}

//+------------------------------------------------------------------+
//| Анализ волн Эллиотта                                             |
//+------------------------------------------------------------------+
double CAdvancedAnalysis::AnalyzeElliottWaves(int index)
{
    if(index < 50) return 0;
    
    double signal = 0;
    
    // Поиск волн Эллиотта
    if(IdentifyElliottWave(index))
    {
        // Анализ текущей волны
        if(m_wave_count > 0)
        {
            ElliottWave current_wave = m_elliott_waves[m_wave_count - 1];
            
            // Волны 3 и 5 - импульсные
            if(current_wave.wave_number == 3 || current_wave.wave_number == 5)
            {
                if(current_wave.is_impulse)
                    signal += 0.5; // Сильный импульс
            }
            
            // Волны 2 и 4 - коррекционные
            if(current_wave.wave_number == 2 || current_wave.wave_number == 4)
            {
                signal += 0.2; // Возможный разворот
            }
        }
    }
    
    return signal;
}

//+------------------------------------------------------------------+
//| Идентификация волн Эллиотта                                      |
//+------------------------------------------------------------------+
bool CAdvancedAnalysis::IdentifyElliottWave(int index)
{
    if(index < 20) return false;
    
    // Упрощенная идентификация волн Эллиотта
    // Поиск локальных экстремумов
    double local_high = 0, local_low = DBL_MAX;
    int high_index = 0, low_index = 0;
    
    for(int i = index - 20; i < index; i++)
    {
        if(m_high[i] > local_high)
        {
            local_high = m_high[i];
            high_index = i;
        }
        if(m_low[i] < local_low)
        {
            local_low = m_low[i];
            low_index = i;
        }
    }
    
    // Определение типа волны
    if(high_index > low_index)
    {
        // Восходящая волна
        if(m_wave_count < 50)
        {
            m_elliott_waves[m_wave_count].wave_number = (m_wave_count % 5) + 1;
            m_elliott_waves[m_wave_count].start_price = local_low;
            m_elliott_waves[m_wave_count].end_price = local_high;
            m_elliott_waves[m_wave_count].start_time = m_time[low_index];
            m_elliott_waves[m_wave_count].end_time = m_time[high_index];
            m_elliott_waves[m_wave_count].degree = 1;
            m_elliott_waves[m_wave_count].is_impulse = (m_wave_count % 5 == 0 || m_wave_count % 5 == 2);
            m_wave_count++;
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Анализ циклов                                                    |
//+------------------------------------------------------------------+
double CAdvancedAnalysis::AnalyzeCycles(int index)
{
    if(index < 50) return 0;
    
    double signal = 0;
    
    // Анализ циклических паттернов
    double cycle_length = 0;
    double cycle_amplitude = 0;
    
    // Поиск повторяющихся паттернов
    for(int cycle = 5; cycle <= 20; cycle++)
    {
        if(index >= cycle * 2)
        {
            double correlation = 0;
            int matches = 0;
            
            for(int i = 0; i < cycle; i++)
            {
                if(index - cycle - i >= 0)
                {
                    double price_change1 = (m_close[index - i] - m_close[index - i - 1]) / m_close[index - i - 1];
                    double price_change2 = (m_close[index - cycle - i] - m_close[index - cycle - i - 1]) / m_close[index - cycle - i - 1];
                    
                    if(MathAbs(price_change1 - price_change2) < 0.01)
                    {
                        matches++;
                    }
                }
            }
            
            if(matches > cycle * 0.7) // 70% совпадений
            {
                signal += 0.3;
                break;
            }
        }
    }
    
    return signal;
}

//+------------------------------------------------------------------+
//| Анализ временных циклов                                          |
//+------------------------------------------------------------------+
double CAdvancedAnalysis::AnalyzeTimeCycles(int index)
{
    if(index < 20) return 0;
    
    double signal = 0;
    
    // Анализ времени дня
    MqlDateTime dt;
    TimeToStruct(m_time[index], dt);
    
    // Азиатская сессия (0-8 GMT)
    if(dt.hour >= 0 && dt.hour < 8)
    {
        signal += 0.1; // Низкая волатильность
    }
    // Европейская сессия (8-16 GMT)
    else if(dt.hour >= 8 && dt.hour < 16)
    {
        signal += 0.2; // Средняя волатильность
    }
    // Американская сессия (16-24 GMT)
    else if(dt.hour >= 16 && dt.hour < 24)
    {
        signal += 0.3; // Высокая волатильность
    }
    
    // Анализ дня недели
    if(dt.day_of_week == 1) // Понедельник
    {
        signal += 0.1; // Открытие недели
    }
    else if(dt.day_of_week == 5) // Пятница
    {
        signal += 0.2; // Закрытие недели
    }
    
    return signal;
}

//+------------------------------------------------------------------+
//| Анализ корреляций                                                |
//+------------------------------------------------------------------+
double CAdvancedAnalysis::AnalyzeCorrelations(int index)
{
    if(index < 30) return 0;
    
    double signal = 0;
    
    // Анализ корреляции с предыдущими движениями
    double current_trend = (m_close[index] - m_close[index-10]) / m_close[index-10];
    double previous_trend = (m_close[index-10] - m_close[index-20]) / m_close[index-20];
    
    double correlation = 0;
    if(previous_trend != 0)
    {
        correlation = current_trend / previous_trend;
    }
    
    // Положительная корреляция - продолжение тренда
    if(correlation > 0.5)
    {
        signal += 0.2;
    }
    // Отрицательная корреляция - возможный разворот
    else if(correlation < -0.5)
    {
        signal += 0.3;
    }
    
    return signal;
}

//+------------------------------------------------------------------+
//| Анализ сезонности                                                |
//+------------------------------------------------------------------+
double CAdvancedAnalysis::AnalyzeSeasonality(int index)
{
    if(index < 100) return 0;
    
    double signal = 0;
    
    MqlDateTime dt;
    TimeToStruct(m_time[index], dt);
    
    // Анализ по месяцам
    switch(dt.mon)
    {
        case 1:  // Январь
        case 2:  // Февраль
            signal += 0.1;
            break;
        case 3:  // Март
        case 4:  // Апрель
            signal += 0.2;
            break;
        case 5:  // Май
        case 6:  // Июнь
            signal += 0.15;
            break;
        case 7:  // Июль
        case 8:  // Август
            signal += 0.1;
            break;
        case 9:  // Сентябрь
        case 10: // Октябрь
            signal += 0.25;
            break;
        case 11: // Ноябрь
        case 12: // Декабрь
            signal += 0.2;
            break;
    }
    
    return signal;
}

//+------------------------------------------------------------------+
//| Предсказание с помощью машинного обучения                        |
//+------------------------------------------------------------------+
double CAdvancedAnalysis::PredictWithML(int index)
{
    if(index < 50) return 0;
    
    double prediction = 0;
    
    // Простая нейронная сеть (упрощенная)
    double inputs[10];
    
    // Подготовка входных данных
    inputs[0] = (m_close[index] - m_close[index-1]) / m_close[index-1]; // Изменение цены
    inputs[1] = (m_high[index] - m_low[index]) / m_close[index]; // Волатильность
    inputs[2] = (m_close[index] - m_close[index-5]) / m_close[index-5]; // 5-периодное изменение
    inputs[3] = (m_close[index] - m_close[index-10]) / m_close[index-10]; // 10-периодное изменение
    inputs[4] = (m_close[index] - m_close[index-20]) / m_close[index-20]; // 20-периодное изменение
    
    // Расчет средних
    double sma5 = 0, sma10 = 0, sma20 = 0;
    for(int i = 0; i < 5; i++) sma5 += m_close[index-i];
    for(int i = 0; i < 10; i++) sma10 += m_close[index-i];
    for(int i = 0; i < 20; i++) sma20 += m_close[index-i];
    
    inputs[5] = (m_close[index] - sma5/5) / (sma5/5);
    inputs[6] = (m_close[index] - sma10/10) / (sma10/10);
    inputs[7] = (m_close[index] - sma20/20) / (sma20/20);
    
    // Объем
    inputs[8] = (m_close[index] - m_open[index]) / m_open[index];
    inputs[9] = (m_high[index] - m_low[index]) / m_low[index];
    
    // Простая нейронная сеть (2 скрытых слоя)
    double hidden1[5], hidden2[3];
    
    // Первый скрытый слой
    for(int i = 0; i < 5; i++)
    {
        hidden1[i] = 0;
        for(int j = 0; j < 10; j++)
        {
            hidden1[i] += inputs[j] * (0.1 + i * 0.05); // Веса
        }
        hidden1[i] = 1.0 / (1.0 + MathExp(-hidden1[i])); // Сигмоида
    }
    
    // Второй скрытый слой
    for(int i = 0; i < 3; i++)
    {
        hidden2[i] = 0;
        for(int j = 0; j < 5; j++)
        {
            hidden2[i] += hidden1[j] * (0.1 + i * 0.1);
        }
        hidden2[i] = 1.0 / (1.0 + MathExp(-hidden2[i]));
    }
    
    // Выходной слой
    for(int i = 0; i < 3; i++)
    {
        prediction += hidden2[i] * (0.1 + i * 0.2);
    }
    
    return MathMax(-1, MathMin(1, prediction));
}

//+------------------------------------------------------------------+
//| Обновление модели машинного обучения                             |
//+------------------------------------------------------------------+
bool CAdvancedAnalysis::UpdateMLModel(int index, double actual_result)
{
    // Простое обновление весов на основе ошибки
    // В реальной реализации здесь был бы более сложный алгоритм обучения
    
    return true;
}

//+------------------------------------------------------------------+
//| Проверка на доджи                                                |
//+------------------------------------------------------------------+
bool CAdvancedAnalysis::IsDoji(int index)
{
    if(index < 0) return false;
    
    double body = MathAbs(m_close[index] - m_open[index]);
    double range = m_high[index] - m_low[index];
    
    return (body / range) < 0.1; // Тело менее 10% от диапазона
}

//+------------------------------------------------------------------+
//| Проверка на молот                                                |
//+------------------------------------------------------------------+
bool CAdvancedAnalysis::IsHammer(int index)
{
    if(index < 0) return false;
    
    double body = MathAbs(m_close[index] - m_open[index]);
    double lower_shadow = MathMin(m_close[index], m_open[index]) - m_low[index];
    double upper_shadow = m_high[index] - MathMax(m_close[index], m_open[index]);
    double range = m_high[index] - m_low[index];
    
    return (lower_shadow > body * 2) && (upper_shadow < body * 0.5) && (body / range > 0.1);
}

//+------------------------------------------------------------------+
//| Проверка на падающую звезду                                      |
//+------------------------------------------------------------------+
bool CAdvancedAnalysis::IsShootingStar(int index)
{
    if(index < 0) return false;
    
    double body = MathAbs(m_close[index] - m_open[index]);
    double lower_shadow = MathMin(m_close[index], m_open[index]) - m_low[index];
    double upper_shadow = m_high[index] - MathMax(m_close[index], m_open[index]);
    double range = m_high[index] - m_low[index];
    
    return (upper_shadow > body * 2) && (lower_shadow < body * 0.5) && (body / range > 0.1);
}

//+------------------------------------------------------------------+
//| Проверка на поглощение                                           |
//+------------------------------------------------------------------+
bool CAdvancedAnalysis::IsEngulfing(int index)
{
    if(index < 1) return false;
    
    double body1 = MathAbs(m_close[index-1] - m_open[index-1]);
    double body2 = MathAbs(m_close[index] - m_open[index]);
    
    if(body2 <= body1) return false;
    
    // Бычье поглощение
    if(m_close[index] > m_open[index] && m_close[index-1] < m_open[index-1])
    {
        return (m_open[index] < m_close[index-1]) && (m_close[index] > m_open[index-1]);
    }
    
    // Медвежье поглощение
    if(m_close[index] < m_open[index] && m_close[index-1] > m_open[index-1])
    {
        return (m_open[index] > m_close[index-1]) && (m_close[index] < m_open[index-1]);
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Проверка на харами                                               |
//+------------------------------------------------------------------+
bool CAdvancedAnalysis::IsHarami(int index)
{
    if(index < 1) return false;
    
    double body1 = MathAbs(m_close[index-1] - m_open[index-1]);
    double body2 = MathAbs(m_close[index] - m_open[index]);
    
    if(body2 >= body1) return false;
    
    // Бычья харами
    if(m_close[index] > m_open[index] && m_close[index-1] < m_open[index-1])
    {
        return (m_open[index] > m_close[index-1]) && (m_close[index] < m_open[index-1]);
    }
    
    // Медвежья харами
    if(m_close[index] < m_open[index] && m_close[index-1] > m_open[index-1])
    {
        return (m_open[index] < m_close[index-1]) && (m_close[index] > m_open[index-1]);
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Проверка на утреннюю звезду                                      |
//+------------------------------------------------------------------+
bool CAdvancedAnalysis::IsMorningStar(int index)
{
    if(index < 2) return false;
    
    // Первая свеча - медвежья
    bool first_bearish = m_close[index-2] < m_open[index-2];
    
    // Вторая свеча - маленькая (доджи или маленькое тело)
    double body2 = MathAbs(m_close[index-1] - m_open[index-1]);
    double range2 = m_high[index-1] - m_low[index-1];
    bool second_small = (body2 / range2) < 0.3;
    
    // Третья свеча - бычья
    bool third_bullish = m_close[index] > m_open[index];
    
    // Гэп между первой и второй свечами
    bool gap1 = m_low[index-1] > m_close[index-2];
    
    // Гэп между второй и третьей свечами
    bool gap2 = m_open[index] > m_high[index-1];
    
    return first_bearish && second_small && third_bullish && gap1 && gap2;
}

//+------------------------------------------------------------------+
//| Проверка на вечернюю звезду                                      |
//+------------------------------------------------------------------+
bool CAdvancedAnalysis::IsEveningStar(int index)
{
    if(index < 2) return false;
    
    // Первая свеча - бычья
    bool first_bullish = m_close[index-2] > m_open[index-2];
    
    // Вторая свеча - маленькая (доджи или маленькое тело)
    double body2 = MathAbs(m_close[index-1] - m_open[index-1]);
    double range2 = m_high[index-1] - m_low[index-1];
    bool second_small = (body2 / range2) < 0.3;
    
    // Третья свеча - медвежья
    bool third_bearish = m_close[index] < m_open[index];
    
    // Гэп между первой и второй свечами
    bool gap1 = m_high[index-1] < m_close[index-2];
    
    // Гэп между второй и третьей свечами
    bool gap2 = m_open[index] < m_low[index-1];
    
    return first_bullish && second_small && third_bearish && gap1 && gap2;
}

//+------------------------------------------------------------------+
//| Проверка на восходящий треугольник                               |
//+------------------------------------------------------------------+
bool CAdvancedAnalysis::IsAscendingTriangle(int index)
{
    if(index < 20) return false;
    
    // Поиск горизонтального сопротивления и восходящей поддержки
    double resistance_level = 0;
    double support_level = DBL_MAX;
    int resistance_touches = 0;
    int support_touches = 0;
    
    for(int i = index - 20; i < index; i++)
    {
        // Поиск уровня сопротивления
        if(m_high[i] > resistance_level)
        {
            resistance_level = m_high[i];
            resistance_touches = 1;
        }
        else if(MathAbs(m_high[i] - resistance_level) / resistance_level < 0.01)
        {
            resistance_touches++;
        }
        
        // Поиск уровня поддержки
        if(m_low[i] < support_level)
        {
            support_level = m_low[i];
            support_touches = 1;
        }
        else if(MathAbs(m_low[i] - support_level) / support_level < 0.01)
        {
            support_touches++;
        }
    }
    
    return (resistance_touches >= 2) && (support_touches >= 2) && (support_level < resistance_level);
}

//+------------------------------------------------------------------+
//| Проверка на нисходящий треугольник                               |
//+------------------------------------------------------------------+
bool CAdvancedAnalysis::IsDescendingTriangle(int index)
{
    if(index < 20) return false;
    
    // Поиск горизонтальной поддержки и нисходящего сопротивления
    double support_level = DBL_MAX;
    double resistance_level = 0;
    int support_touches = 0;
    int resistance_touches = 0;
    
    for(int i = index - 20; i < index; i++)
    {
        // Поиск уровня поддержки
        if(m_low[i] < support_level)
        {
            support_level = m_low[i];
            support_touches = 1;
        }
        else if(MathAbs(m_low[i] - support_level) / support_level < 0.01)
        {
            support_touches++;
        }
        
        // Поиск уровня сопротивления
        if(m_high[i] > resistance_level)
        {
            resistance_level = m_high[i];
            resistance_touches = 1;
        }
        else if(MathAbs(m_high[i] - resistance_level) / resistance_level < 0.01)
        {
            resistance_touches++;
        }
    }
    
    return (support_touches >= 2) && (resistance_touches >= 2) && (support_level < resistance_level);
}

//+------------------------------------------------------------------+
//| Проверка на симметричный треугольник                             |
//+------------------------------------------------------------------+
bool CAdvancedAnalysis::IsSymmetricalTriangle(int index)
{
    if(index < 20) return false;
    
    // Поиск сходящихся линий тренда
    double upper_slope = 0, lower_slope = 0;
    int upper_points = 0, lower_points = 0;
    
    // Упрощенная проверка
    double high1 = 0, high2 = 0, low1 = DBL_MAX, low2 = DBL_MAX;
    int high1_idx = 0, high2_idx = 0, low1_idx = 0, low2_idx = 0;
    
    for(int i = index - 20; i < index; i++)
    {
        if(m_high[i] > high1)
        {
            high2 = high1; high2_idx = high1_idx;
            high1 = m_high[i]; high1_idx = i;
        }
        else if(m_high[i] > high2)
        {
            high2 = m_high[i]; high2_idx = i;
        }
        
        if(m_low[i] < low1)
        {
            low2 = low1; low2_idx = low1_idx;
            low1 = m_low[i]; low1_idx = i;
        }
        else if(m_low[i] < low2)
        {
            low2 = m_low[i]; low2_idx = i;
        }
    }
    
    if(high1_idx != high2_idx && low1_idx != low2_idx)
    {
        upper_slope = (high1 - high2) / (high1_idx - high2_idx);
        lower_slope = (low1 - low2) / (low1_idx - low2_idx);
        
        return (upper_slope < 0) && (lower_slope > 0) && (MathAbs(upper_slope - lower_slope) < 0.1);
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Проверка на клин                                                 |
//+------------------------------------------------------------------+
bool CAdvancedAnalysis::IsWedge(int index)
{
    if(index < 20) return false;
    
    // Поиск сходящихся линий тренда с одинаковым наклоном
    double upper_slope = 0, lower_slope = 0;
    
    // Упрощенная проверка
    double high1 = 0, high2 = 0, low1 = DBL_MAX, low2 = DBL_MAX;
    int high1_idx = 0, high2_idx = 0, low1_idx = 0, low2_idx = 0;
    
    for(int i = index - 20; i < index; i++)
    {
        if(m_high[i] > high1)
        {
            high2 = high1; high2_idx = high1_idx;
            high1 = m_high[i]; high1_idx = i;
        }
        else if(m_high[i] > high2)
        {
            high2 = m_high[i]; high2_idx = i;
        }
        
        if(m_low[i] < low1)
        {
            low2 = low1; low2_idx = low1_idx;
            low1 = m_low[i]; low1_idx = i;
        }
        else if(m_low[i] < low2)
        {
            low2 = m_low[i]; low2_idx = i;
        }
    }
    
    if(high1_idx != high2_idx && low1_idx != low2_idx)
    {
        upper_slope = (high1 - high2) / (high1_idx - high2_idx);
        lower_slope = (low1 - low2) / (low1_idx - low2_idx);
        
        // Клинья имеют одинаковый знак наклона
        return (upper_slope * lower_slope > 0) && (MathAbs(upper_slope - lower_slope) < 0.2);
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Проверка на паттерн Гартли                                       |
//+------------------------------------------------------------------+
bool CAdvancedAnalysis::IsGartley(int index)
{
    if(index < 50) return false;
    
    // Поиск точек X, A, B, C, D для паттерна Гартли
    // Упрощенная реализация
    
    double x = 0, a = 0, b = 0, c = 0, d = 0;
    int x_idx = 0, a_idx = 0, b_idx = 0, c_idx = 0, d_idx = 0;
    
    // Поиск экстремумов за последние 50 баров
    for(int i = index - 50; i < index; i++)
    {
        if(m_high[i] > x) { x = m_high[i]; x_idx = i; }
        if(m_low[i] < a) { a = m_low[i]; a_idx = i; }
    }
    
    // Поиск промежуточных точек
    for(int i = x_idx; i < a_idx; i++)
    {
        if(m_high[i] > b) { b = m_high[i]; b_idx = i; }
    }
    
    for(int i = b_idx; i < a_idx; i++)
    {
        if(m_low[i] < c) { c = m_low[i]; c_idx = i; }
    }
    
    for(int i = c_idx; i < index; i++)
    {
        if(m_high[i] > d) { d = m_high[i]; d_idx = i; }
    }
    
    // Проверка соотношений Фибоначчи
    if(x_idx < a_idx && a_idx < b_idx && b_idx < c_idx && c_idx < d_idx)
    {
        double ab_ratio = (b - a) / (x - a);
        double bc_ratio = (c - b) / (b - a);
        double cd_ratio = (d - c) / (c - b);
        
        // Идеальные соотношения для Гартли: AB=0.618, BC=0.382-0.886, CD=1.27
        return (MathAbs(ab_ratio - 0.618) < 0.1) && 
               (bc_ratio >= 0.382 && bc_ratio <= 0.886) && 
               (MathAbs(cd_ratio - 1.27) < 0.2);
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Проверка на паттерн Бабочка                                      |
//+------------------------------------------------------------------+
bool CAdvancedAnalysis::IsButterfly(int index)
{
    if(index < 50) return false;
    
    // Аналогично Гартли, но с другими соотношениями
    // Упрощенная реализация
    return false; // Заглушка
}

//+------------------------------------------------------------------+
//| Проверка на паттерн Летучая мышь                                 |
//+------------------------------------------------------------------+
bool CAdvancedAnalysis::IsBat(int index)
{
    if(index < 50) return false;
    
    // Аналогично Гартли, но с другими соотношениями
    // Упрощенная реализация
    return false; // Заглушка
}

//+------------------------------------------------------------------+
//| Проверка на паттерн Краб                                         |
//+------------------------------------------------------------------+
bool CAdvancedAnalysis::IsCrab(int index)
{
    if(index < 50) return false;
    
    // Аналогично Гартли, но с другими соотношениями
    // Упрощенная реализация
    return false; // Заглушка
}

//+------------------------------------------------------------------+
//| Расчет уровня отката Фибоначчи                                   |
//+------------------------------------------------------------------+
double CAdvancedAnalysis::CalculateFibonacciRetracement(double high, double low, double level)
{
    return high - (high - low) * level;
}

//+------------------------------------------------------------------+
//| Расчет уровня расширения Фибоначчи                               |
//+------------------------------------------------------------------+
double CAdvancedAnalysis::CalculateFibonacciExtension(double high, double low, double level)
{
    return high + (high - low) * level;
}

//+------------------------------------------------------------------+
//| Анализ объемного профиля                                         |
//+------------------------------------------------------------------+
double CAdvancedAnalysis::AnalyzeVolumeProfile(int index)
{
    if(index < 20) return 0;
    
    double signal = 0;
    
    // Упрощенный анализ объемного профиля
    double total_volume = 0;
    double high_volume = 0;
    
    for(int i = index - 20; i < index; i++)
    {
        total_volume += m_high[i] - m_low[i];
        if(m_high[i] - m_low[i] > high_volume)
        {
            high_volume = m_high[i] - m_low[i];
        }
    }
    
    double avg_volume = total_volume / 20;
    if(high_volume > avg_volume * 1.5)
    {
        signal += 0.3; // Высокий объем
    }
    
    return signal;
}

//+------------------------------------------------------------------+
//| Расчет точки контроля (POC)                                      |
//+------------------------------------------------------------------+
double CAdvancedAnalysis::CalculatePOC(int index)
{
    if(index < 20) return 0;
    
    // Упрощенный расчет POC
    double total_range = 0;
    for(int i = index - 20; i < index; i++)
    {
        total_range += m_high[i] - m_low[i];
    }
    
    return total_range / 20;
}

//+------------------------------------------------------------------+
//| Расчет верхней границы области значений (VAH)                    |
//+------------------------------------------------------------------+
double CAdvancedAnalysis::CalculateVAH(int index)
{
    if(index < 20) return 0;
    
    double high = 0;
    for(int i = index - 20; i < index; i++)
    {
        if(m_high[i] > high) high = m_high[i];
    }
    
    return high * 0.8; // 80% от максимума
}

//+------------------------------------------------------------------+
//| Расчет нижней границы области значений (VAL)                     |
//+------------------------------------------------------------------+
double CAdvancedAnalysis::CalculateVAL(int index)
{
    if(index < 20) return 0;
    
    double low = DBL_MAX;
    for(int i = index - 20; i < index; i++)
    {
        if(m_low[i] < low) low = m_low[i];
    }
    
    return low * 1.2; // 120% от минимума
}

//+------------------------------------------------------------------+