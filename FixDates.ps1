$BasePath = "D:\Photo\GooglePhoto"

# ������ ���������� ����/�����
$mediaExtensions = @("jpg","jpeg","png","gif","mp4","mov","avi","heic","webp")

$deletedCount = 0

# ���� ��� JSON �����
Get-ChildItem -Path $BasePath -Recurse -File -Filter "*.json" | ForEach-Object {
    $jsonFile = $_.FullName

    # ���������� supplemental-metadata
    if ($jsonFile -match "\.supplemental-metadata") {
        return
    }

    # ��� ���������� = ��� json ��� .json � ��� ���������� (n)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($jsonFile)

    # ������� ������� (2), (3), ...
    $cleanName = $baseName -replace '\(\d+\)$',''

    # �����, ��� ����� json
    $dir = $_.DirectoryName

    # ���� ��������� � ����� ������
    $mediaFound = $false
    foreach ($ext in $mediaExtensions) {
        $mediaPath1 = Join-Path $dir "$cleanName.$ext"
        $mediaPath2 = Join-Path $dir "$cleanName($([regex]::Match($baseName,'\d+').Value)).$ext"

        if (Test-Path $mediaPath1 -PathType Leaf -or Test-Path $mediaPath2 -PathType Leaf) {
            $mediaFound = $true
            break
        }
    }

    # ���� ����� ����� � ������� json
    if ($mediaFound) {
        Remove-Item -Path $jsonFile -Force
        $deletedCount++
    }
}

Write-Host "������! ������� $deletedCount JSON-������."
