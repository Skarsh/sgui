@echo off
setlocal enabledelayedexpansion

REM Ensure the build output directory exists
if not exist build mkdir build

echo --- Running tests ---
odin test ui
IF %ERRORLEVEL% NEQ 0 (
    echo Ui tests failed! Cannot successfully build.
    exit /b 1
)

odin test base
IF %ERRORLEVEL% NEQ 0 (
    echo Base tests failed! Cannot successfully build.
    exit /b 1
)

echo.
echo --- Building main application ---
odin build . -strict-style -vet -debug -out:build\sgui.exe
IF %ERRORLEVEL% NEQ 0 (
    echo Build failed!
    exit /b 1
)

echo.
echo --- Building all examples ---
REM Loop through all subdirectories of the 'examples' directory
FOR /D %%d IN (examples\*) DO (
    echo Building example: %%~nd
    odin build "%%d" -strict-style -vet -debug -out:build\%%~nd.exe
    IF !ERRORLEVEL! NEQ 0 (
        echo Build for example '%%~nd' failed!
        exit /b 1
    )
)

echo.
echo Build and tests completed successfully.
endlocal
