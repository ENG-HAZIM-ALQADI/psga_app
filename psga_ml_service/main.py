"""
PSGA ML Analysis Service
=========================
خدمة التحليل الذكي لتطبيق PSGA

الميزات:
- كشف الانحرافات باستخدام DBSCAN
- تحليل الأنماط الزمنية
- حساب درجة الخطورة
- تقديم توصيات ذكية
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List, Optional, Dict
from datetime import datetime
import numpy as np
from sklearn.cluster import DBSCAN
from collections import Counter
import logging

# استيراد وظائف التحسينات
from data_preprocessing import (
    remove_gps_jumps,
    remove_duplicates,
    analyze_speed,
    detect_stops,
    detect_deviation_segments,
    preprocess_and_analyze
)

# إعداد Logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# إنشاء التطبيق
app = FastAPI(
    title="PSGA ML Analysis Service",
    description="خدمة التحليل الذكي للكشف عن الانحرافات وتحليل الأنماط - V1.1 مع تحسينات البيانات",
    version="1.1.0"
)

# إعداد CORS للسماح بالطلبات من Flutter
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # في الإنتاج: حدد النطاقات المسموحة
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ==================== نماذج البيانات (Pydantic Models) ====================

class LocationPoint(BaseModel):
    """نقطة موقع GPS"""
    lat: float = Field(..., description="خط العرض", ge=-90, le=90)
    lng: float = Field(..., description="خط الطول", ge=-180, le=180)
    timestamp: Optional[str] = Field(None, description="الوقت بصيغة ISO 8601")
    speed: Optional[float] = Field(None, description="السرعة (كم/س)", ge=0)


class RouteAnalysisRequest(BaseModel):
    """طلب تحليل المسار"""
    route_id: str
    locations: List[LocationPoint] = Field(..., min_items=3)
    planned_route: List[LocationPoint] = Field(..., min_items=2)


class TripHistoryItem(BaseModel):
    """عنصر في سجل الرحلات"""
    trip_id: str
    start_time: str
    duration_minutes: int = Field(..., ge=0)
    route_id: str


class CurrentTrip(BaseModel):
    """الرحلة الحالية"""
    start_time: str
    route_id: str


class PatternAnalysisRequest(BaseModel):
    """طلب تحليل الأنماط"""
    user_id: str
    trips_history: List[TripHistoryItem]
    current_trip: CurrentTrip


class ComprehensiveAnalysisRequest(BaseModel):
    """طلب تحليل شامل"""
    trip: Dict
    user_history: Dict


class AnomalyDetail(BaseModel):
    """تفاصيل شذوذ"""
    type: str
    message: str
    severity: str


# ==================== وظائف مساعدة ====================

def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    حساب المسافة بين نقطتين GPS بالمتر
    باستخدام صيغة Haversine
    """
    R = 6371000  # نصف قطر الأرض بالمتر
    
    # تحويل لراديان
    lat1_rad = np.radians(lat1)
    lat2_rad = np.radians(lat2)
    delta_lat = np.radians(lat2 - lat1)
    delta_lon = np.radians(lon2 - lon1)
    
    # صيغة Haversine
    a = (np.sin(delta_lat / 2) ** 2 +
         np.cos(lat1_rad) * np.cos(lat2_rad) *
         np.sin(delta_lon / 2) ** 2)
    
    c = 2 * np.arctan2(np.sqrt(a), np.sqrt(1 - a))
    distance = R * c
    
    return distance


def calculate_min_distance_to_route(point: np.ndarray, route_points: np.ndarray) -> float:
    """حساب أقل مسافة من نقطة إلى المسار المخطط"""
    distances = []
    for route_point in route_points:
        dist = haversine_distance(
            point[0], point[1],
            route_point[0], route_point[1]
        )
        distances.append(dist)
    return min(distances)


# ==================== 1. تحليل المسار بـ DBSCAN ====================

@app.post("/analyze-route")
async def analyze_route(request: RouteAnalysisRequest):
    """
    تحليل المسار وكشف النقاط الشاذة باستخدام DBSCAN + تحسينات V1.1
    
    التحسينات الجديدة:
    1. تنظيف البيانات (إزالة قفزات GPS والتكرارات)
    2. تحليل السرعة المتقدم
    3. كشف التوقفات الطويلة
    4. تحديد مقاطع الانحراف المتتالية
    5. حساب درجة خطر محسّنة
    
    الخوارزمية:
    1. استخدام DBSCAN لكشف النقاط المنعزلة (Noise)
    2. حساب متوسط الانحراف عن المسار المخطط
    3. حساب درجة الخطورة
    4. تصنيف مستوى الخطر والإجراء الموصى به
    """
    try:
        logger.info(f"[RouteAnalysis] تحليل المسار: {request.route_id}")
        
        # ==================== تنظيف البيانات (جديد V1.1) ====================
        # تحويل LocationPoint إلى Dict
        locations_dict = [
            {
                "lat": loc.lat,
                "lng": loc.lng,
                "timestamp": loc.timestamp,
                "speed": loc.speed
            }
            for loc in request.locations
        ]
        
        # تطبيق التنظيف والتحليل المتقدم
        preprocessing_result = preprocess_and_analyze(locations_dict)
        cleaned_locations = preprocessing_result['cleaned_locations']
        cleaning_stats = preprocessing_result['cleaning_stats']
        speed_analysis = preprocessing_result['speed_analysis']
        stops_analysis = preprocessing_result['stops_analysis']
        advanced_risk = preprocessing_result['total_risk_contribution']
        
        logger.info(f"[Cleaning] تم تنظيف البيانات: {cleaning_stats['removed_jumps']} قفزات، {cleaning_stats['removed_duplicates']} تكرارات")
        
        # تحويل المواقع إلى مصفوفة numpy
        coords = np.array([[loc['lat'], loc['lng']] for loc in cleaned_locations])
        planned_coords = np.array([[loc.lat, loc.lng] for loc in request.planned_route])
        
        # التحقق من وجود بيانات كافية بعد التنظيف
        if len(coords) < 3:
            raise HTTPException(
                status_code=400, 
                detail=f"عدد النقاط غير كافٍ للتحليل بعد التنظيف ({len(coords)} نقاط)"
            )
        
        # ==================== DBSCAN للكشف عن النقاط الشاذة ====================
        db = DBSCAN(eps=0.0005, min_samples=3).fit(coords)
        
        anomaly_mask = db.labels_ == -1
        anomaly_count = np.sum(anomaly_mask)
        anomaly_percentage = (anomaly_count / len(coords)) * 100
        
        logger.info(f"[DBSCAN] نقاط شاذة: {anomaly_count}/{len(coords)} ({anomaly_percentage:.1f}%)")
        
        # ==================== حساب الانحراف عن المسار المخطط ====================
        deviations = []
        for coord in coords:
            min_dist = calculate_min_distance_to_route(coord, planned_coords)
            deviations.append(min_dist)
        
        avg_deviation = np.mean(deviations)
        max_deviation = np.max(deviations)
        
        logger.info(f"[Deviation] متوسط: {avg_deviation:.1f}م، أقصى: {max_deviation:.1f}م")
        
        # ==================== كشف مقاطع الانحراف (جديد V1.1) ====================
        segments_analysis = detect_deviation_segments(
            deviations,
            cleaned_locations,
            threshold_m=50.0,
            min_consecutive=3
        )
        
        if segments_analysis['has_segments']:
            logger.info(f"[Segments] تم اكتشاف {segments_analysis['total_segments']} مقطع انحراف")
        
        # ==================== حساب درجة الخطورة المحسّنة (0-100) ====================
        # الحساب الأساسي (60% من المجموع)
        anomaly_score = min(100, anomaly_percentage * 2)
        deviation_score = min(100, (avg_deviation / 50) * 100)
        basic_risk = (anomaly_score * 0.4) + (deviation_score * 0.6)
        
        # المخاطر الإضافية من التحليلات المتقدمة (40% من المجموع)
        # توزيع: 15% سرعة، 10% توقفات، 15% مقاطع
        speed_contribution = speed_analysis.get('risk_score', 0) * 0.375  # 15/40
        stops_contribution = stops_analysis.get('risk_score', 0) * 0.25   # 10/40
        segments_contribution = segments_analysis.get('risk_score', 0) * 0.375  # 15/40
        
        additional_risk = speed_contribution + stops_contribution + segments_contribution
        
        # الخطر النهائي (60% أساسي + 40% إضافي)
        risk_score = (basic_risk * 0.6) + (additional_risk * 0.4)
        risk_score = min(100, risk_score)  # للتأكد أنها لا تتجاوز 100
        
        # ==================== تصنيف مستوى الخطر ====================
        if risk_score < 25:
            risk_level = "low"
            action = "مراقبة عادية"
            color = "#4CAF50"
        elif risk_score < 50:
            risk_level = "medium"
            action = "تنبيه خفيف"
            color = "#FF9800"
        elif risk_score < 75:
            risk_level = "high"
            action = "تنبيه عالي"
            color = "#F44336"
        else:
            risk_level = "critical"
            action = "إجراء طوارئ فوري"
            color = "#B71C1C"
        
        logger.info(f"[Result] خطر: {risk_score:.1f}/100 ({risk_level}) - أساسي: {basic_risk:.1f}, إضافي: {additional_risk:.1f}")
        
        # ==================== النتيجة المحسّنة ====================
        return {
            "route_id": request.route_id,
            "timestamp": datetime.now().isoformat(),
            "version": "1.1.0",
            "analysis": {
                # معلومات أساسية
                "original_points": len(request.locations),
                "analyzed_points": len(coords),
                "removed_points": len(request.locations) - len(coords),
                
                # DBSCAN
                "anomaly_count": int(anomaly_count),
                "anomaly_percentage": round(anomaly_percentage, 2),
                
                # الانحراف
                "avg_deviation_meters": round(avg_deviation, 2),
                "max_deviation_meters": round(max_deviation, 2),
                
                # درجة الخطر
                "risk_score": round(risk_score, 2),
                "basic_risk_score": round(basic_risk, 2),
                "advanced_risk_score": round(additional_risk, 2),
                "risk_level": risk_level,
                "risk_color": color,
                "recommended_action": action
            },
            "advanced_analysis": {
                "data_cleaning": cleaning_stats,
                "speed_analysis": speed_analysis if speed_analysis['has_data'] else None,
                "stops_analysis": stops_analysis if stops_analysis['has_stops'] else None,
                "deviation_segments": segments_analysis if segments_analysis['has_segments'] else None
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Error] فشل تحليل المسار: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ==================== 2. تحليل الأنماط الزمنية ====================

@app.post("/analyze-patterns")
async def analyze_patterns(request: PatternAnalysisRequest):
    """
    تحليل أنماط المستخدم وكشف السلوك غير المعتاد
    
    التحليل:
    1. استخراج الأنماط المعتادة (الساعات، الأيام، المسارات)
    2. مقارنة الرحلة الحالية بالأنماط
    3. كشف الشذوذ الزمني والمكاني
    """
    try:
        logger.info(f"[PatternAnalysis] تحليل أنماط المستخدم: {request.user_id}")
        
        trips = request.trips_history
        
        # التحقق من وجود سجل كافٍ
        if len(trips) < 3:
            logger.warning("[PatternAnalysis] سجل غير كافٍ - استخدام افتراضيات")
            return {
                "user_id": request.user_id,
                "patterns": {
                    "most_common_hour": 12,
                    "most_common_day": 0,
                    "avg_duration": 30,
                    "total_trips": len(trips)
                },
                "current_analysis": {
                    "is_unusual": False,
                    "anomalies": [],
                    "anomaly_score": 0,
                    "recommendation": "بيانات غير كافية للتحليل"
                }
            }
        
        # ==================== استخراج الأنماط ====================
        hours = []
        days = []
        durations = []
        routes = []
        
        for trip in trips:
            try:
                dt = datetime.fromisoformat(trip.start_time.replace('Z', '+00:00'))
                hours.append(dt.hour)
                days.append(dt.weekday())
                durations.append(trip.duration_minutes)
                routes.append(trip.route_id)
            except Exception as e:
                logger.warning(f"[PatternAnalysis] تخطي رحلة غير صالحة: {e}")
                continue
        
        # الأنماط المعتادة
        patterns = {
            "most_common_hour": Counter(hours).most_common(1)[0][0] if hours else 12,
            "most_common_day": Counter(days).most_common(1)[0][0] if days else 0,
            "avg_duration": round(np.mean(durations), 1) if durations else 30,
            "most_frequent_route": Counter(routes).most_common(1)[0][0] if routes else None,
            "total_trips": len(trips),
            "hour_distribution": dict(Counter(hours)),
            "day_distribution": dict(Counter(days))
        }
        
        logger.info(f"[Patterns] ساعة معتادة: {patterns['most_common_hour']}:00")
        
        # ==================== تحليل الرحلة الحالية ====================
        current = request.current_trip
        current_dt = datetime.fromisoformat(current.start_time.replace('Z', '+00:00'))
        current_hour = current_dt.hour
        current_day = current_dt.weekday()
        
        anomalies = []
        anomaly_score = 0
        
        # 1. فحص الوقت
        hour_diff = min(
            abs(current_hour - patterns['most_common_hour']),
            24 - abs(current_hour - patterns['most_common_hour'])
        )
        
        if hour_diff > 3:
            severity = "high" if hour_diff > 6 else "medium"
            anomalies.append({
                "type": "unusual_time",
                "message": f"رحلة في وقت غير معتاد ({current_hour:02d}:00 بدلاً من {patterns['most_common_hour']:02d}:00)",
                "severity": severity
            })
            anomaly_score += 30 if severity == "high" else 20
            logger.warning(f"[Anomaly] وقت غير معتاد: فرق {hour_diff} ساعات")
        
        # 2. فحص اليوم
        if current_day not in patterns['day_distribution']:
            anomalies.append({
                "type": "unusual_day",
                "message": "رحلة في يوم غير معتاد من الأسبوع",
                "severity": "low"
            })
            anomaly_score += 10
        
        # 3. فحص المسار
        if patterns['most_frequent_route'] and current.route_id != patterns['most_frequent_route']:
            # التحقق إذا كان المسار جديد تماماً
            if current.route_id not in routes:
                anomalies.append({
                    "type": "new_route",
                    "message": "مسار جديد لم يُستخدم من قبل",
                    "severity": "medium"
                })
                anomaly_score += 25
            else:
                anomalies.append({
                    "type": "different_route",
                    "message": "مسار مختلف عن المعتاد",
                    "severity": "low"
                })
                anomaly_score += 10
        
        # ==================== التوصية ====================
        if anomaly_score < 20:
            recommendation = "رحلة عادية"
        elif anomaly_score < 40:
            recommendation = "مراقبة خفيفة"
        elif anomaly_score < 60:
            recommendation = "تنبيه جهات الاتصال"
        else:
            recommendation = "مراقبة دقيقة - سلوك غير معتاد جداً"
        
        logger.info(f"[Result] شذوذ: {anomaly_score}/100، توصية: {recommendation}")
        
        return {
            "user_id": request.user_id,
            "timestamp": datetime.now().isoformat(),
            "patterns": patterns,
            "current_analysis": {
                "is_unusual": len(anomalies) > 0,
                "anomalies": anomalies,
                "anomaly_score": anomaly_score,
                "recommendation": recommendation
            }
        }
        
    except Exception as e:
        logger.error(f"[Error] فشل تحليل الأنماط: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


# ==================== 3. تحليل شامل ====================

@app.post("/comprehensive-analysis")
async def comprehensive_analysis(request: ComprehensiveAnalysisRequest):
    """
    تحليل شامل يجمع كل الخوارزميات
    """
    try:
        logger.info(f"[Comprehensive] بدء التحليل الشامل")
        
        # 1. تحليل المسار
        route_request = RouteAnalysisRequest(
            route_id=request.trip['trip_id'],
            locations=[LocationPoint(**loc) for loc in request.trip['locations']],
            planned_route=[LocationPoint(**loc) for loc in request.trip['planned_route']]
        )
        route_analysis = await analyze_route(route_request)
        
        # 2. تحليل الأنماط
        pattern_request = PatternAnalysisRequest(
            user_id=request.trip['user_id'],
            trips_history=[TripHistoryItem(**t) for t in request.user_history['trips']],
            current_trip=CurrentTrip(
                start_time=request.trip['start_time'],
                route_id=request.trip['trip_id']
            )
        )
        pattern_analysis = await analyze_patterns(pattern_request)
        
        # 3. حساب الخطر الإجمالي
        route_risk = route_analysis['analysis']['risk_score']
        pattern_risk = pattern_analysis['current_analysis']['anomaly_score']
        
        # وزن أكبر لتحليل المسار (70%) لأنه أكثر موضوعية
        overall_risk = (route_risk * 0.7) + (pattern_risk * 0.3)
        
        # 4. القرار النهائي
        if overall_risk < 25:
            final_action = "normal"
            alert_level = "none"
            alert_message = "كل شيء طبيعي ✓"
        elif overall_risk < 50:
            final_action = "monitor"
            alert_level = "low"
            alert_message = "مراقبة خفيفة"
        elif overall_risk < 75:
            final_action = "notify_user"
            alert_level = "medium"
            alert_message = "تنبيه المستخدم وجهات الاتصال"
        else:
            final_action = "emergency_alert"
            alert_level = "high"
            alert_message = "⚠️ إجراء طوارئ فوري!"
        
        logger.info(f"[Final] خطر إجمالي: {overall_risk:.1f}/100 ({alert_level})")
        
        return {
            "trip_id": request.trip['trip_id'],
            "user_id": request.trip['user_id'],
            "timestamp": datetime.now().isoformat(),
            "overall_risk_score": round(overall_risk, 2),
            "alert_level": alert_level,
            "alert_message": alert_message,
            "recommended_action": final_action,
            "details": {
                "route_analysis": route_analysis,
                "pattern_analysis": pattern_analysis
            }
        }
        
    except Exception as e:
        logger.error(f"[Error] فشل التحليل الشامل: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


# ==================== 4. Health Check ====================

@app.get("/")
async def root():
    """الصفحة الرئيسية"""
    return {
        "service": "PSGA ML Analysis Service",
        "version": "1.1.0",
        "status": "running",
        "features": [
            "DBSCAN anomaly detection",
            "GPS jump removal",
            "Duplicate removal",
            "Speed analysis",
            "Stop detection",
            "Deviation segments"
        ],
        "endpoints": {
            "route_analysis": "/analyze-route",
            "pattern_analysis": "/analyze-patterns",
            "comprehensive": "/comprehensive-analysis",
            "health": "/health",
            "docs": "/docs"
        }
    }


@app.get("/health")
async def health():
    """فحص صحة الخدمة"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "service": "ML Analysis",
        "dependencies": {
            "numpy": np.__version__,
            "sklearn": "1.4.0"
        }
    }


# ==================== تشغيل الخادم ====================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
