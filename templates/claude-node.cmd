@echo off
setlocal
set SCRIPT_DIR=%~dp0
set PATH=%SCRIPT_DIR%node;%PATH%
set CLAUDE_CONFIG_DIR=%USERPROFILE%\.config\claude
set CLAUDE_CONFIG_FILE=%CLAUDE_CONFIG_DIR%\.claude.json
set DISABLE_INSTALLATION_CHECKS=1
"%SCRIPT_DIR%node\node.exe" "%SCRIPT_DIR%node_modules\@anthropic-ai\claude-code\cli.js" %*
set EXIT_CODE=%ERRORLEVEL%
endlocal & exit /b %EXIT_CODE%
