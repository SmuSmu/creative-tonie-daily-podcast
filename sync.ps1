[String]$URL_AUTH = "https://login.tonies.com/auth/realms/tonies/protocol/openid-connect/token"
[String]$USER = $Env:TONIEUSR
[String]$PASS = $Env:TONIEPWD
# URL des Podcast-Feeds
$feedUrl = "https://kinder.wdr.de/radio/diemaus/audio/diemaus-60/diemaus-60-106.podcast"

[String]$TonieHousehold = '4faa54bc-c7dc-4324-9922-156b9305e8ad'
[String]$TonieCreativeTonie = '2148D911500304E0'

$Body = @{
    "grant_type" = "password" ;
    "client_id" = "my-tonies" ;
    "scope" = "openid" ;
    "username" = $USER ;
    "password" = $PASS
    }


$AuthResponse = Invoke-RestMethod -UseBasicParsing -Uri $URL_AUTH -Method "POST" -Body $Body


$Token = $AuthResponse.access_token




[xml]$rss = (Invoke-WebRequest -Uri $feedUrl).Content
$latestItem = $rss.rss.channel.item | Select-Object -Last 1


# Hole die URL der Audiodatei
$audioUrl = $latestItem.enclosure.url

# Bestimme den Dateinamen
$RSSFileName = $latestItem.title + '.mp3'
$RSSFileName = ($RSSFileName -replace ' ', '_') -replace '[^a-zA-Z0-9_\-\.]', ''

# Zielpfad für den Download
$destination = Join-Path -Path $env:TMP -ChildPath "$RSSFileName"


Invoke-WebRequest $audioUrl -OutFile $destination

Write-Host "Heruntergeladen: $fileName nach $destination"


$postParams = @{
            'Authorization' = 'Bearer ' + $Token
            'Content-Type' = "application/json"
            }

#$households = Invoke-RestMethod -Uri ('https://api.prod.tcs.toys/v2/households') -Method Get -ContentType "application/json" -Headers $postParams


#$creativetonies = Invoke-RestMethod -Uri ('https://api.prod.tcs.toys/v2/households/'+ $households.id +'/creativetonies') -Method Get -ContentType "application/json" -Headers $postParams

#$creativetoniePiraten = Invoke-RestMethod -Uri ('https://api.prod.tcs.toys/v2/households/'+ $households.id +'/creativetonies/D642FF12500304E0') -Method Get -ContentType "application/json" -Headers $postParams

Invoke-RestMethod -Uri ('https://api.prod.tcs.toys/v2/households/'+ $TonieHousehold +'/creativetonies/' + $TonieCreativeTonie) -Method Get -ContentType "application/json" -Headers $postParams


#$creativetoniePiraten = Invoke-RestMethod -Uri ('https://api.prod.tcs.toys/v2/households/'+ $households.id +'/creativetonies/D642FF12500304E0') -Method Options -ContentType "application/json" -Headers $postParams


#Write-Host Leeren
#$creativetonieLeeren = Invoke-RestMethod -Uri ('https://api.prod.tcs.toys/v2/households/'+ $TonieHousehold +'/creativetonies/' + $TonieCreativeTonie) -Method Patch -ContentType "application/json" -Body "{`"chapters`":[]}" -Headers $postParams

Write-Host ermittleUpload
$fileupload = Invoke-RestMethod -Uri ('https://api.prod.tcs.toys/v2/file') -Method POST -ContentType "application/json" -Headers $postParams


# Formulardaten definieren
$formFields = @{
    "key" = $fileupload.request.fields.key
    "x-amz-algorithm" = $fileupload.request.fields.'x-amz-algorithm'
    "x-amz-credential" = $fileupload.request.fields.'x-amz-credential'
    "x-amz-date" = $fileupload.request.fields.'x-amz-date'
    "x-amz-security-token" = $fileupload.request.fields.'x-amz-security-token'
    "policy" = $fileupload.request.fields.policy
    "x-amz-signature" = $fileupload.request.fields.'x-amz-signature'
    }


# Datei, die hochgeladen werden soll
$filePath = $destination
$fileName = $fileupload.fileId
$fileBytes = [System.IO.File]::ReadAllBytes($filePath)

# Multipart-Formular erstellen
$boundary = [System.Guid]::NewGuid().ToString()
$LF = "`r`n"
$bodyLines = @()

# Formulardaten einfügen
foreach ($key in $formFields.Keys) {
    $bodyLines += "--$boundary"
    $bodyLines += "Content-Disposition: form-data; name=`"$key`""
    $bodyLines += ""
    $bodyLines += $formFields[$key]
    }

# Datei einfügen
$bodyLines += "--$boundary"
$bodyLines += "Content-Disposition: form-data; name=`"file`"; filename=`"$fileName`""
$bodyLines += "Content-Type: audio/mpeg"
$bodyLines += ""
$bodyLines += [System.Text.Encoding]::GetEncoding("ISO-8859-1").GetString($fileBytes)

# Abschluss
$bodyLines += "--$boundary--"
$bodyLines += ""

# Body zusammenbauen
$body = $bodyLines -join $LF
$bytes = [System.Text.Encoding]::GetEncoding("ISO-8859-1").GetBytes($body)

Write-Host Upload

# Anfrage senden
Invoke-RestMethod -Uri $fileupload.request.url -Method Post -Body $bytes -ContentType "multipart/form-data; boundary=$boundary"



Write-Host Tonie updaten

$Body = '{"chapters":[{"id":"'
$Body += $fileupload.fileId
$Body += '","file":"'
$Body += $fileupload.fileId
$Body += '","title":"'
$Body += $RSSFileName
$Body += '","seconds":0,"type":"file"}]}'

$creativetoniePiratenUpdate= Invoke-RestMethod -Uri ('https://api.prod.tcs.toys/v2/households/'+ $TonieHousehold +'/creativetonies/' + $TonieCreativeTonie) -Method Patch -ContentType "application/json" -Body $Body -Headers $postParams


