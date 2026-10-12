@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

set "PORT=7788"
set "PY="

rem 按顺序找可用的 python（前三个是本机 Forge 自带的）
for %%P in (
  "D:\AI\python-full\python.exe"
  "D:\AI\python\python.exe"
  "D:\AI\stable-diffusion-webui-forge\venv\Scripts\python.exe"
) do (
  if not defined PY if exist %%P set "PY=%%~P"
)
for %%C in (python.exe python3.exe) do (
  if not defined PY for /f "delims=" %%W in ('where %%C 2^>nul') do if not defined PY set "PY=%%W"
)

if not defined PY (
  echo [错误] 找不到可用的 python.exe
  echo        请编辑本文件，把上面的候选路径改成你的 python 位置。
  pause
  exit /b 1
)

echo 使用 python: %PY%
echo.
"%PY%" "%~dp0serve.py" --port %PORT%
pause
