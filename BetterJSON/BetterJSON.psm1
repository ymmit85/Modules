function BetterJSON {
param(
    $InputObject,

    [string[]]
    $Exclusions = @(),

    [string[]]
    $BaseObjects = @(),

    [Int]
    $Depth = 3,

    [Int]
    $Level = 0
)

    $JSON = """"""
    if ($null -ne $InputObject) {
        if ($InputObject -is [string]) {
            $JSON = $InputObject | ConvertTo-Json -Compress
        }
        elseif ($null -ne $InputObject.psObject.Members['GetType'] -and $InputObject.GetType().BaseType.Name -eq "ValueType") {
            $JSON = $InputObject | ConvertTo-Json -Compress
        }
        elseif ($Depth -ne $Level) {
            if ($InputObject -is [array]) {
                $JSON = "["
                $innerJSON += @($InputObject | ForEach-Object { 
                    BetterJSON -InputObject $_ -Depth $Depth -Level ($Level + 1) -Exclusions $Exclusions
                })
                $JSON += "$($innerJSON -join ",")]"
            }
            elseif ($InputObject -is [hashtable]) {
                $JSON = "{"
                $innerJSON = $InputObject.GetEnumerator() | 
                    Where-Object {"" -eq ($Exclusions -eq $_.Name)} |
                    ForEach-Object {
                        """$($_.Name)"":$(BetterJSON -InputObject $_.Value -Depth $Depth -Level ($Level + 1) -Exclusions ($Exclusions += $_.Name))"
                    }
                $JSON += "$($innerJSON -join ",")}"
            }
            else {
                $JSON = "{"
                $innerJSON = @($InputObject.psObject.Properties |
                    Where-Object {"" -eq ($Exclusions -eq $_.Name)} |
                    ForEach-Object { 
                        """$($_.Name)"":$(BetterJSON -InputObject $_.Value -Depth $Depth -Level ($Level + 1) -Exclusions ($Exclusions += $_.Name))"
                    })
                $JSON += "$($innerJSON -join ",")}"
            }
        }
        else {
            if (@($InputObject.psObject.Properties).Count -eq 0) {
                $JSON = """$($InputObject)"""
            }
            else {
                $innerJSON = @(@($InputObject.psObject.Properties | Select-Object Name) | 
                    Where-Object {$BaseObject -eq $_.Name} |
                    ForEach-Object {$InputObject.$_})
                if ($innerJSON.Count -gt 0) {
                    $JSON = $InputObject | ConvertTo-Json -Compress
                }
                elseif ($null -ne $InputObject.psObject.Members['GetType']) {
                    $JSON = """$($InputObject.GetType().Name)"""
                }
            }
        }
    }
    $JSON
}

