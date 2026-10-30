@echo off
rem
rem checker.bat - Windows counterpart of checker.sh. Checks machine readiness for the
rem sticky-rice-fighter stack:
rem   1. Java 25
rem   2. Node.js 24, and the npm that ships with it
rem   3. Docker
rem   4. Python 3.13
rem
rem Mobile tooling is checked too, but only WARNS when missing: a workspace without a
rem mobile repository does not need it, so a missing emulator is not a reason to block.
rem
setlocal EnableExtensions EnableDelayedExpansion

set "FAILED=0"

rem 1. Java 25
where java >nul 2>&1
if errorlevel 1 (
    call :fail "Java not found in PATH"
) else (
    set "JAVA_VERSION_RAW="
    rem `java --version` prints the version unquoted, e.g. "openjdk 25.0.4 2026-08-18".
    for /f "delims=" %%L in ('java --version 2^>^&1') do if not defined JAVA_VERSION_RAW set "JAVA_VERSION_RAW=%%L"
    set "JAVA_MAJOR="
    for /f "tokens=2" %%V in ("!JAVA_VERSION_RAW!") do for /f "tokens=1 delims=." %%M in ("%%V") do set "JAVA_MAJOR=%%M"
    if "!JAVA_MAJOR!"=="25" (
        call :pass "Java version 25 detected (!JAVA_VERSION_RAW!)"
    ) else (
        call :fail "Java 25 required, found: !JAVA_VERSION_RAW!"
    )
)

rem 2. Node.js 24
where node >nul 2>&1
if errorlevel 1 (
    call :fail "Node.js not found in PATH"
) else (
    for /f "delims=" %%L in ('node -v') do set "NODE_VERSION_RAW=%%L"
    for /f "tokens=1 delims=." %%M in ("!NODE_VERSION_RAW:v=!") do set "NODE_MAJOR=%%M"
    if "!NODE_MAJOR!"=="24" (
        call :pass "Node.js version 24 detected (!NODE_VERSION_RAW!)"
    ) else (
        call :fail "Node.js 24 required, found: !NODE_VERSION_RAW!"
    )
)

rem 2b. npm, which builds the frontend and the MCP server. It ships with Node.js, so a
rem     missing npm means a broken Node installation rather than a separate install.
where npm >nul 2>&1
if errorlevel 1 (
    call :fail "npm not found in PATH: the frontend and MCP server are built with npm and tsc"
) else (
    for /f "delims=" %%L in ('npm -v') do set "NPM_VERSION=%%L"
    call :pass "npm detected (!NPM_VERSION!)"
)

rem 3. Docker
where docker >nul 2>&1
if errorlevel 1 (
    call :fail "Docker not found in PATH"
) else (
    for /f "delims=" %%L in ('docker --version 2^>^&1') do set "DOCKER_VERSION=%%L"
    docker info >nul 2>&1
    if errorlevel 1 (
        call :warn "Docker detected but daemon is not running (!DOCKER_VERSION!)"
        set "FAILED=1"
    ) else (
        call :pass "Docker detected and running (!DOCKER_VERSION!)"
    )
)

rem 4. Python 3.13 (fixed version, used for Playwright and tooling).
rem    On Windows the command is `python`: `python3` is the Microsoft Store alias, not
rem    an interpreter.
set "REQUIRED_PYTHON=3.13"
where python >nul 2>&1
if errorlevel 1 (
    call :fail "Python 3 not found in PATH"
) else (
    set "PYTHON_VERSION_RAW="
    for /f "delims=" %%L in ('python --version 2^>^&1') do if not defined PYTHON_VERSION_RAW set "PYTHON_VERSION_RAW=%%L"
    set "PYTHON_MINOR_VERSION="
    for /f "tokens=2" %%V in ("!PYTHON_VERSION_RAW!") do for /f "tokens=1,2 delims=." %%A in ("%%V") do set "PYTHON_MINOR_VERSION=%%A.%%B"
    if "!PYTHON_MINOR_VERSION!"=="%REQUIRED_PYTHON%" (
        call :pass "Python %REQUIRED_PYTHON% detected (!PYTHON_VERSION_RAW!)"
    ) else (
        call :fail "Python %REQUIRED_PYTHON% required, found: !PYTHON_VERSION_RAW!"
    )
)

rem 5. Mobile tooling. Needed only when the workspace has a mobile repository, so these
rem    warn rather than fail. Presence only; no tool is invoked to read a version.
where adb >nul 2>&1
if errorlevel 1 (
    call :warn "adb not found: needed to drive the Android Emulator for a mobile repository"
) else (
    call :pass "adb detected - the agent can drive the Android Emulator"
)

call :warn "iOS Simulator runs on macOS only: this machine can build and test Android only"

where maestro >nul 2>&1
if errorlevel 1 (
    call :warn "Maestro not found: needed to run mobile journeys"
) else (
    call :pass "Maestro detected"
)

echo -----------------------------------
if "%FAILED%"=="0" (
    echo All checks passed. Machine is ready.
    exit /b 0
) else (
    echo Some checks failed. Machine is NOT ready.
    exit /b 1
)

:pass
echo [OK]   %~1
goto :eof

:fail
echo [FAIL] %~1
set "FAILED=1"
goto :eof

:warn
echo [WARN] %~1
goto :eof
