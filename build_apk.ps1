# Flutter APK 精简构建脚本（Windows PowerShell）
# 用法：在项目根目录运行 .\build_apk.ps1

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  序 (Xu) - 精简 APK 构建脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. 清理旧构建
Write-Host "[1/3] 清理旧构建缓存..." -ForegroundColor Yellow
flutter clean
Write-Host "  OK 清理完成" -ForegroundColor Green

# 2. 获取依赖
Write-Host "[2/3] 获取依赖..." -ForegroundColor Yellow
flutter pub get
Write-Host "  OK 依赖就绪" -ForegroundColor Green

# 3. 构建 APK
# --split-per-abi: 按 CPU 架构拆分 APK（每个缩小约 60%）
# --obfuscate: 混淆 Dart 代码
# --split-debug-info: 调试符号外置
Write-Host "[3/3] 构建精简 APK..." -ForegroundColor Yellow
flutter build apk --release --obfuscate --split-debug-info=build/debug-info

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  构建完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

$apkDir = "build\app\outputs\flutter-apk"
if (Test-Path $apkDir) {
    Write-Host "APK 文件列表：" -ForegroundColor White
    Get-ChildItem $apkDir -Filter "*.apk" | ForEach-Object {
        $sizeMB = [math]::Round($_.Length / 1MB, 2)
        Write-Host "  $($_.Name)  ($sizeMB MB)" -ForegroundColor Cyan
    }
    Write-Host ""
    Write-Host "推荐安装: app-arm64-v8a-release.apk (适用于绝大多数现代手机)" -ForegroundColor White
}
