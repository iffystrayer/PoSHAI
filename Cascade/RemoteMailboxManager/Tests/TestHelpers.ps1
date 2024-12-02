function Export-PowerShellData {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$InputObject,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $content = "@{`n"
    foreach ($key in $InputObject.Keys) {
        $value = $InputObject[$key]
        if ($value -is [string]) {
            $content += "    $key = '$value'`n"
        }
        elseif ($value -is [array]) {
            $content += "    $key = @(`n"
            foreach ($item in $value) {
                $content += "        '$item'`n"
            }
            $content += "    )`n"
        }
        else {
            $content += "    $key = $value`n"
        }
    }
    $content += "}"
    
    Set-Content -Path $Path -Value $content
}
