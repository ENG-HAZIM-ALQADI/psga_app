@echo off
REM ========================================
REM PSGA ML Service - Startup Script
REM ========================================

echo.
echo ╔══════════════════════════════════════════╗
echo ║  PSGA ML Analysis Service - Startup    ║
echo ╚══════════════════════════════════════════╝
echo.

REM تحديد المجلد الحالي
set SCRIPT_DIR=%~dp0
cd /d %SCRIPT_DIR%

echo [1/3] التحقق من البيئة الافتراضية...
echo.

REM التحقق من وجود Conda
where conda >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ❌ خطأ: Anaconda غير مثبت!
    echo.
    echo يرجى تثبيت Anaconda من: https://www.anaconda.com/download
    pause
    exit /b 1
)

echo ✅ تم العثور على Conda
echo.

echo [2/3] تفعيل البيئة الافتراضية psga_ml_env...
echo.

REM تفعيل البيئة
call conda activate psga_ml_env
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ خطأ: فشل تفعيل البيئة psga_ml_env
    echo.
    echo هل قمت بإنشاء البيئة؟
    echo قم بتشغيل: conda env create -f environment.yml
    echo.
    pause
    exit /b 1
)

echo ✅ تم تفعيل البيئة
echo.

echo [3/3] تشغيل خادم ML...
echo.
echo ═══════════════════════════════════════════
echo   الخادم يعمل على: http://localhost:8000
echo   API Docs: http://localhost:8000/docs
echo   لإيقاف الخادم: اضغط Ctrl+C
echo ═══════════════════════════════════════════
echo.

REM تشغيل الخادم
python main.py

REM في حالة إغلاق الخادم
echo.
echo تم إيقاف الخادم.
pause
