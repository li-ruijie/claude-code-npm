@echo off
setlocal
set SCRIPT_DIR=%~dp0
set CLAUDE_CONFIG_DIR=%USERPROFILE%\.config\claude
set CLAUDE_CONFIG_FILE=%CLAUDE_CONFIG_DIR%\.claude.json
set CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
set CLAUDE_CODE_ENABLE_TELEMETRY=0
"%SCRIPT_DIR%deno\deno.exe" run --allow-all --unstable-bare-node-builtins --node-modules-dir=auto "%SCRIPT_DIR%deno-shim.js" %*
set EXIT_CODE=%ERRORLEVEL%
endlocal & exit /b %EXIT_CODE%
