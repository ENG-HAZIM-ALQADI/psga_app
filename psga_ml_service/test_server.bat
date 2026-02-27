@echo off
REM ========================================
REM PSGA ML Service - Test Script
REM ========================================

echo.
echo ╔══════════════════════════════════════════╗
echo ║  PSGA ML Analysis Service - Tests      ║
echo ╚══════════════════════════════════════════╝
echo.

REM تحديد المجلد الحالي
set SCRIPT_DIR=%~dp0
cd /d %SCRIPT_DIR%

echo [1/2] تفعيل البيئة الافتراضية...
echo.

REM تفعيل البيئة
call conda activate psga_ml_env
if %ERRORLEVEL% NEQ 0 (
    echo ❌ خطأ: فشل تفعيل البيئة
    pause
    exit /b 1
)

echo ✅ تم تفعيل البيئة
echo.

echo [2/2] تشغيل الاختبارات...
echo.
echo ═══════════════════════════════════════════
echo   تأكد أن الخادم يعمل على localhost:8000
echo ═══════════════════════════════════════════
echo.

REM تشغيل الاختبارات
python test_api.py

echo.
echo تمت الاختبارات!
pause
