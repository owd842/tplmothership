# C:\Users\LC2022\AppData\Local\sfdx\bin\sf.cmd org auth show-access-token -o storagevault941@agentforce.com

$InstanceUrl = "https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce.com"
$AccessToken = "00Dfj00000EYWGl!AQEAQHHg08geQtV6lXR61vfvdzlmzS9gvCUdXSKZpDc_6tJ.qqESCpduqUFBlDi_5sGTO7MRrl_zxJ1Tt0j_wWZ3wRfhksCi"
$Channel     = "/event/StorageVault__LogEvent__e" # Replace with your event name
$CometdUrl   = "$InstanceUrl/cometd/61.0"      # Use current API versions

$Headers = @{
    "Authorization" = "Bearer $AccessToken"
    "Content-Type"  = "application/json"
}

$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

:HandshakeLoop while ($true) {
    Write-Host "Performing CometD Handshake..." -ForegroundColor Cyan
    
    $handshakeBody = @(
        @{
            channel                  = "/meta/handshake"
            version                  = "1.0"
            minimumVersion           = "1.0"
            supportedConnectionTypes = @("long-polling")
        }
    ) | ConvertTo-Json

    try {
        $handshakeRes = Invoke-RestMethod -Uri "$cometdUrl/" -Method Post -Headers $headers -Body $handshakeBody -WebSession $session
        
        if (-not $handshakeRes[0].successful) {
            Write-Error "Handshake failed: $($handshakeRes[0].error). Retrying in 5s..."
            Start-Sleep -Seconds 5
            continue
        }

        $clientId = $handshakeRes[0].clientId
        Write-Host "Handshake successful. ClientId allocated: $clientId" -ForegroundColor Green
    }
    catch {
        Write-Error "Handshake HTTP Exception: $_. Retrying..."
        Start-Sleep -Seconds 5
        continue
    }

    # 2. Subscribe to the Platform Event Channel
    Write-Host "Subscribing to channel $channel..." -ForegroundColor Cyan
    $subscribeBody = @(
        @{
            channel      = "/meta/subscribe"
            clientId     = $clientId
            subscription = $channel
        }
    ) | ConvertTo-Json

    $subRes = Invoke-RestMethod -Uri "$cometdUrl/" -Method Post -Headers $headers -Body $subscribeBody -WebSession $session
    if (-not $subRes[0].successful) {
        Write-Error "Subscription failed: $($subRes[0].error). Restarting loop..."
        continue
    }
    Write-Host "Successfully subscribed to $channel." -ForegroundColor Green

    # 3. Enter the Long Polling Listen Loop
    Write-Host "Entering Connect Loop (Listening for events)..." -ForegroundColor Yellow
    while ($true) {
        $connectBody = @(
            @{
                channel        = "/meta/connect"
                clientId       = $clientId
                connectionType = "long-polling"
            }
        ) | ConvertTo-Json

        try {
            # This call blocks execution (long polls) until an event triggers or a timeout (~110 seconds) occurs
            $connectRes = Invoke-RestMethod -Uri "$cometdUrl/" -Method Post -Headers $headers -Body $connectBody -WebSession $session

            # Inspect array items for errors or incoming event payloads
            foreach ($msg in $connectRes) {
                # Handle standard Unknown Client or Connection drops
                if ($msg.successful -eq $false) {
                    Write-Warning "Server connection dropped. Error: $($msg.error)"
                    
                    # If server requests a full handshake re-auth, break out back to the top loop
                    if ($msg.advice.reconnect -eq "handshake" -or $msg.error -match "Unknown client") {
                        Write-Warning "Resetting connection and re-authenticating..."
                        break HandshakeLoop
                    }
                }

                # If an event payload returns on your target channel, process it
                if ($msg.channel -eq $channel) {
                    Write-Host "New Platform Event Received!" -ForegroundColor Magenta
                    $msg.data.payload | Format-List *
                }
            }
        }
        catch {
            Write-Error "Connect long-poll error encountered: $_"
            Start-Sleep -Seconds 2
            # Check if network disruption killed our session state entirely
            break HandshakeLoop
        }
    }
}
