@echo off
setlocal enabledelayedexpansion

set mode=%~1
if "%mode%"=="" set mode=all

if not "%mode%"=="all" if not "%mode%"=="test" (
    echo Usage: %~nx0 [all^|test]
    echo.
    echo   all   Run tests, build main app, and build examples ^(default^)
    echo   test  Run tests only
    exit /b 1
)

REM Clean and recreate the build output directory
if exist build rmdir /s /q build
mkdir build

echo.
echo --- Running tests ---
call test.bat
IF %ERRORLEVEL% NEQ 0 exit /b 1

if "%mode%"=="test" (
    echo.
    echo Tests completed successfully.
    exit /b 0
)

echo.
echo --- Building main application ---
odin build . -vet -strict-style -vet-tabs -warnings-as-errors -debug -out:build\sgui.exe
IF %ERRORLEVEL% NEQ 0 (
    echo Build failed!
    exit /b 1
)

echo.
echo --- Building all examples ---
FOR /D %%d IN (examples\*) DO (
    echo Building example: %%~nd
    odin build "%%d" -vet -strict-style -vet-tabs -warnings-as-errors -debug -out:build\%%~nd.exe
    IF !ERRORLEVEL! NEQ 0 (
        echo Build for example '%%~nd' failed!
        exit /b 1
    )
)

echo.
echo Build and tests completed successfully.
endlocal
