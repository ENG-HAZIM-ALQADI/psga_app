"""
PSGA ML Service - Data Preprocessing & Enhancements
====================================================
وظائف تنظيف وتحسين البيانات للإصدار V1.1

الميزات:
1. إزالة قفزات GPS غير الواقعية
2. إزالة النقاط المكررة
3. تحليل السرعة وكشف الشذوذات
4. كشف التوقفات الطويلة
5. تحديد مقاطع الانحراف المتتالية
"""

import numpy as np
from typing import List, Dict, Tuple, Optional
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    حساب المسافة بين نقطتين GPS بالمتر
    باستخدام صيغة Haversine
    
    Args:
        lat1, lon1: إحداثيات النقطة الأولى
        lat2, lon2: إحداثيات النقطة الثانية
    
    Returns:
        المسافة بالمتر
    """
    R = 6371000  # نصف قطر الأرض بالمتر
    
    lat1_rad = np.radians(lat1)
    lat2_rad = np.radians(lat2)
    delta_lat = np.radians(lat2 - lat1)
    delta_lon = np.radians(lon2 - lon1)
    
    a = (np.sin(delta_lat / 2) ** 2 +
         np.cos(lat1_rad) * np.cos(lat2_rad) *
         np.sin(delta_lon / 2) ** 2)
    
    c = 2 * np.arctan2(np.sqrt(a), np.sqrt(1 - a))
    return R * c


# ==================== 1. إزالة قفزات GPS ====================

def remove_gps_jumps(locations: List[Dict], max_jump_km: float = 1.0) -> Tuple[List[Dict], Dict]:
    """
    إزالة القفزات غير الواقعية في GPS
    
    القفزة غير الواقعية: انتقال سريع جداً لا يمكن تحقيقه
    مثلاً: قفزة 50 كم في ثانية واحدة
    
    Args:
        locations: قائمة المواقع [{lat, lng, timestamp, ...}, ...]
        max_jump_km: الحد الأقصى للقفزة المقبولة (كم)
    
    Returns:
        (قائمة منظفة, إحصائيات)
    """
    if not locations or len(locations) < 2:
        return locations, {"removed": 0, "jumps": []}
    
    cleaned = [locations[0]]
    removed_jumps = []
    
    for i in range(1, len(locations)):
        prev = cleaned[-1]
        curr = locations[i]
        
        # حساب المسافة
        dist_km = haversine_distance(
            prev['lat'], prev['lng'],
            curr['lat'], curr['lng']
        ) / 1000
        
        # حساب الوقت بين النقطتين (إذا متوفر)
        time_diff_sec = None
        if 'timestamp' in prev and 'timestamp' in curr:
            try:
                prev_time = datetime.fromisoformat(prev['timestamp'].replace('Z', '+00:00'))
                curr_time = datetime.fromisoformat(curr['timestamp'].replace('Z', '+00:00'))
                time_diff_sec = (curr_time - prev_time).total_seconds()
            except:
                pass
        
        # قرار: احتفظ أو احذف
        is_jump = False
        reason = ""
        
        # فحص 1: مسافة كبيرة جداً
        if dist_km > max_jump_km:
            is_jump = True
            reason = f"مسافة كبيرة: {dist_km:.2f} كم"
        
        # فحص 2: سرعة غير واقعية (إذا الوقت متوفر)
        if time_diff_sec and time_diff_sec > 0:
            speed_kmh = (dist_km / time_diff_sec) * 3600
            # سرعة > 200 كم/س غير واقعية للسيارات في المدينة
            if speed_kmh > 200:
                is_jump = True
                reason = f"سرعة غير واقعية: {speed_kmh:.0f} كم/س"
        
        if is_jump:
            removed_jumps.append({
                "index": i,
                "from_location": {"lat": prev['lat'], "lng": prev['lng']},
                "to_location": {"lat": curr['lat'], "lng": curr['lng']},
                "distance_km": round(dist_km, 2),
                "reason": reason
            })
            logger.warning(f"[GPS Jump] تم إزالة قفزة: {reason}")
        else:
            cleaned.append(curr)
    
    stats = {
        "original_count": len(locations),
        "cleaned_count": len(cleaned),
        "removed_count": len(removed_jumps),
        "removal_percentage": round((len(removed_jumps) / len(locations)) * 100, 2),
        "jumps_details": removed_jumps
    }
    
    if removed_jumps:
        logger.info(f"[GPS Jump] تم إزالة {len(removed_jumps)} قفزات ({stats['removal_percentage']:.1f}%)")
    
    return cleaned, stats


# ==================== 2. إزالة التكرارات ====================

def remove_duplicates(locations: List[Dict], min_distance_m: float = 5.0) -> Tuple[List[Dict], Dict]:
    """
    إزالة النقاط المتطابقة أو القريبة جداً
    
    النقاط المتطابقة تحدث عندما:
    - GPS يرسل نفس الموقع عدة مرات
    - المستخدم واقف في نفس المكان
    - دقة GPS منخفضة
    
    Args:
        locations: قائمة المواقع
        min_distance_m: الحد الأدنى للمسافة بين النقاط (متر)
    
    Returns:
        (قائمة بدون تكرارات, إحصائيات)
    """
    if not locations:
        return [], {"removed": 0}
    
    unique = [locations[0]]
    removed_count = 0
    
    for loc in locations[1:]:
        prev = unique[-1]
        
        # حساب المسافة
        dist = haversine_distance(
            prev['lat'], prev['lng'],
            loc['lat'], loc['lng']
        )
        
        # احتفظ فقط إذا كانت المسافة كافية
        if dist >= min_distance_m:
            unique.append(loc)
        else:
            removed_count += 1
    
    stats = {
        "original_count": len(locations),
        "unique_count": len(unique),
        "removed_count": removed_count,
        "removal_percentage": round((removed_count / len(locations)) * 100, 2) if locations else 0
    }
    
    if removed_count > 0:
        logger.info(f"[Duplicates] تم إزالة {removed_count} نقطة مكررة ({stats['removal_percentage']:.1f}%)")
    
    return unique, stats


# ==================== 3. تحليل السرعة ====================

def analyze_speed(locations: List[Dict]) -> Dict:
    """
    تحليل السرعات وكشف الشذوذات
    
    أنواع الشذوذات:
    1. السرعة العالية جداً (> 120 كم/س في المدينة)
    2. السرعة البطيئة جداً لفترة طويلة
    3. التباين العالي (قيادة عنيفة)
    4. تغييرات مفاجئة (تسارع/تباطؤ حاد)
    
    Args:
        locations: قائمة المواقع مع السرعات [{..., speed}, ...]
    
    Returns:
        تحليل شامل للسرعة
    """
    # استخراج السرعات
    speeds = [loc.get('speed', 0) for loc in locations if loc.get('speed') is not None and loc.get('speed') > 0]
    
    if not speeds or len(speeds) < 3:
        return {
            "has_data": False,
            "has_anomaly": False,
            "anomalies": [],
            "stats": None,
            "risk_score": 0
        }
    
    # حساب الإحصائيات
    avg_speed = np.mean(speeds)
    max_speed = np.max(speeds)
    min_speed = np.min(speeds)
    std_speed = np.std(speeds)
    median_speed = np.median(speeds)
    
    anomalies = []
    risk_score = 0
    
    # 1. سرعة عالية جداً
    if max_speed > 120:
        severity = "critical" if max_speed > 150 else "high"
        anomalies.append({
            "type": "excessive_speed",
            "message": f"سرعة عالية جداً: {max_speed:.0f} كم/س",
            "value": max_speed,
            "severity": severity,
            "threshold": 120
        })
        risk_score += 30 if severity == "critical" else 20
        logger.warning(f"[Speed] سرعة عالية: {max_speed:.0f} كم/س")
    
    # 2. سرعة بطيئة لفترة طويلة (احتمال ازدحام أو مشكلة)
    slow_count = sum(1 for s in speeds if 0 < s < 15)
    slow_percentage = (slow_count / len(speeds)) * 100
    
    if slow_percentage > 40:  # أكثر من 40% من الوقت بطيء
        anomalies.append({
            "type": "excessive_slow_driving",
            "message": f"سرعة بطيئة لفترة طويلة: {slow_percentage:.0f}% من الوقت",
            "value": slow_percentage,
            "severity": "medium",
            "threshold": 40
        })
        risk_score += 10
    
    # 3. تباين عالي (قيادة غير منتظمة)
    if std_speed > 35:
        severity = "high" if std_speed > 50 else "medium"
        anomalies.append({
            "type": "erratic_driving",
            "message": f"قيادة غير منتظمة (تباين عالي: {std_speed:.0f})",
            "value": std_speed,
            "severity": severity,
            "threshold": 35
        })
        risk_score += 15 if severity == "high" else 10
        logger.warning(f"[Speed] قيادة غير منتظمة: تباين {std_speed:.0f}")
    
    # 4. تغييرات مفاجئة في السرعة
    if len(speeds) >= 2:
        speed_changes = [abs(speeds[i] - speeds[i-1]) for i in range(1, len(speeds))]
        max_change = max(speed_changes) if speed_changes else 0
        
        # تغيير أكثر من 40 كم/س دفعة واحدة
        if max_change > 40:
            severity = "high" if max_change > 60 else "medium"
            anomalies.append({
                "type": "sudden_speed_change",
                "message": f"تغيير مفاجئ في السرعة: {max_change:.0f} كم/س",
                "value": max_change,
                "severity": severity,
                "threshold": 40
            })
            risk_score += 15 if severity == "high" else 10
    
    # حساب النسبة المئوية لكل فئة سرعة
    speed_distribution = {
        "stopped_or_very_slow": sum(1 for s in speeds if s < 10) / len(speeds) * 100,
        "slow": sum(1 for s in speeds if 10 <= s < 30) / len(speeds) * 100,
        "moderate": sum(1 for s in speeds if 30 <= s < 60) / len(speeds) * 100,
        "fast": sum(1 for s in speeds if 60 <= s < 100) / len(speeds) * 100,
        "very_fast": sum(1 for s in speeds if s >= 100) / len(speeds) * 100
    }
    
    return {
        "has_data": True,
        "has_anomaly": len(anomalies) > 0,
        "anomalies": anomalies,
        "anomaly_count": len(anomalies),
        "stats": {
            "avg_speed_kmh": round(avg_speed, 1),
            "max_speed_kmh": round(max_speed, 1),
            "min_speed_kmh": round(min_speed, 1),
            "median_speed_kmh": round(median_speed, 1),
            "std_deviation": round(std_speed, 1),
            "speed_distribution": {k: round(v, 1) for k, v in speed_distribution.items()}
        },
        "risk_score": min(risk_score, 40)  # أقصى 40 نقطة من السرعة
    }


# ==================== 4. كشف التوقفات ====================

def detect_stops(locations: List[Dict], 
                 max_distance_m: float = 20.0,
                 min_duration_sec: float = 180) -> Dict:
    """
    كشف التوقفات الطويلة
    
    التوقف: عدم حركة (< 20م) لمدة طويلة (> 3 دقائق)
    
    أنواع التوقفات:
    - عادي: 3-10 دقائق (إشارة مرور، محطة وقود)
    - طويل: 10-30 دقيقة (قد يكون طبيعي أو غير طبيعي)
    - غير عادي: > 30 دقيقة (يحتاج انتباه)
    
    Args:
        locations: قائمة المواقع مع timestamps
        max_distance_m: الحد الأقصى للحركة أثناء التوقف (متر)
        min_duration_sec: الحد الأدنى لمدة التوقف (ثانية)
    
    Returns:
        معلومات التوقفات
    """
    if len(locations) < 2:
        return {"has_stops": False, "stops": [], "risk_score": 0}
    
    stops = []
    i = 0
    
    while i < len(locations) - 1:
        stop_start = i
        stop_location = locations[i]
        
        # التحقق من وجود timestamp
        if 'timestamp' not in locations[i]:
            i += 1
            continue
        
        # البحث عن نهاية التوقف
        j = i + 1
        while j < len(locations):
            if 'timestamp' not in locations[j]:
                j += 1
                continue
            
            # حساب المسافة
            dist = haversine_distance(
                stop_location['lat'], stop_location['lng'],
                locations[j]['lat'], locations[j]['lng']
            )
            
            # إذا تحرك بعيداً، انتهى التوقف
            if dist > max_distance_m:
                break
            
            j += 1
        
        # حساب مدة التوقف
        if j > i + 1:
            try:
                start_time = datetime.fromisoformat(locations[i]['timestamp'].replace('Z', '+00:00'))
                end_time = datetime.fromisoformat(locations[j-1]['timestamp'].replace('Z', '+00:00'))
                duration_sec = (end_time - start_time).total_seconds()
                
                # إذا كان توقف طويل بما يكفي
                if duration_sec >= min_duration_sec:
                    duration_min = duration_sec / 60
                    
                    # تصنيف التوقف
                    if duration_min < 10:
                        category = "normal"
                        severity = "low"
                        is_unusual = False
                    elif duration_min < 30:
                        category = "long"
                        severity = "medium"
                        is_unusual = True
                    else:
                        category = "very_long"
                        severity = "high"
                        is_unusual = True
                    
                    stops.append({
                        "location": {
                            "lat": stop_location['lat'],
                            "lng": stop_location['lng']
                        },
                        "start_index": stop_start,
                        "end_index": j - 1,
                        "duration_seconds": round(duration_sec, 0),
                        "duration_minutes": round(duration_min, 1),
                        "category": category,
                        "severity": severity,
                        "is_unusual": is_unusual,
                        "message": f"توقف {category} لمدة {duration_min:.0f} دقيقة"
                    })
                    
                    if is_unusual:
                        logger.warning(f"[Stop] توقف غير عادي: {duration_min:.0f} دقيقة")
            
            except Exception as e:
                logger.error(f"[Stop] خطأ في معالجة التوقف: {e}")
        
        i = j if j > i + 1 else i + 1
    
    # حساب المخاطر
    risk_score = 0
    unusual_stops = [s for s in stops if s['is_unusual']]
    
    for stop in unusual_stops:
        if stop['severity'] == 'high':
            risk_score += 20
        elif stop['severity'] == 'medium':
            risk_score += 10
    
    total_stop_duration = sum(s['duration_minutes'] for s in stops)
    
    return {
        "has_stops": len(stops) > 0,
        "stops": stops,
        "total_stops": len(stops),
        "unusual_stops": len(unusual_stops),
        "total_stop_duration_minutes": round(total_stop_duration, 1),
        "longest_stop_minutes": round(max([s['duration_minutes'] for s in stops]), 1) if stops else 0,
        "risk_score": min(risk_score, 30)  # أقصى 30 نقطة من التوقفات
    }


# ==================== 5. مقاطع الانحراف المتتالية ====================

def detect_deviation_segments(deviations: List[float],
                               locations: List[Dict],
                               threshold_m: float = 50.0,
                               min_consecutive: int = 3) -> Dict:
    """
    إيجاد مقاطع الانحراف المتتالية
    
    المقطع: عدة نقاط متتالية (≥3) بانحراف عالي (>50م)
    
    هذا يساعد في:
    - تحديد مناطق الخطر الدقيقة
    - فهم نمط الانحراف (مستمر أم متقطع)
    - تحسين التنبيهات (تنبيه واحد للمقطع بدلاً من عدة تنبيهات)
    
    Args:
        deviations: قائمة الانحرافات (متر)
        locations: قائمة المواقع المقابلة
        threshold_m: حد الانحراف (متر)
        min_consecutive: الحد الأدنى للنقاط المتتالية
    
    Returns:
        معلومات المقاطع
    """
    if not deviations or len(deviations) < min_consecutive:
        return {"has_segments": False, "segments": [], "risk_score": 0}
    
    segments = []
    current_segment = []
    
    for i, deviation in enumerate(deviations):
        if deviation > threshold_m:
            current_segment.append(i)
        else:
            # إذا انتهى المقطع وكان طويل بما يكفي
            if len(current_segment) >= min_consecutive:
                segment = _create_segment(current_segment, deviations, locations)
                segments.append(segment)
            
            current_segment = []
    
    # تحقق من المقطع الأخير
    if len(current_segment) >= min_consecutive:
        segment = _create_segment(current_segment, deviations, locations)
        segments.append(segment)
    
    # حساب المخاطر
    risk_score = 0
    for seg in segments:
        if seg['severity'] == 'critical':
            risk_score += 25
        elif seg['severity'] == 'high':
            risk_score += 15
        else:
            risk_score += 8
    
    if segments:
        logger.info(f"[Deviation Segments] تم اكتشاف {len(segments)} مقطع انحراف")
    
    return {
        "has_segments": len(segments) > 0,
        "segments": segments,
        "total_segments": len(segments),
        "longest_segment_length": max([s['length'] for s in segments]) if segments else 0,
        "total_deviation_points": sum([s['length'] for s in segments]),
        "risk_score": min(risk_score, 40)  # أقصى 40 نقطة من المقاطع
    }


def _create_segment(indices: List[int], deviations: List[float], locations: List[Dict]) -> Dict:
    """إنشاء كائن مقطع من قائمة الفهارس"""
    segment_deviations = [deviations[j] for j in indices]
    
    avg_dev = np.mean(segment_deviations)
    max_dev = np.max(segment_deviations)
    min_dev = np.min(segment_deviations)
    
    # تصنيف الخطورة
    if max_dev > 200:
        severity = "critical"
    elif max_dev > 100:
        severity = "high"
    else:
        severity = "medium"
    
    return {
        "start_index": indices[0],
        "end_index": indices[-1],
        "length": len(indices),
        "avg_deviation_m": round(avg_dev, 1),
        "max_deviation_m": round(max_dev, 1),
        "min_deviation_m": round(min_dev, 1),
        "severity": severity,
        "start_location": {
            "lat": locations[indices[0]]['lat'],
            "lng": locations[indices[0]]['lng']
        },
        "end_location": {
            "lat": locations[indices[-1]]['lat'],
            "lng": locations[indices[-1]]['lng']
        }
    }


# ==================== دالة شاملة للتنظيف والتحليل ====================

def preprocess_and_analyze(locations: List[Dict]) -> Dict:
    """
    دالة شاملة لتنظيف البيانات والتحليل المتقدم
    
    تطبق جميع التحسينات بالترتيب:
    1. إزالة قفزات GPS
    2. إزالة التكرارات
    3. تحليل السرعة
    4. كشف التوقفات
    
    Args:
        locations: قائمة المواقع الأولية
    
    Returns:
        {
            "cleaned_locations": المواقع المنظفة,
            "cleaning_stats": إحصائيات التنظيف,
            "speed_analysis": تحليل السرعة,
            "stops_analysis": تحليل التوقفات,
            "total_risk_contribution": مساهمة إجمالية في درجة الخطر
        }
    """
    logger.info(f"[Preprocessing] بدء معالجة {len(locations)} نقطة")
    
    # 1. إزالة قفزات GPS
    cleaned_locs, jump_stats = remove_gps_jumps(locations, max_jump_km=1.0)
    
    # 2. إزالة التكرارات
    cleaned_locs, dup_stats = remove_duplicates(cleaned_locs, min_distance_m=5.0)
    
    # 3. تحليل السرعة
    speed_analysis = analyze_speed(cleaned_locs)
    
    # 4. كشف التوقفات
    stops_analysis = detect_stops(cleaned_locs, max_distance_m=20.0, min_duration_sec=180)
    
    # حساب المساهمة الإجمالية في درجة الخطر
    total_risk = (
        speed_analysis.get('risk_score', 0) +
        stops_analysis.get('risk_score', 0)
    )
    
    logger.info(f"[Preprocessing] اكتمل - {len(cleaned_locs)} نقطة نظيفة، خطر إضافي: {total_risk}")
    
    return {
        "cleaned_locations": cleaned_locs,
        "cleaning_stats": {
            "original_count": len(locations),
            "cleaned_count": len(cleaned_locs),
            "removed_jumps": jump_stats['removed_count'],
            "removed_duplicates": dup_stats['removed_count'],
            "total_removed": len(locations) - len(cleaned_locs),
            "removal_percentage": round(((len(locations) - len(cleaned_locs)) / len(locations)) * 100, 2) if locations else 0
        },
        "speed_analysis": speed_analysis,
        "stops_analysis": stops_analysis,
        "total_risk_contribution": total_risk
    }
