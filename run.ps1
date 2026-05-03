Write-Host "Starting NEOS development environment..." -ForegroundColor Cyan
Write-Host "  Backend:  http://localhost:8000" -ForegroundColor Green
Write-Host "  Frontend: http://localhost:5173" -ForegroundColor Green
Write-Host ""

# Start backend in a new terminal
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$PSScriptRoot\neos-operating-system'; & .\start-dev.ps1"

# Start frontend in a new terminal
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$PSScriptRoot\charting-the-course'; & .\start-dev.ps1"

Write-Host "Launched backend and frontend in separate terminals." -ForegroundColor Yellow
