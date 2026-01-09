[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

$REPO_OWNER = "typst-g7-32"
$REPO_NAME = "modern-g7-32"
$GITHUB_API = "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest"
$GIT_URL = "https://github.com/$REPO_OWNER/$REPO_NAME"

Write-Host "==> РРЅРёС†РёР°Р»РёР·Р°С†РёСЏ СѓСЃС‚Р°РЅРѕРІРєРё РїР°РєРµС‚Р° $REPO_NAME..." -ForegroundColor Blue

try {
    $response = Invoke-RestMethod -Uri $GITHUB_API -Method Get
    $LATEST_TAG = $response.tag_name
} catch {
    Write-Host "РћС€РёР±РєР°: РќРµ СѓРґР°Р»РѕСЃСЊ РїРѕР»СѓС‡РёС‚СЊ РёРЅС„РѕСЂРјР°С†РёСЋ Рѕ РїРѕСЃР»РµРґРЅРµРј СЂРµР»РёР·Рµ." -ForegroundColor Red
    exit 1
}

if ([string]::IsNullOrEmpty($LATEST_TAG)) {
    Write-Host "РћС€РёР±РєР°: " -NoNewline -ForegroundColor Red
    Write-Host "РќРµ СѓРґР°Р»РѕСЃСЊ РїРѕР»СѓС‡РёС‚СЊ РёРЅС„РѕСЂРјР°С†РёСЋ Рѕ РїРѕСЃР»РµРґРЅРµРј СЂРµР»РёР·Рµ."
    exit 1
}

$VERSION = $LATEST_TAG -replace '^v', ''

$TARGET_DIR = Join-Path $env:LOCALAPPDATA "typst\packages\preview\$REPO_NAME\$VERSION"

Write-Host "==> " -NoNewline -ForegroundColor Blue
Write-Host "РћР±РЅР°СЂСѓР¶РµРЅР° РїРѕСЃР»РµРґРЅСЏСЏ РІРµСЂСЃРёСЏ: " -NoNewline
Write-Host $VERSION -ForegroundColor Green
Write-Host "==> " -NoNewline -ForegroundColor Blue
Write-Host "Р¦РµР»РµРІР°СЏ РґРёСЂРµРєС‚РѕСЂРёСЏ: $TARGET_DIR"

function Draw-ProgressBar {
    param(
        [System.Management.Automation.Job]$Job
    )
    
    $delay = 100
    $i = 0
    $direction = 1
    
    [Console]::CursorVisible = $false
    
    try {
        while ($Job.State -eq "Running") {
            $spaces = 30 - $i
            $bar = "[Р—Р°РіСЂСѓР·РєР°] ["
            
            for ($j = 0; $j -lt $i; $j++) {
                $bar += " "
            }
            $bar += '<=>'
            for ($j = 0; $j -lt $spaces; $j++) {
                $bar += " "
            }
            $bar += "]"
            
            Write-Host "`r$bar" -NoNewline -ForegroundColor Yellow
            
            $i += $direction
            if ($i -ge 28 -or $i -le 0) {
                $direction = $direction * -1
            }
            
            Start-Sleep -Milliseconds $delay
        }
    } finally {
        $clearLine = "`r" + (" " * 80) + "`r"
        Write-Host $clearLine -NoNewline
        [Console]::CursorVisible = $true
    }
}

$job = Start-Job -ScriptBlock {
    param($TargetDir, $GitUrl, $Tag)
    
    function Invoke-GitOpsInternal {
        param(
            [string]$Dir,
            [string]$Url,
            [string]$Tag
        )
        
        if ((Test-Path $Dir) -and (Test-Path (Join-Path $Dir ".git"))) {
            $ErrorActionPreference = 'SilentlyContinue'
            $currentTag = git -C $Dir describe --tags --exact-match
            $ErrorActionPreference = 'Continue'
            if ($LASTEXITCODE -eq 0 -and $currentTag -eq $Tag) {
                return 0
            }
            
            try {
                $null = git -C $Dir fetch origin --tags 2>&1 | Out-Null
                $null = git -C $Dir checkout $Tag 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    return 0
                }
            } catch {
            }
            
            return 2
        }
        
        if (Test-Path $Dir) {
            Remove-Item -Path $Dir -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        $parentDir = Split-Path -Parent $Dir
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        
        try {
            $null = git clone --depth 1 --branch $Tag $Url $Dir 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                return 0
            }
            $null = git clone --depth 1 $Url $Dir 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $null = git -C $Dir fetch origin tag $Tag 2>&1 | Out-Null
                $null = git -C $Dir checkout $Tag 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    return 0
                }
            }
            return 1
        } catch {
            return 1
        }
    }
    
    $res = Invoke-GitOpsInternal -Dir $TargetDir -Url $GitUrl -Tag $Tag
    
    if ($res -eq 2) {
        if (Test-Path $TargetDir) {
            Remove-Item -Path $TargetDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        $parentDir = Split-Path -Parent $TargetDir
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        
        try {
            $null = git clone --depth 1 --branch $Tag $GitUrl $TargetDir 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                return 0
            }
            $null = git clone --depth 1 $GitUrl $TargetDir 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $null = git -C $TargetDir fetch origin tag $Tag 2>&1 | Out-Null
                $null = git -C $TargetDir checkout $Tag 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    return 0
                }
            }
            return 1
        } catch {
            return 1
        }
    }
    
    return $res
} -ArgumentList $TARGET_DIR, $GIT_URL, $LATEST_TAG

Draw-ProgressBar -Job $job

$job | Wait-Job | Out-Null
$result = Receive-Job -Job $job
Remove-Job -Job $job

$EXIT_CODE = $result

if ($EXIT_CODE -eq 0) {
    Write-Host "вњ” РЈСЃРїРµС€РЅРѕ! " -NoNewline -ForegroundColor Green
    Write-Host "РџР°РєРµС‚ СѓСЃС‚Р°РЅРѕРІР»РµРЅ РІ $TARGET_DIR"
} elseif ($EXIT_CODE -eq 2) {
    Write-Host "вљ  Р’РЅРёРјР°РЅРёРµ: " -NoNewline -ForegroundColor Yellow
    Write-Host "Git pull РЅРµ СѓРґР°Р»СЃСЏ, Р±С‹Р»Р° РІС‹РїРѕР»РЅРµРЅР° РїРѕР»РЅР°СЏ РїРµСЂРµСѓСЃС‚Р°РЅРѕРІРєР°."
    Write-Host "вњ” РЈСЃРїРµС€РЅРѕ! " -NoNewline -ForegroundColor Green
    Write-Host "Р РµРїРѕР·РёС‚РѕСЂРёР№ РїРµСЂРµР·Р°РїРёСЃР°РЅ."
} else {
    Write-Host "вњ– РћС€РёР±РєР°: " -NoNewline -ForegroundColor Red
    Write-Host "РќРµ СѓРґР°Р»РѕСЃСЊ СЃРєР°С‡Р°С‚СЊ РёР»Рё РѕР±РЅРѕРІРёС‚СЊ СЂРµРїРѕР·РёС‚РѕСЂРёР№."
    exit 1
}

