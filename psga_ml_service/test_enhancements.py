"""
اختبار التحسينات V1.1
======================
اختبار شامل لجميع الميزات الجديدة
"""

import requests
import json
from datetime import datetime, timedelta

# عنوان الخادم
BASE_URL = "http://localhost:8000"

def print_section(title):
    """طباعة عنوان قسم"""
    print("\n" + "="*70)
    print(f"  {title}")
    print("="*70)

def print_result(label, value, color=""):
    """طباعة نتيجة"""
    colors = {
        "green": "\033[92m",
        "red": "\033[91m",
        "yellow": "\033[93m",
        "blue": "\033[94m",
        "reset": "\033[0m"
    }
    c = colors.get(color, "")
    r = colors["reset"]
    print(f"  {c}✓{r} {label}: {c}{value}{r}")

def test_health_check():
    """اختبار صحة الخدمة"""
    print_section("1️⃣ اختبار Health Check")
    
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print_result("Status", data['status'], "green")
            print_result("Service", data['service'], "blue")
            print_result("Timestamp", data['timestamp'], "blue")
            return True
        else:
            print_result("Error", f"Status code: {response.status_code}", "red")
            return False
    except Exception as e:
        print_result("Error", str(e), "red")
        return False

def test_route_analysis_with_enhancements():
    """اختبار تحليل المسار مع التحسينات"""
    print_section("2️⃣ اختبار تحليل المسار + التحسينات")
    
    # بيانات تجريبية واقعية
    # محاكاة رحلة من الرياض مع:
    # - قفزة GPS (نقطة 3)
    # - نقاط مكررة (نقطة 6-7)
    # - سرعة عالية (نقطة 8)
    # - انحراف عن المسار
    
    now = datetime.now()
    
    test_data = {
        "route_id": "test_route_v11_001",
        "locations": [
            # نقاط عادية
            {"lat": 24.7136, "lng": 46.6753, "timestamp": now.isoformat(), "speed": 50},
            {"lat": 24.7140, "lng": 46.6760, "timestamp": (now + timedelta(seconds=10)).isoformat(), "speed": 55},
            
            # قفزة GPS غير واقعية (500 كم!)
            {"lat": 21.4225, "lng": 39.8262, "timestamp": (now + timedelta(seconds=20)).isoformat(), "speed": 60},
            
            # عودة للمسار الطبيعي
            {"lat": 24.7145, "lng": 46.6770, "timestamp": (now + timedelta(seconds=30)).isoformat(), "speed": 45},
            {"lat": 24.7150, "lng": 46.6780, "timestamp": (now + timedelta(seconds=40)).isoformat(), "speed": 48},
            
            # نقاط مكررة
            {"lat": 24.7152, "lng": 46.6782, "timestamp": (now + timedelta(seconds=50)).isoformat(), "speed": 0},
            {"lat": 24.7152, "lng": 46.6782, "timestamp": (now + timedelta(seconds=60)).isoformat(), "speed": 0},
            {"lat": 24.7152, "lng": 46.6782, "timestamp": (now + timedelta(seconds=70)).isoformat(), "speed": 0},
            
            # سرعة عالية جداً
            {"lat": 24.7160, "lng": 46.6800, "timestamp": (now + timedelta(seconds=80)).isoformat(), "speed": 140},
            
            # انحراف كبير عن المسار المخطط
            {"lat": 24.7200, "lng": 46.6900, "timestamp": (now + timedelta(seconds=90)).isoformat(), "speed": 60},
            {"lat": 24.7210, "lng": 46.6910, "timestamp": (now + timedelta(seconds=100)).isoformat(), "speed": 55},
            {"lat": 24.7220, "lng": 46.6920, "timestamp": (now + timedelta(seconds=110)).isoformat(), "speed": 50},
            
            # عودة للمسار
            {"lat": 24.7180, "lng": 46.6820, "timestamp": (now + timedelta(seconds=120)).isoformat(), "speed": 52},
        ],
        "planned_route": [
            {"lat": 24.7136, "lng": 46.6753},
            {"lat": 24.7140, "lng": 46.6760},
            {"lat": 24.7145, "lng": 46.6770},
            {"lat": 24.7150, "lng": 46.6780},
            {"lat": 24.7160, "lng": 46.6800},
            {"lat": 24.7170, "lng": 46.6810},
            {"lat": 24.7180, "lng": 46.6820}
        ]
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/analyze-route",
            json=test_data,
            timeout=30
        )
        
        if response.status_code == 200:
            data = response.json()
            
            print_result("Route ID", data['route_id'], "blue")
            print_result("Version", data.get('version', 'N/A'), "blue")
            
            # النتائج الأساسية
            analysis = data['analysis']
            print("\n  📊 النتائج الأساسية:")
            print_result("  النقاط الأصلية", analysis['original_points'], "blue")
            print_result("  النقاط المحللة", analysis['analyzed_points'], "green")
            print_result("  النقاط المحذوفة", analysis['removed_points'], "yellow")
            print_result("  النقاط الشاذة", f"{analysis['anomaly_count']}/{analysis['analyzed_points']} ({analysis['anomaly_percentage']}%)", "yellow")
            print_result("  متوسط الانحراف", f"{analysis['avg_deviation_meters']:.1f}م", "blue")
            print_result("  أقصى انحراف", f"{analysis['max_deviation_meters']:.1f}م", "red")
            
            # درجة الخطر
            print("\n  🎯 درجة الخطر:")
            print_result("  الخطر الأساسي", f"{analysis['basic_risk_score']:.1f}/100", "yellow")
            print_result("  الخطر المتقدم", f"{analysis['advanced_risk_score']:.1f}/100", "yellow")
            print_result("  الخطر الإجمالي", f"{analysis['risk_score']:.1f}/100", "red" if analysis['risk_score'] > 50 else "green")
            print_result("  مستوى الخطر", analysis['risk_level'], "red" if analysis['risk_level'] in ['high', 'critical'] else "yellow")
            print_result("  الإجراء الموصى به", analysis['recommended_action'], "blue")
            
            # التحليلات المتقدمة
            advanced = data.get('advanced_analysis', {})
            
            # تنظيف البيانات
            if 'data_cleaning' in advanced:
                cleaning = advanced['data_cleaning']
                print("\n  🧹 تنظيف البيانات:")
                print_result("  قفزات GPS محذوفة", cleaning['removed_jumps'], "yellow")
                print_result("  نقاط مكررة محذوفة", cleaning['removed_duplicates'], "yellow")
                print_result("  نسبة الحذف", f"{cleaning['removal_percentage']}%", "blue")
            
            # تحليل السرعة
            if advanced.get('speed_analysis') and advanced['speed_analysis']['has_data']:
                speed = advanced['speed_analysis']
                print("\n  🚗 تحليل السرعة:")
                print_result("  متوسط السرعة", f"{speed['stats']['avg_speed_kmh']} كم/س", "blue")
                print_result("  أقصى سرعة", f"{speed['stats']['max_speed_kmh']} كم/س", "red" if speed['stats']['max_speed_kmh'] > 120 else "green")
                print_result("  شذوذات السرعة", speed['anomaly_count'], "yellow" if speed['has_anomaly'] else "green")
                if speed['has_anomaly']:
                    for anomaly in speed['anomalies']:
                        print(f"    ⚠️ {anomaly['message']}")
            
            # كشف التوقفات
            if advanced.get('stops_analysis') and advanced['stops_analysis']['has_stops']:
                stops = advanced['stops_analysis']
                print("\n  🛑 كشف التوقفات:")
                print_result("  إجمالي التوقفات", stops['total_stops'], "blue")
                print_result("  توقفات غير عادية", stops['unusual_stops'], "yellow" if stops['unusual_stops'] > 0 else "green")
                print_result("  أطول توقف", f"{stops['longest_stop_minutes']} دقيقة", "red" if stops['longest_stop_minutes'] > 30 else "blue")
                if stops['unusual_stops'] > 0:
                    print("  📍 التوقفات غير العادية:")
                    for stop in stops['stops']:
                        if stop['is_unusual']:
                            print(f"    - {stop['message']} في ({stop['location']['lat']:.4f}, {stop['location']['lng']:.4f})")
            
            # مقاطع الانحراف
            if advanced.get('deviation_segments') and advanced['deviation_segments']['has_segments']:
                segments = advanced['deviation_segments']
                print("\n  📍 مقاطع الانحراف:")
                print_result("  عدد المقاطع", segments['total_segments'], "yellow")
                print_result("  أطول مقطع", f"{segments['longest_segment_length']} نقاط", "red")
                print("  🔍 تفاصيل المقاطع:")
                for i, seg in enumerate(segments['segments'], 1):
                    print(f"    المقطع {i}: {seg['length']} نقاط، متوسط {seg['avg_deviation_m']:.1f}م، أقصى {seg['max_deviation_m']:.1f}م ({seg['severity']})")
            
            return True
        else:
            print_result("Error", f"Status code: {response.status_code}", "red")
            print(f"  Response: {response.text}")
            return False
            
    except Exception as e:
        print_result("Error", str(e), "red")
        import traceback
        traceback.print_exc()
        return False

def test_root_endpoint():
    """اختبار الصفحة الرئيسية"""
    print_section("3️⃣ اختبار الصفحة الرئيسية")
    
    try:
        response = requests.get(BASE_URL, timeout=5)
        if response.status_code == 200:
            data = response.json()
            print_result("Service", data['service'], "green")
            print_result("Version", data['version'], "blue")
            print_result("Status", data['status'], "green")
            
            if 'features' in data:
                print("\n  ✨ الميزات المتاحة:")
                for feature in data['features']:
                    print(f"    • {feature}")
            
            return True
        else:
            print_result("Error", f"Status code: {response.status_code}", "red")
            return False
    except Exception as e:
        print_result("Error", str(e), "red")
        return False

def main():
    """تشغيل جميع الاختبارات"""
    print("\n" + "🚀 " * 20)
    print("  اختبار شامل لتحسينات PSGA ML Service V1.1")
    print("🚀 " * 20)
    
    results = {
        "health_check": test_health_check(),
        "root_endpoint": test_root_endpoint(),
        "route_analysis_enhanced": test_route_analysis_with_enhancements(),
    }
    
    # الخلاصة
    print_section("📊 خلاصة الاختبارات")
    
    total = len(results)
    passed = sum(results.values())
    
    for test_name, result in results.items():
        status = "✅ نجح" if result else "❌ فشل"
        color = "green" if result else "red"
        print_result(test_name.replace("_", " ").title(), status, color)
    
    print("\n" + "="*70)
    success_rate = (passed / total) * 100
    color = "green" if success_rate == 100 else "yellow" if success_rate >= 50 else "red"
    print_result("معدل النجاح", f"{passed}/{total} ({success_rate:.0f}%)", color)
    print("="*70 + "\n")
    
    return passed == total

if __name__ == "__main__":
    import sys
    success = main()
    sys.exit(0 if success else 1)
