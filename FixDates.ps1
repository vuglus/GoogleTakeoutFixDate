Get-Content ".\config.env" | ForEach-Object {
    if ($_ -match "^(.*?)=(.*)$") {
        Set-Variable -Name $matches[1] -Value $matches[2]
    }
}

Write-Host "BasePath из .env: $BasePath"

# Форматы фото и видео, с которыми работаем
$Extensions = @(".jpg", ".jpeg", ".png", ".heic", ".mp4", ".mov", ".avi", ".mkv")

# Счётчики
$UpdatedCount = 0
$TotalJson = 0
$deletedCount = 0
$notFoundCount = 0

Write-Host "=== Начало обработки ==="

# Поиск всех JSON в папке и подпапках
Get-ChildItem -Path $BasePath -Recurse -Filter *.json | ForEach-Object {
    $TotalJson++
    try {
        $jsonFile = $_.FullName
        $mediaFound = $false
        # Читаем JSON
        $jsonText = Get-Content $_.FullName -Raw -Encoding UTF8
        $data = $jsonText | ConvertFrom-Json

        # Берём timestamp
        $timestamp = $null
        if ($data.photoTakenTime.timestamp) {
            $timestamp = [long]$data.photoTakenTime.timestamp
        } elseif ($data.creationTime.timestamp) {
            $timestamp = [long]$data.creationTime.timestamp
        }

        if (-not $timestamp -or $timestamp -eq 0) {
            return
        }

        # Конвертация Unix timestamp в дату
        $dateTaken = (Get-Date "1970-01-01 00:00:00Z").AddSeconds($timestamp).ToLocalTime()

        # Имя файла из JSON
        $fileName = $data.title

        # Путь к медиафайлу
        $mediaFile = Join-Path $_.DirectoryName $fileName

        # Если файла с таким именем нет — пробуем разные варианты:
        # 1. Оригинальное имя
        # 2. Имя с разными расширениями
        # 3. Имя с суффиксом (n)
        # 4. Имя с суффиксом (n) и разными расширениями
        if (-not (Test-Path $mediaFile)) {
            # Попробуем разные расширения для оригинального имени
            foreach ($ext in $Extensions) {
                $altPath = [System.IO.Path]::ChangeExtension($mediaFile, $ext)
                if (Test-Path $altPath) {
                    $mediaFile = $altPath
                    $mediaFound = $true
                    break
                }
            }
            
            if (-not $mediaFound) {
                # Попробуем найти файлы с суффиксом (n)
                $baseName = [System.IO.Path]::GetFileNameWithoutExtension($mediaFile)
                $extension = [System.IO.Path]::GetExtension($mediaFile)
                
                # Сначала попробуем оригинальное расширение с суффиксами (1)-(9)
                for ($i = 1; $i -le 9; $i++) {
                    $numberedPath = Join-Path $_.DirectoryName "$baseName($i)$extension"
                    if (Test-Path $numberedPath) {
                        $mediaFile = $numberedPath
                        $mediaFound = $true
                        break
                    }
                }
                
                if (-not $mediaFound) {
                    # Если не нашли, попробуем другие расширения с суффиксами
                    foreach ($ext in $Extensions) {
                        for ($i = 1; $i -le 9; $i++) {
                            $numberedPath = Join-Path $_.DirectoryName "$baseName($i)$ext"
                            if (Test-Path $numberedPath) {
                                $mediaFile = $numberedPath
                                $mediaFound = $true
                                break
                            }
                        }
                        if ($mediaFound) { break }
                    }
                }
            }
        } else {
            $mediaFound = $true
        }

        # Если файл найден — меняем даты
        if ($mediaFound) {
            (Get-Item $mediaFile).CreationTime = $dateTaken
            (Get-Item $mediaFile).LastWriteTime = $dateTaken
            $UpdatedCount++
            Write-Host "✔ $([System.IO.Path]::GetFileName($mediaFile)) — дата изменена на $dateTaken"
            
            # Удаляем json файл, включая возможные суффиксы (n)
            $jsonBaseName = [System.IO.Path]::GetFileNameWithoutExtension($jsonFile)
            $jsonExt = [System.IO.Path]::GetExtension($jsonFile)
            $jsonPattern = "$jsonBaseName*$jsonExt"
            Get-ChildItem -Path $_.DirectoryName -Filter $jsonPattern | Remove-Item -Force
            $deletedCount++
        } else {
            $notFoundCount++
            Write-Host "⚠ Не найден медиафайл для: $fileName (JSON: $([System.IO.Path]::GetFileName($jsonFile)))" -ForegroundColor Yellow
        }

    } catch {
        Write-Host "Ошибка обработки $($_.FullName): $_" -ForegroundColor Red
    }
}

Write-Host "=== Результаты обработки ==="
Write-Host "Удалено JSON файлов: $deletedCount"
Write-Host "Обновлено медиафайлов: $UpdatedCount"
Write-Host "Не найдено медиафайлов: $notFoundCount"
Write-Host "Всего обработано JSON файлов: $TotalJson"