//+------------------------------------------------------------------+
//|                                           CrashBoom_Simple.mq5   |
//|                  Упрощенная версия индикатора для Crash/Boom     |
//|                                        Готов для MetaEditor      |
//+------------------------------------------------------------------+
#property copyright "CrashBoom Predictor v1.0 Simple"
#property link      "https://deriv.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 2
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
input double SpikePredictionSensitivity = 65.0;  // Чувствительность (0-100)
input bool   EnableAlerts = true;                // Звуковые сигналы
input bool   ShowInfoPanel = true;               // Показать панель
input int    ArrowDistance = 20;                 // Расстояние стрелки от свечи

input group "=== Индикаторы ==="
input int    MA_Fast = 20;                       // Быстрая MA
input int    MA_Slow = 50;                       // Медленная MA
input int    RSI_Period = 14;                    // Период RSI
input int    ATR_Period = 14;                    // Период ATR

input group "=== MACD ==="
input int    MACD_Fast = 12;                     // MACD быстрая
input int    MACD_Slow = 26;                     // MACD медленная
input int    MACD_Signal = 9;                    // MACD сигнальная

//+------------------------------------------------------------------+
//| ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ                                            |
//+------------------------------------------------------------------+
double BuySignalBuffer[];
double SellSignalBuffer[];

// Хендлы индикаторов
int handle_MA_Fast, handle_MA_Slow;
int handle_RSI, handle_MACD, handle_ATR;

// Массивы для данных
double ma_fast[], ma_slow[];
double rsi_values[];
double macd_main[], macd_signal[];
double atr_values[];

// Переменные
datetime lastAlertTime = 0;
bool isCrashSymbol = false;

//+------------------------------------------------------------------+
//| Инициализация индикатора                                         |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Установка буферов индикатора
    SetIndexBuffer(0, BuySignalBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, SellSignalBuffer, INDICATOR_DATA);
    
    //--- Установка стрелок
    PlotIndexSetInteger(0, PLOT_ARROW, 233);  // Стрелка вверх
    PlotIndexSetInteger(1, PLOT_ARROW, 234);  // Стрелка вниз
    
    //--- Установка пустых значений
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
    
    //--- Определение типа символа
    string symbol = _Symbol;
    
    if(StringFind(symbol, "Crash") >= 0 || StringFind(symbol, "CRASH") >= 0)
        isCrashSymbol = true;
    else if(StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "BOOM") >= 0)
        isCrashSymbol = false;
    else
        Print("⚠️ Символ не распознан как Crash или Boom");
    
    //--- Инициализация индикаторов
    handle_MA_Fast = iMA(_Symbol, PERIOD_CURRENT, MA_Fast, 0, MODE_EMA, PRICE_CLOSE);
    handle_MA_Slow = iMA(_Symbol, PERIOD_CURRENT, MA_Slow, 0, MODE_EMA, PRICE_CLOSE);
    handle_RSI = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
    handle_MACD = iMACD(_Symbol, PERIOD_CURRENT, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
    handle_ATR = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
    
    if(handle_MA_Fast == INVALID_HANDLE || handle_RSI == INVALID_HANDLE) {
        Print("❌ Ошибка инициализации индикаторов!");
        return(INIT_FAILED);
    }
    
    //--- Установка массивов как серий
    ArraySetAsSeries(ma_fast, true);
    ArraySetAsSeries(ma_slow, true);
    ArraySetAsSeries(rsi_values, true);
    ArraySetAsSeries(macd_main, true);
    ArraySetAsSeries(macd_signal, true);
    ArraySetAsSeries(atr_values, true);
    
    //--- Создание информационной панели
    if(ShowInfoPanel) {
        CreateInfoPanel();
    }
    
    Print("✅ CrashBoom Simple загружен: ", symbol, " | Тип: ", isCrashSymbol ? "CRASH" : "BOOM");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Деинициализация индикатора                                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Освобождение хендлов
    if(handle_MA_Fast != INVALID_HANDLE) IndicatorRelease(handle_MA_Fast);
    if(handle_MA_Slow != INVALID_HANDLE) IndicatorRelease(handle_MA_Slow);
    if(handle_RSI != INVALID_HANDLE) IndicatorRelease(handle_RSI);
    if(handle_MACD != INVALID_HANDLE) IndicatorRelease(handle_MACD);
    if(handle_ATR != INVALID_HANDLE) IndicatorRelease(handle_ATR);
    
    //--- Удаление объектов
    ObjectsDeleteAll(0, "CBS_");
    
    Print("🔴 CrashBoom Simple выгружен");
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
    if(rates_total < MA_Slow + 10) {
        return(0);
    }
    
    //--- Определение начальной позиции
    int start_pos = prev_calculated > 0 ? prev_calculated - 1 : MA_Slow;
    
    //--- Основной цикл расчёта
    for(int i = start_pos; i < rates_total - 1; i++) 
    {
        //--- Сброс буферов
        BuySignalBuffer[i] = 0.0;
        SellSignalBuffer[i] = 0.0;
        
        //--- Копирование данных индикаторов
        if(CopyBuffer(handle_MA_Fast, 0, i, 1, ma_fast) <= 0) continue;
        if(CopyBuffer(handle_MA_Slow, 0, i, 1, ma_slow) <= 0) continue;
        if(CopyBuffer(handle_RSI, 0, i, 1, rsi_values) <= 0) continue;
        if(CopyBuffer(handle_MACD, 0, i, 1, macd_main) <= 0) continue;
        if(CopyBuffer(handle_MACD, 1, i, 1, macd_signal) <= 0) continue;
        if(CopyBuffer(handle_ATR, 0, i, 1, atr_values) <= 0) continue;
        
        //--- Анализ сигналов
        double signalStrength = 0.0;
        int direction = 0;  // 1 = Buy, -1 = Sell
        
        //--- 1. Анализ MA
        if(close[i] > ma_fast[0] && ma_fast[0] > ma_slow[0])
            signalStrength += 20.0;  // Восходящий тренд
        else if(close[i] < ma_fast[0] && ma_fast[0] < ma_slow[0])
            signalStrength -= 20.0;  // Нисходящий тренд
        
        //--- 2. Анализ RSI
        if(rsi_values[0] < 30)
            signalStrength += 25.0;  // Перепроданность
        else if(rsi_values[0] > 70)
            signalStrength -= 25.0;  // Перекупленность
        
        //--- 3. Анализ MACD
        if(macd_main[0] > macd_signal[0] && macd_main[0] > 0)
            signalStrength += 20.0;  // Бычий сигнал
        else if(macd_main[0] < macd_signal[0] && macd_main[0] < 0)
            signalStrength -= 20.0;  // Медвежий сигнал
        
        //--- 4. Анализ волатильности (ATR)
        double atr_threshold = atr_values[0] * 2.0;
        double price_range = high[i] - low[i];
        
        if(price_range > atr_threshold)
            signalStrength += 15.0;  // Высокая волатильность
        
        //--- Определение направления
        if(signalStrength > 0) {
            direction = 1;  // Buy
        } else if(signalStrength < 0) {
            direction = -1; // Sell
        }
        
        //--- Нормализация силы сигнала (0-100)
        double normalizedStrength = MathAbs(signalStrength);
        
        //--- Проверка порога чувствительности
        if(normalizedStrength >= SpikePredictionSensitivity) 
        {
            //--- Для Crash - импульсы вниз
            if(isCrashSymbol && direction == -1) {
                SellSignalBuffer[i] = high[i] + ArrowDistance * _Point;
                
                // Уведомление (только для текущей свечи)
                if(i == rates_total - 2 && time[i] != lastAlertTime) {
                    SendAlert("CRASH SELL", normalizedStrength, time[i]);
                    lastAlertTime = time[i];
                }
            }
            //--- Для Boom - импульсы вверх
            else if(!isCrashSymbol && direction == 1) {
                BuySignalBuffer[i] = low[i] - ArrowDistance * _Point;
                
                // Уведомление (только для текущей свечи)
                if(i == rates_total - 2 && time[i] != lastAlertTime) {
                    SendAlert("BOOM BUY", normalizedStrength, time[i]);
                    lastAlertTime = time[i];
                }
            }
        }
    }
    
    //--- Обновление панели
    if(ShowInfoPanel && rates_total > 0) {
        UpdateInfoPanel(rates_total - 1);
    }
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Отправка оповещения                                             |
//+------------------------------------------------------------------+
void SendAlert(string signalType, double strength, datetime time)
{
    string message = StringFormat("🎯 %s СИГНАЛ! Сила: %.1f%% | %s",
                                  signalType, strength, TimeToString(time));
    
    if(EnableAlerts) {
        Alert(message);
    }
    
    Print(message);
    Comment(message);
}

//+------------------------------------------------------------------+
//| Создание информационной панели                                  |
//+------------------------------------------------------------------+
void CreateInfoPanel()
{
    int x = 10;
    int y = 20;
    int width = 220;
    int height = 150;
    
    //--- Фон
    ObjectCreate(0, "CBS_Panel_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "CBS_Panel_BG", OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, "CBS_Panel_BG", OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, "CBS_Panel_BG", OBJPROP_XSIZE, width);
    ObjectSetInteger(0, "CBS_Panel_BG", OBJPROP_YSIZE, height);
    ObjectSetInteger(0, "CBS_Panel_BG", OBJPROP_BGCOLOR, clrBlack);
    ObjectSetInteger(0, "CBS_Panel_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, "CBS_Panel_BG", OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, "CBS_Panel_BG", OBJPROP_BACK, false);
    
    //--- Заголовок
    ObjectCreate(0, "CBS_Title", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "CBS_Title", OBJPROP_XDISTANCE, x + 10);
    ObjectSetInteger(0, "CBS_Title", OBJPROP_YDISTANCE, y + 10);
    ObjectSetInteger(0, "CBS_Title", OBJPROP_COLOR, clrYellow);
    ObjectSetString(0, "CBS_Title", OBJPROP_TEXT, "📊 CRASH/BOOM");
    ObjectSetString(0, "CBS_Title", OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, "CBS_Title", OBJPROP_FONTSIZE, 10);
    
    //--- Метки
    string labels[] = {"Symbol:", "Type:", "RSI:", "Signal:"};
    
    for(int i = 0; i < ArraySize(labels); i++) {
        string objLabel = "CBS_Label_" + IntegerToString(i);
        ObjectCreate(0, objLabel, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, objLabel, OBJPROP_XDISTANCE, x + 10);
        ObjectSetInteger(0, objLabel, OBJPROP_YDISTANCE, y + 35 + i * 25);
        ObjectSetInteger(0, objLabel, OBJPROP_COLOR, clrLightGray);
        ObjectSetString(0, objLabel, OBJPROP_TEXT, labels[i]);
        ObjectSetString(0, objLabel, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, objLabel, OBJPROP_FONTSIZE, 9);
        
        //--- Значения
        string objValue = "CBS_Value_" + IntegerToString(i);
        ObjectCreate(0, objValue, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, objValue, OBJPROP_XDISTANCE, x + 80);
        ObjectSetInteger(0, objValue, OBJPROP_YDISTANCE, y + 35 + i * 25);
        ObjectSetInteger(0, objValue, OBJPROP_COLOR, clrWhite);
        ObjectSetString(0, objValue, OBJPROP_TEXT, "...");
        ObjectSetString(0, objValue, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, objValue, OBJPROP_FONTSIZE, 9);
    }
}

//+------------------------------------------------------------------+
//| Обновление информационной панели                                |
//+------------------------------------------------------------------+
void UpdateInfoPanel(int bar_index)
{
    //--- Символ
    ObjectSetString(0, "CBS_Value_0", OBJPROP_TEXT, _Symbol);
    
    //--- Тип
    string typeText = isCrashSymbol ? "CRASH ▼" : "BOOM ▲";
    color typeColor = isCrashSymbol ? clrRed : clrDodgerBlue;
    ObjectSetString(0, "CBS_Value_1", OBJPROP_TEXT, typeText);
    ObjectSetInteger(0, "CBS_Value_1", OBJPROP_COLOR, typeColor);
    
    //--- RSI
    if(ArraySize(rsi_values) > 0)
        ObjectSetString(0, "CBS_Value_2", OBJPROP_TEXT, DoubleToString(rsi_values[0], 1));
    
    //--- Сигнал
    string signalText = "WAIT";
    color signalColor = clrGray;
    
    if(BuySignalBuffer[bar_index] > 0) {
        signalText = "BUY ⬆";
        signalColor = clrLime;
    } else if(SellSignalBuffer[bar_index] > 0) {
        signalText = "SELL ⬇";
        signalColor = clrRed;
    }
    
    ObjectSetString(0, "CBS_Value_3", OBJPROP_TEXT, signalText);
    ObjectSetInteger(0, "CBS_Value_3", OBJPROP_COLOR, signalColor);
    
    ChartRedraw();
}
//+------------------------------------------------------------------+
