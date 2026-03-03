@echo off
setlocal enabledelayedexpansion

odin test ui -vet -strict-style -vet-tabs -warnings-as-errors -all-packages
IF %ERRORLEVEL% NEQ 0 (
    echo Ui tests failed! Cannot successfully build.
    exit /b 1
)

odin test ui\text -vet -strict-style -vet-tabs -warnings-as-errors
IF %ERRORLEVEL% NEQ 0 (
    echo Ui/text tests failed! Cannot successfully build.
    exit /b 1
)

odin test base -vet -strict-style -vet-tabs -warnings-as-errors
IF %ERRORLEVEL% NEQ 0 (
    echo Base tests failed! Cannot successfully build.
    exit /b 1
)

odin test gap_buffer -vet -strict-style -vet-tabs -warnings-as-errors
IF %ERRORLEVEL% NEQ 0 (
    echo Gap buffer tests failed! Cannot successfully build.
    exit /b 1
)

endlocal
