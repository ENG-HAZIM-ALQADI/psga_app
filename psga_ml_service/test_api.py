"""
اختبار API للتحقق من عمل الخدمة
"""

import requests
import json
from datetime import datetime, timedelta

# عنوان الخادم (غيّره حسب بيئتك)
BASE_URL = "http://localhost:8000"  # للتطوير المحلي
# BASE_URL = "https://your-app.railway.app"  # للإنتاج

def test_health():
    """اختبار Health Check"""
    print("\n=== اختبار Health Check ===")
    response = requests.get(f"{BASE_URL}/health")
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2, ensure_ascii=False)}")
    return response.status_code == 200


def test_route_analysis():
    """اختبار تحليل المسار"""
    print("\n=== اختبار تحليل المسار ===")
    
    # بيانات تجريبية - مسار من الرياض
    data = {
        "route_id": "test_route_001",
        "locations": [
            {"lat": 24.7136, "lng": 46.6753, "timestamp": "2026-02-15T10:00:00"},
            {"lat": 24.7140, "lng": 46.6760, "timestamp": "2026-02-15T10:01:00"},
            {"lat": 24.7145, "lng": 46.6765, "timestamp": "2026-02-15T10:02:00"},
            {"lat": 24.7150, "lng": 46.6770, "timestamp": "2026-02-15T10:03:00"},
            {"lat": 24.7200, "lng": 46.6800, "timestamp": "2026-02-15T10:04:00"},  # انحراف!
            {"lat": 24.7155, "lng": 46.6775, "timestamp": "2026-02-15T10:05:00"},
        ],
        "planned_route": [
            {"lat": 24.7136, "lng": 46.6753},
            {"lat": 24.7140, "lng": 46.6760},
            {"lat": 24.7145, "lng": 46.6765},
            {"lat": 24.7150, "lng": 46.6770},
            {"lat": 24.7155, "lng": 46.6775},
        ]
    }
    
    response = requests.post(f"{BASE_URL}/analyze-route", json=data)
    print(f"Status: {response.status_code}")
    if response.status_code == 200:
        result = response.json()
        print(f"Response:")
        print(f"  النقاط الشاذة: {result['analysis']['anomaly_count']}/{result['analysis']['total_points']}")
        print(f"  متوسط الانحراف: {result['analysis']['avg_deviation_meters']:.1f} متر")
        print(f"  درجة الخطر: {result['analysis']['risk_score']:.1f}/100")
        print(f"  مستوى الخطر: {result['analysis']['risk_level']}")
        print(f"  الإجراء الموصى به: {result['analysis']['recommended_action']}")
    else:
        print(f"Error: {response.text}")
    
    return response.status_code == 200


def test_pattern_analysis():
    """اختبار تحليل الأنماط"""
    print("\n=== اختبار تحليل الأنماط ===")
    
    # إنشاء سجل رحلات تجريبي (عادة في الصباح)
    trips_history = []
    base_date = datetime.now() - timedelta(days=30)
    
    for i in range(20):
        trip_date = base_date + timedelta(days=i)
        # معظم الرحلات في الصباح (8 صباحاً)
        trip_date = trip_date.replace(hour=8, minute=0)
        
        trips_history.append({
            "trip_id": f"trip_{i}",
            "start_time": trip_date.isoformat(),
            "duration_minutes": 45,
            "route_id": "route_work"
        })
    
    # الرحلة الحالية في وقت غير معتاد (11 مساءً!)
    current_time = datetime.now().replace(hour=23, minute=0)
    
    data = {
        "user_id": "test_user_001",
        "trips_history": trips_history,
        "current_trip": {
            "start_time": current_time.isoformat(),
            "route_id": "route_work"
        }
    }
    
    response = requests.post(f"{BASE_URL}/analyze-patterns", json=data)
    print(f"Status: {response.status_code}")
    if response.status_code == 200:
        result = response.json()
        print(f"Response:")
        print(f"  الساعة المعتادة: {result['patterns']['most_common_hour']}:00")
        print(f"  عدد الرحلات: {result['patterns']['total_trips']}")
        print(f"  سلوك غير معتاد؟ {'نعم' if result['current_analysis']['is_unusual'] else 'لا'}")
        print(f"  درجة الشذوذ: {result['current_analysis']['anomaly_score']}/100")
        
        if result['current_analysis']['anomalies']:
            print(f"  الشذوذات المكتشفة:")
            for anomaly in result['current_analysis']['anomalies']:
                print(f"    - {anomaly['message']} ({anomaly['severity']})")
        
        print(f"  التوصية: {result['current_analysis']['recommendation']}")
    else:
        print(f"Error: {response.text}")
    
    return response.status_code == 200


def test_comprehensive_analysis():
    """اختبار التحليل الشامل"""
    print("\n=== اختبار التحليل الشامل ===")
    
    # بيانات شاملة
    current_time = datetime.now().replace(hour=23, minute=0)
    base_date = datetime.now() - timedelta(days=30)
    
    trips_history = []
    for i in range(15):
        trip_date = base_date + timedelta(days=i)
        trip_date = trip_date.replace(hour=8, minute=0)
        trips_history.append({
            "trip_id": f"trip_{i}",
            "start_time": trip_date.isoformat(),
            "duration_minutes": 45,
            "route_id": "route_work"
        })
    
    data = {
        "trip": {
            "trip_id": "current_trip",
            "user_id": "test_user_001",
            "start_time": current_time.isoformat(),
            "locations": [
                {"lat": 24.7136, "lng": 46.6753, "timestamp": current_time.isoformat()},
                {"lat": 24.7140, "lng": 46.6760},
                {"lat": 24.7145, "lng": 46.6765},
                {"lat": 24.7250, "lng": 46.6850},  # انحراف كبير!
                {"lat": 24.7155, "lng": 46.6775},
            ],
            "planned_route": [
                {"lat": 24.7136, "lng": 46.6753},
                {"lat": 24.7140, "lng": 46.6760},
                {"lat": 24.7145, "lng": 46.6765},
                {"lat": 24.7150, "lng": 46.6770},
                {"lat": 24.7155, "lng": 46.6775},
            ]
        },
        "user_history": {
            "trips": trips_history
        }
    }
    
    response = requests.post(f"{BASE_URL}/comprehensive-analysis", json=data)
    print(f"Status: {response.status_code}")
    if response.status_code == 200:
        result = response.json()
        print(f"Response:")
        print(f"  الخطر الإجمالي: {result['overall_risk_score']:.1f}/100")
        print(f"  مستوى التنبيه: {result['alert_level']}")
        print(f"  الرسالة: {result['alert_message']}")
        print(f"  الإجراء الموصى به: {result['recommended_action']}")
    else:
        print(f"Error: {response.text}")
    
    return response.status_code == 200


if __name__ == "__main__":
    print("=" * 60)
    print("اختبار خدمة PSGA ML Analysis")
    print("=" * 60)
    
    # تشغيل الاختبارات
    results = {
        "Health Check": test_health(),
        "Route Analysis": test_route_analysis(),
        "Pattern Analysis": test_pattern_analysis(),
        "Comprehensive Analysis": test_comprehensive_analysis()
    }
    
    # النتائج
    print("\n" + "=" * 60)
    print("ملخص النتائج:")
    print("=" * 60)
    for test_name, passed in results.items():
        status = "✅ نجح" if passed else "❌ فشل"
        print(f"{test_name}: {status}")
    
    all_passed = all(results.values())
    print("\n" + ("🎉 جميع الاختبارات نجحت!" if all_passed else "⚠️ بعض الاختبارات فشلت"))
