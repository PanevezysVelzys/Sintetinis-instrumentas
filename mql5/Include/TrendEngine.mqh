//+------------------------------------------------------------------+
//|                                    TrendEngine.mqh               |
//| Retrospective dual trend labeling (UP=1, DOWN=-1, FLAT=0)       |
//| OPTIMIZED: Batch array allocation for performance               |
//| FIXED: Max retracement checked even in FLAT state               |
//| INFO: Shows retracement even before trend starts                |
//+------------------------------------------------------------------+

#ifndef TREND_ENGINE_MQH
#define TREND_ENGINE_MQH

struct TrendTickData {
   datetime ts;
   int msc;
   double bid;
   double ask;
   double tp;
   int label;
   int trend_id;
   double length_pips;
   string info;
};

class TrendEngine {
private:
   int m_minLengthPoints;
   int m_maxRetrPoints;
   bool m_scaleJPY;
   
   TrendTickData m_allTicks[];
   int m_tickCount;
   int m_allocatedSize;
   
   bool m_inUptrend;
   long m_upLowest;
   int m_upLowestIdx;
   long m_upPeak;
   int m_upPeakIdx;
   int m_upFlatStart;
   int m_upRetrStart;
   
   bool m_inDowntrend;
   long m_downHighest;
   int m_downHighestIdx;
   long m_downBottom;
   int m_downBottomIdx;
   int m_downFlatStart;
   int m_downRetrStart;
   
   int m_trendId;

public:
   TrendEngine() {
      m_inUptrend = false;
      m_inDowntrend = false;
      m_trendId = 0;
      m_tickCount = 0;
      m_allocatedSize = 0;
      m_upFlatStart = 0;
      m_downFlatStart = 0;
      m_upRetrStart = -1;
      m_downRetrStart = -1;
   }
   
   void Init(int minLengthPips, int maxRetrPips, bool scaleJPY) {
      m_minLengthPoints = minLengthPips * 10;
      m_maxRetrPoints = maxRetrPips * 10;
      m_scaleJPY = scaleJPY;
      
      m_allocatedSize = 100000;
      ArrayResize(m_allTicks, m_allocatedSize);
      m_tickCount = 0;
      
      PrintFormat("[TREND_ENGINE] Retrospective dual labeling");
      PrintFormat("  MinLength=%d pips, MaxRetr=%d pips", minLengthPips, maxRetrPips);
      PrintFormat("  MaxRetr enforced ALWAYS (even in FLAT state)");
      PrintFormat("  Retracement shown in INFO column");
      PrintFormat("  Chronological output guaranteed");
   }
   
   void ProcessTick(datetime ts, int msc, double bid, double ask, double tp, TrendTickData &output[]) {
      long tpI = RoundToPoints(tp);
      
      if(m_tickCount >= m_allocatedSize) {
         m_allocatedSize += 100000;
         ArrayResize(m_allTicks, m_allocatedSize);
      }
      
      int idx = m_tickCount++;
      
      m_allTicks[idx].ts = ts;
      m_allTicks[idx].msc = msc;
      m_allTicks[idx].bid = bid;
      m_allTicks[idx].ask = ask;
      m_allTicks[idx].tp = tp;
      m_allTicks[idx].label = 0;
      m_allTicks[idx].trend_id = 0;
      m_allTicks[idx].length_pips = 0.0;
      m_allTicks[idx].info = "";
      
      if(!m_inUptrend && !m_inDowntrend) {
         // === FLAT STATE - Track potential trends ===
         
         // Track lowest for potential uptrend
         if(idx == m_upFlatStart || tpI < m_upLowest) {
            m_upLowest = tpI;
            m_upLowestIdx = idx;
            if(idx > m_upFlatStart) {
               m_upFlatStart = idx;
            }
         }
         
         // Track highest for potential downtrend
         if(idx == m_downFlatStart || tpI > m_downHighest) {
            m_downHighest = tpI;
            m_downHighestIdx = idx;
            if(idx > m_downFlatStart) {
               m_downFlatStart = idx;
            }
         }
         
         // === CHECK UPTREND RETRACEMENT (even in FLAT) ===
         long upGain = tpI - m_upLowest;
         long upPeak = m_upLowest;
         
         // Find peak since lowest
         for(int i = m_upLowestIdx; i <= idx; i++) {
            long checkTp = RoundToPoints(m_allTicks[i].tp);
            if(checkTp > upPeak) upPeak = checkTp;
         }
         
         long upRetr = upPeak - tpI;
         
         // === CHECK DOWNTREND RETRACEMENT (even in FLAT) ===
         long downDrop = m_downHighest - tpI;
         long downBottom = m_downHighest;
         
         // Find bottom since highest
         for(int i = m_downHighestIdx; i <= idx; i++) {
            long checkTp = RoundToPoints(m_allTicks[i].tp);
            if(checkTp < downBottom) downBottom = checkTp;
         }
         
         long downRetr = tpI - downBottom;
         
         // === DETERMINE INFO STRING (show retracement even in FLAT) ===
         string info_str = "";
         
         // If uptrend is stronger candidate
         if(upGain > downDrop) {
            if(upGain > 0) {
               info_str = "UP:" + DoubleToString(PointsToPips(upGain), 1);
               if(upPeak > m_upLowest && upRetr > 0) {
                  info_str += " RETR:" + DoubleToString(PointsToPips(upRetr), 1);
               }
            }
         } else {
            if(downDrop > 0) {
               info_str = "DN:" + DoubleToString(PointsToPips(downDrop), 1);
               if(downBottom < m_downHighest && downRetr > 0) {
                  info_str += " RETR:" + DoubleToString(PointsToPips(downRetr), 1);
               }
            }
         }
         
         m_allTicks[idx].info = info_str;
         
         // === CHECK IF RETRACEMENT EXCEEDED - RESET ===
         if(upPeak > m_upLowest && upRetr > (long)m_maxRetrPoints) {
            m_upLowest = tpI;
            m_upLowestIdx = idx;
            m_upFlatStart = idx;
            upGain = 0;
         }
         
         if(downBottom < m_downHighest && downRetr > (long)m_maxRetrPoints) {
            m_downHighest = tpI;
            m_downHighestIdx = idx;
            m_downFlatStart = idx;
            downDrop = 0;
         }
         
         // === NOW CHECK IF VALID TREND CAN START ===
         if(upGain >= (long)m_minLengthPoints && upRetr <= (long)m_maxRetrPoints) {
            m_trendId++;
            m_inUptrend = true;
            m_upPeak = tpI;
            m_upPeakIdx = idx;
            m_upRetrStart = -1;
            
            LabelRangeUP(m_upFlatStart, idx);
            return;
         }
         
         if(downDrop >= (long)m_minLengthPoints && downRetr <= (long)m_maxRetrPoints) {
            m_trendId++;
            m_inDowntrend = true;
            m_downBottom = tpI;
            m_downBottomIdx = idx;
            m_downRetrStart = -1;
            
            LabelRangeDOWN(m_downFlatStart, idx);
            return;
         }
      }
      else if(m_inUptrend) {
         // === ACTIVE UPTREND ===
         
         if(tpI > m_upPeak) {
            // New high - continue uptrend
            if(m_upRetrStart >= 0) {
               LabelRangeUP(m_upRetrStart, idx - 1);
               m_upRetrStart = -1;
            }
            
            m_upPeak = tpI;
            m_upPeakIdx = idx;
            
            m_allTicks[idx].label = 1;
            m_allTicks[idx].trend_id = m_trendId;
            m_allTicks[idx].length_pips = PointsToPips(tpI - m_upLowest);
            m_allTicks[idx].info = "NEW HIGH";
            return;
         }
         
         // Price below peak - potential retracement
         if(m_upRetrStart < 0) {
            m_upRetrStart = idx;
         }
         
         long retr = m_upPeak - tpI;
         if(retr > (long)m_maxRetrPoints) {
            // Retracement exceeded - END uptrend
            m_inUptrend = false;
            
            m_upLowest = tpI;
            m_upLowestIdx = idx;
            m_upFlatStart = m_upRetrStart;
            m_upRetrStart = -1;
            
            m_downHighest = tpI;
            m_downHighestIdx = idx;
            m_downFlatStart = m_upFlatStart;
         }
         return;
      }
      else if(m_inDowntrend) {
         // === ACTIVE DOWNTREND ===
         
         if(tpI < m_downBottom) {
            // New low - continue downtrend
            if(m_downRetrStart >= 0) {
               LabelRangeDOWN(m_downRetrStart, idx - 1);
               m_downRetrStart = -1;
            }
            
            m_downBottom = tpI;
            m_downBottomIdx = idx;
            
            m_allTicks[idx].label = -1;
            m_allTicks[idx].trend_id = m_trendId;
            m_allTicks[idx].length_pips = PointsToPips(m_downHighest - tpI);
            m_allTicks[idx].info = "NEW LOW";
            return;
         }
         
         // Price above bottom - potential retracement
         if(m_downRetrStart < 0) {
            m_downRetrStart = idx;
         }
         
         long retr = tpI - m_downBottom;
         if(retr > (long)m_maxRetrPoints) {
            // Retracement exceeded - END downtrend
            m_inDowntrend = false;
            
            m_downHighest = tpI;
            m_downHighestIdx = idx;
            m_downFlatStart = m_downRetrStart;
            m_downRetrStart = -1;
            
            m_upLowest = tpI;
            m_upLowestIdx = idx;
            m_upFlatStart = m_downFlatStart;
         }
         return;
      }
   }
   
   void Finalize(TrendTickData &output[]) {
      ArrayResize(output, m_tickCount);
      for(int i = 0; i < m_tickCount; i++) {
         output[i] = m_allTicks[i];
      }
      
      PrintFormat("[FINALIZE] Complete: %d ticks output", m_tickCount);
   }

private:
   long RoundToPoints(double price) {
      if(m_scaleJPY) {
         return (long)MathRound(price * 1000.0);
      } else {
         return (long)MathRound(price * 100000.0);
      }
   }
   
   double PointsToPips(long points) {
      return (double)points / 10.0;
   }
   
   void LabelRangeUP(int startIdx, int endIdx) {
      for(int i = startIdx; i <= endIdx && i < m_tickCount; i++) {
         long tickTp = RoundToPoints(m_allTicks[i].tp);
         long length = tickTp - m_upLowest;
         
         m_allTicks[i].label = 1;
         m_allTicks[i].trend_id = m_trendId;
         m_allTicks[i].length_pips = PointsToPips(length);
         
         if(i == m_upLowestIdx) {
            m_allTicks[i].info = "ENTRY";
         } else if(i < m_upRetrStart || m_upRetrStart < 0) {
            m_allTicks[i].info = "NEW HIGH";
         } else {
            long retr = m_upPeak - tickTp;
            m_allTicks[i].info = "RETR:" + DoubleToString(PointsToPips(retr), 1);
         }
      }
   }
   
   void LabelRangeDOWN(int startIdx, int endIdx) {
      for(int i = startIdx; i <= endIdx && i < m_tickCount; i++) {
         long tickTp = RoundToPoints(m_allTicks[i].tp);
         long length = m_downHighest - tickTp;
         
         m_allTicks[i].label = -1;
         m_allTicks[i].trend_id = m_trendId;
         m_allTicks[i].length_pips = PointsToPips(length);
         
         if(i == m_downHighestIdx) {
            m_allTicks[i].info = "ENTRY";
         } else if(i < m_downRetrStart || m_downRetrStart < 0) {
            m_allTicks[i].info = "NEW LOW";
         } else {
            long retr = tickTp - m_downBottom;
            m_allTicks[i].info = "RETR:" + DoubleToString(PointsToPips(retr), 1);
         }
      }
   }
};

#endif