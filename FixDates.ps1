$BasePath = "D:\Photo\GooglePhoto"

# Список расширений фото/видео
$mediaExtensions = @("jpg","jpeg","png","gif","mp4","mov","avi","heic","webp")

$deletedCount = 0

# Ищем все JSON файлы
Get-ChildItem -Path $BasePath -Recurse -File -Filter "*.json" | ForEach-Object {
    $jsonFile = $_.FullName

    # Пропускаем supplemental-metadata
    if ($jsonFile -match "\.supplemental-metadata") {
        return
    }

    # Имя медиафайла = имя json без .json и без возможного (n)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($jsonFile)

    # Удаляем суффикс (2), (3), ...
    $cleanName = $baseName -replace '\(\d+\)$',''

    # Папка, где лежит json
    $dir = $_.DirectoryName

    # Ищем медиафайл с таким именем
    $mediaFound = $false
    foreach ($ext in $mediaExtensions) {
        $mediaPath1 = Join-Path $dir "$cleanName.$ext"
        $mediaPath2 = Join-Path $dir "$cleanName($([regex]::Match($baseName,'\d+').Value)).$ext"

        if (Test-Path $mediaPath1 -PathType Leaf -or Test-Path $mediaPath2 -PathType Leaf) {
            $mediaFound = $true
            break
        }
    }

    # Если нашли медиа — удаляем json
    if ($mediaFound) {
        Remove-Item -Path $jsonFile -Force
        $deletedCount++
    }
}

Write-Host "Готово! Удалено $deletedCount JSON-файлов."
