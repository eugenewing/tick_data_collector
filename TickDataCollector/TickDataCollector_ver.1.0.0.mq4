//+-----------------------------------------------------------------------------------------------------------+
//|                                                                                         TickDataCollector |
//|                                                                             Copyright 2026, Andy Dufresne |
//+-----------------------------------------------------------------------------------------------------------+
#property strict
#property copyright "Copyright 2026, Andy Dufresne"
#property version   "1.0.0"

struct Tick {
   double            ask;//Цена ask
   double            bid;//Цена bid
   string            date;//Время и дата
   int               volume;//Объем тика
   double            body;//Тело тика
   double            spread;//Спред тика
   int               speed;//Скорость тика
};

Tick TickData[];
datetime LastM5BarTime = 0;
string DataFilePrefix = "TickDataCollector_Data_";
int MaxRowsPerFile = 150000;
int CurrentDataFileIndex = 0;
int CurrentDataFileRowCount = 0;
//+-----------------------------------------------------------------------------------------------------------+
//| Основные функции                                                                                          |
//+-----------------------------------------------------------------------------------------------------------+
int OnInit() {
   ArrayResize(TickData, 0);
   LastM5BarTime = iTime(Symbol(), PERIOD_M5, 0);
   // Находит индекс последнего файла TickDataCollector_Data_N.csv, доступного для продолжения записи.
   CurrentDataFileIndex = GetLastDataFileIndex();

   if (CurrentDataFileIndex == 0) {
      CurrentDataFileIndex = 1;
      CurrentDataFileRowCount = 0;
   } else {
      // Возвращает имя CSV-файла по его порядковому номеру.
      string currentDataFileName = GetDataFileName(CurrentDataFileIndex);
      // Подсчитывает количество строк с данными в указанном CSV-файле.
      CurrentDataFileRowCount = CountFileRows(currentDataFileName);
   }

   return(INIT_SUCCEEDED);
}
//+-----------------------------------------------------------------------------------------------------------+
void OnDeinit(const int reason) {}
//+-----------------------------------------------------------------------------------------------------------+
void OnTick() {
   datetime currentM5BarTime = iTime(Symbol(), PERIOD_M5, 0);

   if (LastM5BarTime == 0) {
      LastM5BarTime = currentM5BarTime;
   }

   if (currentM5BarTime != LastM5BarTime) {
      // Сохраняет накопленные тики в последний CSV-файл и при достижении лимита строк создает следующий.
      SaveTickDataToCsv();
      ArrayResize(TickData, 0);
      LastM5BarTime = currentM5BarTime;
   }

   Tick tick;
   // Получает цену ask.
   tick.ask = NormalizeDouble(Ask, Digits);
   // Получает цену bid.
   tick.bid = NormalizeDouble(Bid, Digits);
   // Получает дату и время тика.
   tick.date = GetTickTimeDate();
   // Получает объем, прошедший в текущем тике, как разницу между новым и предыдущим объемом.
   tick.volume = GetTickVolume();
   // Получает тело текущего тика как изменение Bid относительно предыдущего тика.
   tick.body = GetTickBody();
   // Получает спред текущего тика как разницу между Ask и Bid.
   tick.spread = GetTickSpread();
   // Получает скорость текущего тика как время в миллисекундах с предыдущего тика.
   tick.speed = GetTickSpeed();

   int tickDataSize = ArraySize(TickData);
   ArrayResize(TickData, tickDataSize + 1);
   TickData[tickDataSize] = tick;
}
//+-----------------------------------------------------------------------------------------------------------+
//| Пользовательские функции                                                                                  |
//+-----------------------------------------------------------------------------------------------------------+
string GetTickTimeDate() {
   // Получает дату и время тика.
   // Получаем текущее серверное время тика (с точностью до секунд)
   datetime server_time = TimeCurrent();
   
   // Получаем системные миллисекунды
   uint sys_msc = GetTickCount();
   
   // Вычисляем остаток миллисекунд для текущей секунды
   int milliseconds = (int)(sys_msc % 1000);
   
   // Выводим строковое представление даты, времени и миллисекунд
   return(StringFormat("=\"%s.%03d\"", TimeToString(server_time, TIME_DATE|TIME_SECONDS), milliseconds));
}
//+-----------------------------------------------------------------------------------------------------------+
// Получает объем, прошедший в текущем тике, как разницу между новым и предыдущим объемом.
int GetTickVolume() {
   static int previousVolume = 0;
   int currentVolume = (int)Volume[0];

   if (previousVolume == 0 || currentVolume < previousVolume) {
      previousVolume = currentVolume;
      return(0);
   }

   int tickVolume = currentVolume - previousVolume;
   previousVolume = currentVolume;

   return(tickVolume);
}
//+-----------------------------------------------------------------------------------------------------------+
// Получает тело текущего тика как изменение Bid относительно предыдущего тика.
double GetTickBody() {
   static double previousBid = 0.0;
   double currentBid = Bid;

   if (previousBid == 0.0) {
      previousBid = currentBid;
      return(0.0);
   }

   double body = NormalizeDouble(currentBid - previousBid, Digits);
   previousBid = currentBid;

   return(body);
}
//+-----------------------------------------------------------------------------------------------------------+
// Получает спред текущего тика как разницу между Ask и Bid.
double GetTickSpread() {
   return(NormalizeDouble(Ask - Bid, Digits));
}
//+------------------------------------------------------------------+
// Получает скорость текущего тика как время в миллисекундах с предыдущего тика.
int GetTickSpeed() {
   static uint previousTickCount = 0;
   uint currentTickCount = GetTickCount();

   if (previousTickCount == 0) {
      previousTickCount = currentTickCount;
      return(0);
   }

   int speed = (int)(currentTickCount - previousTickCount);
   previousTickCount = currentTickCount;

   return(speed);
}
//+-----------------------------------------------------------------------------------------------------------+
// Сохраняет накопленные тики в последний CSV-файл и при достижении лимита строк создает следующий.
void SaveTickDataToCsv() {
   int tickCount = ArraySize(TickData);

   if (tickCount == 0) {
      return;
   }

   int tickIndex = 0;

   while (tickIndex < tickCount) {
      if (CurrentDataFileRowCount >= MaxRowsPerFile) {
         CurrentDataFileIndex++;
         CurrentDataFileRowCount = 0;
      }

      // Возвращает имя CSV-файла по его порядковому номеру.
      string fileName = GetDataFileName(CurrentDataFileIndex);
      int fileHandle = FileOpen(fileName, FILE_CSV | FILE_READ | FILE_WRITE | FILE_ANSI, ';');

      if (fileHandle == INVALID_HANDLE) {
         return;
      }

      FileSeek(fileHandle, 0, SEEK_END);

      while (tickIndex < tickCount && CurrentDataFileRowCount < MaxRowsPerFile) {
         FileWrite(fileHandle,
                   DoubleToString(TickData[tickIndex].ask, Digits),
                   DoubleToString(TickData[tickIndex].bid, Digits),
                   TickData[tickIndex].date,
                   TickData[tickIndex].volume,
                   DoubleToString(TickData[tickIndex].body, Digits),
                   DoubleToString(TickData[tickIndex].spread, Digits),
                   TickData[tickIndex].speed);

         tickIndex++;
         CurrentDataFileRowCount++;
      }

      FileClose(fileHandle);
   }
}
//+-----------------------------------------------------------------------------------------------------------+
// Возвращает имя CSV-файла по его порядковому номеру.
string GetDataFileName(int fileIndex) {
   return(DataFilePrefix + IntegerToString(fileIndex) + ".csv");
}
//+-----------------------------------------------------------------------------------------------------------+
// Находит индекс последнего файла TickDataCollector_Data_N.csv, доступного для продолжения записи.
int GetLastDataFileIndex() {
   string fileName;
   int lastFileIndex = 0;
   long searchHandle = FileFindFirst(DataFilePrefix + "*.csv", fileName, 0);

   if (searchHandle == INVALID_HANDLE) {
      return(0);
   }

   do {
      // Извлекает порядковый номер файла из имени TickDataCollector_Data_N.csv.
      int fileIndex = ExtractFileIndex(fileName);

      if (fileIndex > lastFileIndex) {
         lastFileIndex = fileIndex;
      }
   }
   while (FileFindNext(searchHandle, fileName));

   FileFindClose(searchHandle);

   return(lastFileIndex);
}
//+-----------------------------------------------------------------------------------------------------------+
// Извлекает порядковый номер файла из имени TickDataCollector_Data_N.csv.
int ExtractFileIndex(string fileName) {
   string prefix = DataFilePrefix;
   string suffix = ".csv";
   int prefixLength = StringLen(prefix);
   int suffixLength = StringLen(suffix);
   int fileNameLength = StringLen(fileName);

   if (fileNameLength <= prefixLength + suffixLength) {
      return(0);
   }

   string indexPart = StringSubstr(fileName, prefixLength, fileNameLength - prefixLength - suffixLength);

   return((int)StringToInteger(indexPart));
}
//+-----------------------------------------------------------------------------------------------------------+
// Подсчитывает количество строк с данными в указанном CSV-файле.
int CountFileRows(string fileName) {
   if (!FileIsExist(fileName)) {
      return(0);
   }

   int fileHandle = FileOpen(fileName, FILE_CSV | FILE_READ | FILE_ANSI, ';');

   if (fileHandle == INVALID_HANDLE) {
      return(0);
   }

   int rowCount = 0;

   while (!FileIsEnding(fileHandle)) {
      FileReadNumber(fileHandle);
      FileReadString(fileHandle);
      FileReadString(fileHandle);
      FileReadNumber(fileHandle);
      rowCount++;
   }

   FileClose(fileHandle);

   return(rowCount);
}
//+-----------------------------------------------------------------------------------------------------------+