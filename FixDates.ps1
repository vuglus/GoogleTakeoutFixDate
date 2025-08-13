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

Write-Host "=== Начало обработки ==="

# Поиск всех JSON в папке и подпапках
Get-ChildItem -Path $BasePath -Recurse -Filter *.json | ForEach-Object {
    $TotalJson++
    try {
        $jsonFile = $_.FullName

        # Пропускаем supplemental-metadata
        if ($jsonFile -match "\.supplemental-metadata") {
            return
        }
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

        # Если файла с таким именем нет — пробуем разные расширения
        if (-not (Test-Path $mediaFile)) {
            foreach ($ext in $Extensions) {
                $altPath = [System.IO.Path]::ChangeExtension($mediaFile, $ext)
                if (Test-Path $altPath) {
                    $mediaFile = $altPath
                    break
                }
            }
        }

        # Если файл найден — меняем даты
        if (Test-Path $mediaFile) {
            (Get-Item $mediaFile).CreationTime = $dateTaken
            (Get-Item $mediaFile).LastWriteTime = $dateTaken
            $UpdatedCount++
            Write-Host "✔ $fileName — дата изменена на $dateTaken"
            $mediaFound = $true
        }
        # Если нашли медиа — удаляем json
        if ($mediaFound) {
            Remove-Item -Path $jsonFile -Force
            $deletedCount++
        }

    } catch {
        Write-Host "Ошибка обработки $($_.FullName): $_" -ForegroundColor Red
    }
}
Write-Host "=== Готово! Удалено $deletedCount JSON-файлов."
Write-Host "=== Готово! Обновлено $UpdatedCount файлов из $TotalJson JSON ==="


