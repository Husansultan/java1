//+------------------------------------------------------------------+
//|                                        CrashBoom_Utilities.mqh |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Вспомогательные функции и утилиты для индикатора CrashBoom      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Класс для работы с графическими объектами                       |
//+------------------------------------------------------------------+
class CChartObjects
{
private:
    string m_object_prefix;
    int m_object_count;
    
public:
    CChartObjects(string prefix = "CrashBoom_");
    ~CChartObjects();
    
    // Создание объектов
    bool CreateTrendLine(string name, datetime time1, double price1, datetime time2, double price2, color clr = clrBlue);
    bool CreateHorizontalLine(string name, double price, color clr = clrYellow);
    bool CreateRectangle(string name, datetime time1, double price1, datetime time2, double price2, color clr = clrGray);
    bool CreateText(string name, string text, datetime time, double price, color clr = clrWhite);
    bool CreateArrow(string name, datetime time, double price, int arrow_code, color clr = clrRed);
    
    // Удаление объектов
    bool DeleteObject(string name);
    bool DeleteAllObjects();
    bool DeleteOldObjects(int max_age_bars = 100);
    
    // Обновление объектов
    bool UpdateTrendLine(string name, datetime time2, double price2);
    bool UpdateText(string name, string new_text);
    
    // Получение информации
    int GetObjectCount() { return m_object_count; }
    string GetObjectName(int index);
    bool ObjectExists(string name);
};

//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
CChartObjects::CChartObjects(string prefix)
{
    m_object_prefix = prefix;
    m_object_count = 0;
}

//+------------------------------------------------------------------+
//| Деструктор                                                       |
//+------------------------------------------------------------------+
CChartObjects::~CChartObjects()
{
    DeleteAllObjects();
}

//+------------------------------------------------------------------+
//| Создание трендовой линии                                         |
//+------------------------------------------------------------------+
bool CChartObjects::CreateTrendLine(string name, datetime time1, double price1, datetime time2, double price2, color clr)
{
    string full_name = m_object_prefix + name;
    
    if(ObjectFind(0, full_name) >= 0)
    {
        ObjectDelete(0, full_name);
    }
    
    if(ObjectCreate(0, full_name, OBJ_TREND, 0, time1, price1, time2, price2))
    {
        ObjectSetInteger(0, full_name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, full_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, full_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, full_name, OBJPROP_RAY_RIGHT, true);
        m_object_count++;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Создание горизонтальной линии                                    |
//+------------------------------------------------------------------+
bool CChartObjects::CreateHorizontalLine(string name, double price, color clr)
{
    string full_name = m_object_prefix + name;
    
    if(ObjectFind(0, full_name) >= 0)
    {
        ObjectDelete(0, full_name);
    }
    
    if(ObjectCreate(0, full_name, OBJ_HLINE, 0, 0, price))
    {
        ObjectSetInteger(0, full_name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, full_name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, full_name, OBJPROP_STYLE, STYLE_DOT);
        m_object_count++;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Создание прямоугольника                                          |
//+------------------------------------------------------------------+
bool CChartObjects::CreateRectangle(string name, datetime time1, double price1, datetime time2, double price2, color clr)
{
    string full_name = m_object_prefix + name;
    
    if(ObjectFind(0, full_name) >= 0)
    {
        ObjectDelete(0, full_name);
    }
    
    if(ObjectCreate(0, full_name, OBJ_RECTANGLE, 0, time1, price1, time2, price2))
    {
        ObjectSetInteger(0, full_name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, full_name, OBJPROP_FILL, true);
        ObjectSetInteger(0, full_name, OBJPROP_BACK, true);
        m_object_count++;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Создание текста                                                  |
//+------------------------------------------------------------------+
bool CChartObjects::CreateText(string name, string text, datetime time, double price, color clr)
{
    string full_name = m_object_prefix + name;
    
    if(ObjectFind(0, full_name) >= 0)
    {
        ObjectDelete(0, full_name);
    }
    
    if(ObjectCreate(0, full_name, OBJ_TEXT, 0, time, price))
    {
        ObjectSetString(0, full_name, OBJPROP_TEXT, text);
        ObjectSetInteger(0, full_name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, full_name, OBJPROP_FONTSIZE, 10);
        m_object_count++;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Создание стрелки                                                 |
//+------------------------------------------------------------------+
bool CChartObjects::CreateArrow(string name, datetime time, double price, int arrow_code, color clr)
{
    string full_name = m_object_prefix + name;
    
    if(ObjectFind(0, full_name) >= 0)
    {
        ObjectDelete(0, full_name);
    }
    
    if(ObjectCreate(0, full_name, OBJ_ARROW, 0, time, price))
    {
        ObjectSetInteger(0, full_name, OBJPROP_ARROWCODE, arrow_code);
        ObjectSetInteger(0, full_name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, full_name, OBJPROP_WIDTH, 3);
        m_object_count++;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Удаление объекта                                                 |
//+------------------------------------------------------------------+
bool CChartObjects::DeleteObject(string name)
{
    string full_name = m_object_prefix + name;
    if(ObjectFind(0, full_name) >= 0)
    {
        if(ObjectDelete(0, full_name))
        {
            m_object_count--;
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Удаление всех объектов                                           |
//+------------------------------------------------------------------+
bool CChartObjects::DeleteAllObjects()
{
    int total_objects = ObjectsTotal(0, 0, OBJ_TREND);
    total_objects += ObjectsTotal(0, 0, OBJ_HLINE);
    total_objects += ObjectsTotal(0, 0, OBJ_RECTANGLE);
    total_objects += ObjectsTotal(0, 0, OBJ_TEXT);
    total_objects += ObjectsTotal(0, 0, OBJ_ARROW);
    
    for(int i = total_objects - 1; i >= 0; i--)
    {
        string obj_name = ObjectName(0, i, 0, OBJ_TREND);
        if(StringFind(obj_name, m_object_prefix) == 0)
        {
            ObjectDelete(0, obj_name);
        }
    }
    
    m_object_count = 0;
    return true;
}

//+------------------------------------------------------------------+
//| Удаление старых объектов                                         |
//+------------------------------------------------------------------+
bool CChartObjects::DeleteOldObjects(int max_age_bars)
{
    datetime current_time = TimeCurrent();
    int deleted = 0;
    
    for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
    {
        string obj_name = ObjectName(0, i, 0, -1);
        if(StringFind(obj_name, m_object_prefix) == 0)
        {
            datetime obj_time = (datetime)ObjectGetInteger(0, obj_name, OBJPROP_TIME);
            if(current_time - obj_time > max_age_bars * PeriodSeconds())
            {
                ObjectDelete(0, obj_name);
                deleted++;
            }
        }
    }
    
    m_object_count -= deleted;
    return true;
}

//+------------------------------------------------------------------+
//| Обновление трендовой линии                                       |
//+------------------------------------------------------------------+
bool CChartObjects::UpdateTrendLine(string name, datetime time2, double price2)
{
    string full_name = m_object_prefix + name;
    if(ObjectFind(0, full_name) >= 0)
    {
        ObjectSetInteger(0, full_name, OBJPROP_TIME, 1, time2);
        ObjectSetDouble(0, full_name, OBJPROP_PRICE, 1, price2);
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Обновление текста                                                |
//+------------------------------------------------------------------+
bool CChartObjects::UpdateText(string name, string new_text)
{
    string full_name = m_object_prefix + name;
    if(ObjectFind(0, full_name) >= 0)
    {
        ObjectSetString(0, full_name, OBJPROP_TEXT, new_text);
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Получение имени объекта по индексу                               |
//+------------------------------------------------------------------+
string CChartObjects::GetObjectName(int index)
{
    int count = 0;
    for(int i = 0; i < ObjectsTotal(0, 0, -1); i++)
    {
        string obj_name = ObjectName(0, i, 0, -1);
        if(StringFind(obj_name, m_object_prefix) == 0)
        {
            if(count == index)
                return obj_name;
            count++;
        }
    }
    return "";
}

//+------------------------------------------------------------------+
//| Проверка существования объекта                                   |
//+------------------------------------------------------------------+
bool CChartObjects::ObjectExists(string name)
{
    string full_name = m_object_prefix + name;
    return ObjectFind(0, full_name) >= 0;
}

//+------------------------------------------------------------------+
//| Класс для работы с уведомлениями                                 |
//+------------------------------------------------------------------+
class CNotifications
{
private:
    bool m_enable_alerts;
    bool m_enable_push;
    bool m_enable_email;
    string m_email_address;
    
public:
    CNotifications(bool alerts = true, bool push = false, bool email = false, string email_addr = "");
    ~CNotifications();
    
    // Отправка уведомлений
    bool SendAlert(string title, string message, int alert_type = 0);
    bool SendPushNotification(string message);
    bool SendEmail(string subject, string message);
    
    // Настройки
    void SetAlertsEnabled(bool enabled) { m_enable_alerts = enabled; }
    void SetPushEnabled(bool enabled) { m_enable_push = enabled; }
    void SetEmailEnabled(bool enabled) { m_enable_email = enabled; }
    void SetEmailAddress(string address) { m_email_address = address; }
    
    // Вспомогательные функции
    string FormatMessage(string symbol, string signal_type, double probability, double price);
    void LogMessage(string message);
};

//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
CNotifications::CNotifications(bool alerts, bool push, bool email, string email_addr)
{
    m_enable_alerts = alerts;
    m_enable_push = push;
    m_enable_email = email;
    m_email_address = email_addr;
}

//+------------------------------------------------------------------+
//| Деструктор                                                       |
//+------------------------------------------------------------------+
CNotifications::~CNotifications()
{
    // Очистка ресурсов
}

//+------------------------------------------------------------------+
//| Отправка оповещения                                              |
//+------------------------------------------------------------------+
bool CNotifications::SendAlert(string title, string message, int alert_type)
{
    if(!m_enable_alerts) return false;
    
    bool result = false;
    
    // Звуковое оповещение
    if(alert_type == 0 || alert_type == 1)
    {
        Alert(title + ": " + message);
        result = true;
    }
    
    // Визуальное оповещение
    if(alert_type == 0 || alert_type == 2)
    {
        MessageBox(message, title, MB_OK | MB_ICONINFORMATION);
        result = true;
    }
    
    // Вывод в лог
    LogMessage(title + ": " + message);
    
    return result;
}

//+------------------------------------------------------------------+
//| Отправка push-уведомления                                        |
//+------------------------------------------------------------------+
bool CNotifications::SendPushNotification(string message)
{
    if(!m_enable_push) return false;
    
    // Отправка push-уведомления через MT5
    if(SendNotification(message))
    {
        LogMessage("Push notification sent: " + message);
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Отправка email                                                   |
//+------------------------------------------------------------------+
bool CNotifications::SendEmail(string subject, string message)
{
    if(!m_enable_email || m_email_address == "") return false;
    
    // Отправка email через MT5
    if(SendMail(subject, message))
    {
        LogMessage("Email sent to " + m_email_address + ": " + subject);
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Форматирование сообщения                                         |
//+------------------------------------------------------------------+
string CNotifications::FormatMessage(string symbol, string signal_type, double probability, double price)
{
    string message = "";
    message += "Символ: " + symbol + "\n";
    message += "Сигнал: " + signal_type + "\n";
    message += "Вероятность: " + DoubleToString(probability * 100, 1) + "%\n";
    message += "Цена: " + DoubleToString(price, _Digits) + "\n";
    message += "Время: " + TimeToString(TimeCurrent()) + "\n";
    
    return message;
}

//+------------------------------------------------------------------+
//| Логирование сообщения                                            |
//+------------------------------------------------------------------+
void CNotifications::LogMessage(string message)
{
    Print(TimeToString(TimeCurrent()) + " - " + message);
}

//+------------------------------------------------------------------+
//| Класс для статистики и анализа производительности               |
//+------------------------------------------------------------------+
class CPerformanceStats
{
private:
    struct StatRecord {
        datetime time;
        string signal_type;
        double predicted_probability;
        double actual_result;
        bool was_correct;
    };
    
    StatRecord m_records[1000];
    int m_record_count;
    double m_total_accuracy;
    int m_total_signals;
    int m_correct_signals;
    
public:
    CPerformanceStats();
    ~CPerformanceStats();
    
    // Добавление записи
    bool AddRecord(string signal_type, double predicted_probability, double actual_result);
    
    // Расчет статистики
    double GetAccuracy();
    double GetPrecision();
    double GetRecall();
    double GetF1Score();
    int GetTotalSignals() { return m_total_signals; }
    int GetCorrectSignals() { return m_correct_signals; }
    
    // Анализ по типам сигналов
    double GetAccuracyByType(string signal_type);
    int GetSignalsByType(string signal_type);
    
    // Очистка старых записей
    void CleanOldRecords(int max_age_hours = 24);
    
    // Экспорт статистики
    string ExportToCSV();
    bool SaveToFile(string filename);
};

//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
CPerformanceStats::CPerformanceStats()
{
    m_record_count = 0;
    m_total_accuracy = 0;
    m_total_signals = 0;
    m_correct_signals = 0;
    ArrayResize(m_records, 1000);
}

//+------------------------------------------------------------------+
//| Деструктор                                                       |
//+------------------------------------------------------------------+
CPerformanceStats::~CPerformanceStats()
{
    ArrayFree(m_records);
}

//+------------------------------------------------------------------+
//| Добавление записи                                                |
//+------------------------------------------------------------------+
bool CPerformanceStats::AddRecord(string signal_type, double predicted_probability, double actual_result)
{
    if(m_record_count >= 1000) return false;
    
    m_records[m_record_count].time = TimeCurrent();
    m_records[m_record_count].signal_type = signal_type;
    m_records[m_record_count].predicted_probability = predicted_probability;
    m_records[m_record_count].actual_result = actual_result;
    m_records[m_record_count].was_correct = (predicted_probability > 0.5 && actual_result > 0) || 
                                           (predicted_probability < 0.5 && actual_result < 0);
    
    if(m_records[m_record_count].was_correct)
    {
        m_correct_signals++;
    }
    
    m_total_signals++;
    m_total_accuracy = (double)m_correct_signals / m_total_signals;
    m_record_count++;
    
    return true;
}

//+------------------------------------------------------------------+
//| Расчет точности                                                  |
//+------------------------------------------------------------------+
double CPerformanceStats::GetAccuracy()
{
    return m_total_accuracy;
}

//+------------------------------------------------------------------+
//| Расчет точности (precision)                                      |
//+------------------------------------------------------------------+
double CPerformanceStats::GetPrecision()
{
    int true_positive = 0;
    int false_positive = 0;
    
    for(int i = 0; i < m_record_count; i++)
    {
        if(m_records[i].predicted_probability > 0.5)
        {
            if(m_records[i].actual_result > 0)
                true_positive++;
            else
                false_positive++;
        }
    }
    
    if(true_positive + false_positive == 0) return 0;
    return (double)true_positive / (true_positive + false_positive);
}

//+------------------------------------------------------------------+
//| Расчет полноты (recall)                                          |
//+------------------------------------------------------------------+
double CPerformanceStats::GetRecall()
{
    int true_positive = 0;
    int false_negative = 0;
    
    for(int i = 0; i < m_record_count; i++)
    {
        if(m_records[i].actual_result > 0)
        {
            if(m_records[i].predicted_probability > 0.5)
                true_positive++;
            else
                false_negative++;
        }
    }
    
    if(true_positive + false_negative == 0) return 0;
    return (double)true_positive / (true_positive + false_negative);
}

//+------------------------------------------------------------------+
//| Расчет F1-меры                                                   |
//+------------------------------------------------------------------+
double CPerformanceStats::GetF1Score()
{
    double precision = GetPrecision();
    double recall = GetRecall();
    
    if(precision + recall == 0) return 0;
    return 2 * (precision * recall) / (precision + recall);
}

//+------------------------------------------------------------------+
//| Расчет точности по типу сигнала                                  |
//+------------------------------------------------------------------+
double CPerformanceStats::GetAccuracyByType(string signal_type)
{
    int total = 0;
    int correct = 0;
    
    for(int i = 0; i < m_record_count; i++)
    {
        if(m_records[i].signal_type == signal_type)
        {
            total++;
            if(m_records[i].was_correct)
                correct++;
        }
    }
    
    if(total == 0) return 0;
    return (double)correct / total;
}

//+------------------------------------------------------------------+
//| Количество сигналов по типу                                      |
//+------------------------------------------------------------------+
int CPerformanceStats::GetSignalsByType(string signal_type)
{
    int count = 0;
    
    for(int i = 0; i < m_record_count; i++)
    {
        if(m_records[i].signal_type == signal_type)
            count++;
    }
    
    return count;
}

//+------------------------------------------------------------------+
//| Очистка старых записей                                           |
//+------------------------------------------------------------------+
void CPerformanceStats::CleanOldRecords(int max_age_hours)
{
    datetime cutoff_time = TimeCurrent() - max_age_hours * 3600;
    int new_count = 0;
    
    for(int i = 0; i < m_record_count; i++)
    {
        if(m_records[i].time >= cutoff_time)
        {
            if(new_count != i)
            {
                m_records[new_count] = m_records[i];
            }
            new_count++;
        }
    }
    
    m_record_count = new_count;
}

//+------------------------------------------------------------------+
//| Экспорт в CSV                                                    |
//+------------------------------------------------------------------+
string CPerformanceStats::ExportToCSV()
{
    string csv = "Time,SignalType,PredictedProbability,ActualResult,WasCorrect\n";
    
    for(int i = 0; i < m_record_count; i++)
    {
        csv += TimeToString(m_records[i].time) + ",";
        csv += m_records[i].signal_type + ",";
        csv += DoubleToString(m_records[i].predicted_probability, 3) + ",";
        csv += DoubleToString(m_records[i].actual_result, 3) + ",";
        csv += (m_records[i].was_correct ? "1" : "0") + "\n";
    }
    
    return csv;
}

//+------------------------------------------------------------------+
//| Сохранение в файл                                                |
//+------------------------------------------------------------------+
bool CPerformanceStats::SaveToFile(string filename)
{
    int file_handle = FileOpen(filename, FILE_WRITE | FILE_TXT);
    if(file_handle == INVALID_HANDLE) return false;
    
    string csv = ExportToCSV();
    FileWriteString(file_handle, csv);
    FileClose(file_handle);
    
    return true;
}

//+------------------------------------------------------------------+
//| Класс для работы с конфигурацией                                 |
//+------------------------------------------------------------------+
class CConfigManager
{
private:
    string m_config_file;
    struct ConfigParam {
        string name;
        string value;
        string type;
    };
    
    ConfigParam m_params[100];
    int m_param_count;
    
public:
    CConfigManager(string filename = "CrashBoom_Config.ini");
    ~CConfigManager();
    
    // Загрузка и сохранение конфигурации
    bool LoadConfig();
    bool SaveConfig();
    
    // Работа с параметрами
    bool SetParameter(string name, string value, string type = "string");
    string GetParameter(string name, string default_value = "");
    int GetIntParameter(string name, int default_value = 0);
    double GetDoubleParameter(string name, double default_value = 0.0);
    bool GetBoolParameter(string name, bool default_value = false);
    
    // Вспомогательные функции
    bool ParameterExists(string name);
    int GetParameterCount() { return m_param_count; }
    string GetParameterName(int index);
};

//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
CConfigManager::CConfigManager(string filename)
{
    m_config_file = filename;
    m_param_count = 0;
    ArrayResize(m_params, 100);
}

//+------------------------------------------------------------------+
//| Деструктор                                                       |
//+------------------------------------------------------------------+
CConfigManager::~CConfigManager()
{
    ArrayFree(m_params);
}

//+------------------------------------------------------------------+
//| Загрузка конфигурации                                            |
//+------------------------------------------------------------------+
bool CConfigManager::LoadConfig()
{
    int file_handle = FileOpen(m_config_file, FILE_READ | FILE_TXT);
    if(file_handle == INVALID_HANDLE) return false;
    
    m_param_count = 0;
    
    while(!FileIsEnding(file_handle))
    {
        string line = FileReadString(file_handle);
        if(line == "") continue;
        
        int pos = StringFind(line, "=");
        if(pos > 0)
        {
            m_params[m_param_count].name = StringSubstr(line, 0, pos);
            m_params[m_param_count].value = StringSubstr(line, pos + 1);
            m_params[m_param_count].type = "string";
            m_param_count++;
        }
    }
    
    FileClose(file_handle);
    return true;
}

//+------------------------------------------------------------------+
//| Сохранение конфигурации                                          |
//+------------------------------------------------------------------+
bool CConfigManager::SaveConfig()
{
    int file_handle = FileOpen(m_config_file, FILE_WRITE | FILE_TXT);
    if(file_handle == INVALID_HANDLE) return false;
    
    for(int i = 0; i < m_param_count; i++)
    {
        string line = m_params[i].name + "=" + m_params[i].value + "\n";
        FileWriteString(file_handle, line);
    }
    
    FileClose(file_handle);
    return true;
}

//+------------------------------------------------------------------+
//| Установка параметра                                              |
//+------------------------------------------------------------------+
bool CConfigManager::SetParameter(string name, string value, string type)
{
    // Поиск существующего параметра
    for(int i = 0; i < m_param_count; i++)
    {
        if(m_params[i].name == name)
        {
            m_params[i].value = value;
            m_params[i].type = type;
            return true;
        }
    }
    
    // Добавление нового параметра
    if(m_param_count < 100)
    {
        m_params[m_param_count].name = name;
        m_params[m_param_count].value = value;
        m_params[m_param_count].type = type;
        m_param_count++;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Получение параметра                                              |
//+------------------------------------------------------------------+
string CConfigManager::GetParameter(string name, string default_value)
{
    for(int i = 0; i < m_param_count; i++)
    {
        if(m_params[i].name == name)
            return m_params[i].value;
    }
    return default_value;
}

//+------------------------------------------------------------------+
//| Получение целочисленного параметра                               |
//+------------------------------------------------------------------+
int CConfigManager::GetIntParameter(string name, int default_value)
{
    string value = GetParameter(name, "");
    if(value == "") return default_value;
    return (int)StringToInteger(value);
}

//+------------------------------------------------------------------+
//| Получение вещественного параметра                                |
//+------------------------------------------------------------------+
double CConfigManager::GetDoubleParameter(string name, double default_value)
{
    string value = GetParameter(name, "");
    if(value == "") return default_value;
    return StringToDouble(value);
}

//+------------------------------------------------------------------+
//| Получение логического параметра                                  |
//+------------------------------------------------------------------+
bool CConfigManager::GetBoolParameter(string name, bool default_value)
{
    string value = GetParameter(name, "");
    if(value == "") return default_value;
    return (value == "true" || value == "1");
}

//+------------------------------------------------------------------+
//| Проверка существования параметра                                 |
//+------------------------------------------------------------------+
bool CConfigManager::ParameterExists(string name)
{
    for(int i = 0; i < m_param_count; i++)
    {
        if(m_params[i].name == name)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Получение имени параметра по индексу                             |
//+------------------------------------------------------------------+
string CConfigManager::GetParameterName(int index)
{
    if(index >= 0 && index < m_param_count)
        return m_params[index].name;
    return "";
}

//+------------------------------------------------------------------+