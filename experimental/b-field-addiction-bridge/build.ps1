$ErrorActionPreference = 'Stop'
$game = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
$java = 'D:/Program Files/Adobe Animate 2024/jre/bin/java.exe'
$sdk = Join-Path $game 'mods/Sandevistan/build/tools/flexsdk'
$original = Join-Path $game 'mods/AddictionSystem/build'
$output = Join-Path $PSScriptRoot 'build'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$compileArgs = @(
    "-load-config=$original/air-config.xml", '-static-link-runtime-shared-libraries=true',
    '-theme=', '-compiler.fonts.local-fonts-snapshot=', "-source-path=$PSScriptRoot/src",
    "-external-library-path+=$original/stubs.swc",
    '-includes=fe.unit.AddictionInvent,fe.unit.AddictionPers,fe.inter.AddictionUIBridge',
    "-link-report=$output/link-report.xml", "-output=$output/AddictionSystemMod.swf", "$PSScriptRoot/src/AddictionDoc.as"
)
& $java -Xmx768m -jar "$sdk/lib/mxmlc.jar" @compileArgs 2>&1 | Tee-Object -FilePath "$output/compile.log"
if ($LASTEXITCODE -ne 0) { throw 'Independent AddictionSystem bridge compile failed' }
$report = Get-Content -LiteralPath "$output/link-report.xml" -Raw
foreach ($native in @('fe.unit:Unit','fe.unit:Invent','fe.unit:Pers','fe.inter:PipBuck')) {
    if ($report -match ('<def id="' + [regex]::Escape($native) + '"')) { throw "Embedded native class: $native" }
}
Get-FileHash -LiteralPath "$output/AddictionSystemMod.swf" -Algorithm SHA256
