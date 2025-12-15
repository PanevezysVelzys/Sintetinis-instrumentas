//+------------------------------------------------------------------+
//|                                                    CsvLite.mqh   |
//| Lightweight CSV reader/writer: default ';', supports '#', BOM,  |
//| quotes. Files read/written from Common Files (if specified).    |
//+------------------------------------------------------------------+
#ifndef CSV_LITE_MQH
#define CSV_LITE_MQH
#property strict

class CsvReader {
private:
   int   m_fh;
   bool  m_common;
   char  m_delim;
   bool  m_open;
   
public:
   CsvReader() {
      m_fh = INVALID_HANDLE;
      m_common = true;
      m_delim = ';';
      m_open = false;
   }

   bool Open(const string fname, const char delim = ';', const bool in_common = true) {
      Close();
      m_delim = delim;
      m_common = in_common;
      m_fh = FileOpen(fname, FILE_READ|FILE_ANSI|(m_common ? FILE_COMMON : 0));
      if(m_fh == INVALID_HANDLE) return false;
      m_open = true;
      return true;
   }

   bool ReadHeader(string &cols[]) {
      ArrayResize(cols, 0);
      if(!m_open) return false;
      
      string line;
      while(!FileIsEnding(m_fh)) {
         line = FileReadString(m_fh);
         if(StringLen(line) == 0) continue;
         
         // BOM
         if(StringLen(line) > 0 && StringGetCharacter(line, 0) == 0xFEFF) {
            line = StringSubstr(line, 1);
         }
         
         string t = line;
         StringTrimLeft(t);
         StringTrimRight(t);
         if(StringLen(t) == 0) continue;
         if(StringSubstr(t, 0, 1) == "#") continue;
         break;
      }
      
      if(StringLen(line) == 0) return false;
      
      int n = StringSplit(line, m_delim, cols);
      for(int i = 0; i < n; i++) {
         StringTrimLeft(cols[i]);
         StringTrimRight(cols[i]);
         
         if(StringLen(cols[i]) >= 2) {
            string a = StringSubstr(cols[i], 0, 1);
            string b = StringSubstr(cols[i], StringLen(cols[i]) - 1, 1);
            if((a == "\"" && b == "\"") || (a == "'" && b == "'")) {
               cols[i] = StringSubstr(cols[i], 1, StringLen(cols[i]) - 2);
            }
         }
      }
      return (n > 0);
   }

   bool Next(string &fields[]) {
      ArrayResize(fields, 0);
      if(!m_open) return false;
      
      while(!FileIsEnding(m_fh)) {
         string line = FileReadString(m_fh);
         if(StringLen(line) == 0) continue;
         
         string t = line;
         StringTrimLeft(t);
         StringTrimRight(t);
         if(StringLen(t) == 0) continue;
         if(StringSubstr(t, 0, 1) == "#") continue;
         
         int n = StringSplit(line, m_delim, fields);
         if(n <= 0) continue;
         
         for(int i = 0; i < n; i++) {
            StringTrimLeft(fields[i]);
            StringTrimRight(fields[i]);
            
            if(StringLen(fields[i]) >= 2) {
               string a = StringSubstr(fields[i], 0, 1);
               string b = StringSubstr(fields[i], StringLen(fields[i]) - 1, 1);
               if((a == "\"" && b == "\"") || (a == "'" && b == "'")) {
                  fields[i] = StringSubstr(fields[i], 1, StringLen(fields[i]) - 2);
               }
            }
         }
         return true;
      }
      return false;
   }

   int ColIndex(const string &name, const string &hdr[]) {
      int N = ArraySize(hdr);
      string low = name;
      StringToLower(low);
      
      for(int i = 0; i < N; i++) {
         string h = hdr[i];
         StringTrimLeft(h);
         StringTrimRight(h);
         StringToLower(h);
         if(h == low) return i;
      }
      return -1;
   }

   static bool ParseTimeMs(const string date_s, const string timems_s, datetime &t, int &msc) {
      int dot = StringFind(timems_s, ".");
      string ss = (dot >= 0 ? StringSubstr(timems_s, 0, dot) : timems_s);
      string ms = (dot >= 0 ? StringSubstr(timems_s, dot + 1) : "000");
      
      t = StringToTime(date_s + " " + ss);
      if(t == 0) return false;
      
      msc = (int)StringToInteger(ms);
      if(msc < 0) msc = 0;
      if(msc > 999) msc = msc % 1000;
      return true;
   }

   void Close() {
      if(m_open && m_fh != INVALID_HANDLE) FileClose(m_fh);
      m_fh = INVALID_HANDLE;
      m_open = false;
   }
};

class CsvWriter {
private:
   int   m_fh;
   bool  m_common;
   char  m_delim;
   bool  m_open;
   
public:
   CsvWriter() {
      m_fh = INVALID_HANDLE;
      m_common = true;
      m_delim = ';';
      m_open = false;
   }

   bool Open(const string fname, const char delim = ';', const bool in_common = true) {
      Close();
      m_delim = delim;
      m_common = in_common;
      m_fh = FileOpen(fname, FILE_WRITE|FILE_ANSI|(m_common ? FILE_COMMON : 0));
      if(m_fh == INVALID_HANDLE) return false;
      m_open = true;
      return true;
   }

   bool WriteHeader(const string &cols[]) {
      if(!m_open) return false;
      
      int N = ArraySize(cols);
      for(int i = 0; i < N; i++) {
         if(i > 0) FileWriteString(m_fh, StringFormat("%c", (int)m_delim));
         
         string f = cols[i];
         if(StringFind(f, StringFormat("%c", (int)m_delim)) >= 0) {
            FileWriteString(m_fh, "\"" + f + "\"");
         } else {
            FileWriteString(m_fh, f);
         }
      }
      FileWriteString(m_fh, "\r\n");
      return true;
   }

   bool WriteComment(const string line) {
      if(!m_open) return false;
      FileWriteString(m_fh, "# " + line + "\r\n");
      return true;
   }

   bool WriteRow(const string &fields[]) {
      if(!m_open) return false;
      
      int N = ArraySize(fields);
      for(int i = 0; i < N; i++) {
         if(i > 0) FileWriteString(m_fh, StringFormat("%c", (int)m_delim));
         
         string f = fields[i];
         if(StringFind(f, StringFormat("%c", (int)m_delim)) >= 0) {
            FileWriteString(m_fh, "\"" + f + "\"");
         } else {
            FileWriteString(m_fh, f);
         }
      }
      FileWriteString(m_fh, "\r\n");
      return true;
   }

   void Flush() {
      if(m_open) FileFlush(m_fh);
   }
   
   void Close() {
      if(m_open && m_fh != INVALID_HANDLE) FileClose(m_fh);
      m_fh = INVALID_HANDLE;
      m_open = false;
   }
};

#endif
