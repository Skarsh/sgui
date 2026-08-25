@echo off
setlocal enabledelayedexpansion
set mode=%~1
if "%mode%"=="" set mode=all
if not "%mode%"=="all" if not "%mode%"=="test" if not "%mode%"=="build" (
    echo Usage: %~nx0 [all^|test^|build]
    echo.
    echo   all    Run tests, build main app, and build examples ^(default^)
    echo   test   Run tests only
    echo   build  Build main app and examples only ^(no tests^)
    exit /b 1
)
REM Clean and recreate the build output directory
if exist build rmdir /s /q build
mkdir build

if not "%mode%"=="build" (
    echo.
    echo --- Running tests ---
    call test.bat
    IF %ERRORLEVEL% NEQ 0 exit /b 1
    if "%mode%"=="test" (
        echo.
        echo Tests completed successfully.
        exit /b 0
    )
)

echo.
echo --- Building all examples ---

odin run parbuild -- .\examples .\build
     IF !ERRORLEVEL! NEQ 0 (
         echo Building examples with parbuild failed!
         exit /b 1
     )

echo.
echo Examples built successfully.
endlocal
