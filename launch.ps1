 param([int]$Port=8765)
 
 $root = $PSScriptRoot
 $appFile = Join-Path $root "app.html"
 
 # Find Edge/Chrome
 $browser = $null
 $paths = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe","${env:ProgramFiles}\Microsoft\Edge\Application\msedge.exe","${env:ProgramFiles}\Google\Chrome\Application\chrome.exe")
 foreach ($p in $paths) { if (Test-Path $p) { $browser = $p; break } }
 
 if (-not $browser) {
   Write-Host "No browser found, opening file directly..."
   Start-Process $appFile
   return
 }
 
 # Start HTTP server in background
 $job = Start-Job -Name VoiceAI -ScriptBlock {
   param($p, $r)
   try {
     $tcp = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $p)
     $tcp.Start()
     $mime = @{".html"="text/html;charset=utf-8";".css"="text/css;charset=utf-8";".js"="application/javascript;charset=utf-8";".ico"="image/x-icon";".png"="image/png";".svg"="image/svg+xml";".json"="application/json";}
     while ($true) {
       $client = $tcp.AcceptTcpClient()
       $stream = $client.GetStream()
       $buf = New-Object byte[] 4096
       $n = $stream.Read($buf, 0, $buf.Length)
       $req = [System.Text.Encoding]::ASCII.GetString($buf, 0, $n)
       $first = $req.Split("`r`n")[0]
       $parts = $first.Split(" ")
       if ($parts.Length -ge 2 -and $parts[0] -eq "GET") {
         $path = $parts[1]
         $qi = $path.IndexOf("?")
         if ($qi -ge 0) { $path = $path.Substring(0, $qi) }
         if ($path -eq "/" -or $path -eq "") { $path = "/app.html" }
         $file = Join-Path $r $path.TrimStart("/")
         if (Test-Path $file) {
           $ext = [System.IO.Path]::GetExtension($file)
           $ct = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { "application/octet-stream" }
           $data = [System.IO.File]::ReadAllBytes($file)
           $hdr = "HTTP/1.1 200 OK`r`nContent-Type: $ct`r`nContent-Length: $($data.Length)`r`nConnection: close`r`nAccess-Control-Allow-Origin: *`r`n`r`n"
           $stream.Write([System.Text.Encoding]::UTF8.GetBytes($hdr), 0, $hdr.Length)
           $stream.Write($data, 0, $data.Length)
         }
       }
       $stream.Close(); $client.Close()
     }
   } catch { }
 } -ArgumentList $Port, $root
 
 # Poll port until ready (up to 5 seconds)
 $ready = $false
 for ($i = 0; $i -lt 25; $i++) {
   Start-Sleep -Milliseconds 200
   try { $tc = New-Object System.Net.Sockets.TcpClient; $tc.Connect("127.0.0.1", $Port); $tc.Close(); $ready = $true; break } catch { }
 }
 
 if ($ready) {
   Write-Host "VoiceAI started on http://localhost:$Port/app.html"
   Start-Process -FilePath $browser -ArgumentList "--app=http://localhost:$Port/app.html", "--no-first-run"
   Write-Host "Press Enter to stop the server."
   try { [void][System.Console]::ReadLine() } catch { Start-Sleep -Seconds 120 }
   Remove-Job $job -Force 2>$null
   Write-Host "Server stopped."
 } else {
   Write-Host "Server not available, opening file directly..."
   Start-Process -FilePath $browser -ArgumentList "--app=`"file:///$($appFile.Replace('\','/').Replace(' ','%20'))`"", "--no-first-run"
   Remove-Job $job -Force 2>$null
   Start-Sleep -Seconds 3
 }
