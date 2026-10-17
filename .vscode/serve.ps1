$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$rootPrefix = $root.TrimEnd('\') + '\'
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add('http://127.0.0.1:8080/')
$listener.Start()
Write-Output 'Portfolio preview running at http://127.0.0.1:8080/'

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        try {
            $relativePath = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart('/'))
            if ([string]::IsNullOrWhiteSpace($relativePath)) {
                $relativePath = 'index.html'
            }

            $filePath = [System.IO.Path]::GetFullPath((Join-Path $root $relativePath))
            if (-not $filePath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                $context.Response.StatusCode = 403
                continue
            }

            if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
                $context.Response.StatusCode = 404
                continue
            }

            $extension = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
            $context.Response.ContentType = switch ($extension) {
                '.html' { 'text/html; charset=utf-8' }
                '.css' { 'text/css; charset=utf-8' }
                '.js' { 'application/javascript; charset=utf-8' }
                '.png' { 'image/png' }
                '.jpg' { 'image/jpeg' }
                '.jpeg' { 'image/jpeg' }
                '.svg' { 'image/svg+xml' }
                default { 'application/octet-stream' }
            }

            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $context.Response.ContentLength64 = $bytes.Length
            $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        }
        catch {
            Write-Error "Preview request failed: $_"
            $context.Response.StatusCode = 500
        }
        finally {
            $context.Response.Close()
        }
    }
}
finally {
    $listener.Stop()
    $listener.Close()
}
