@echo off
echo Running tests
odin test ui
IF %ERRORLEVEL% NEQ 0 (
    echo Tests failed! Cannot successfully build.
    exit /b 1
)

echo Building SDL2 example
odin build . -strict-style -vet -debug 
IF %ERRORLEVEL% NEQ 0 (
    echo Build failed!
    exit /b 1
)

echo Build and tests completed successfully.
