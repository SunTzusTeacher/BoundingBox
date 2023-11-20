# Replace 'your_geojson_file.geojson' with the actual path to your GeoJSON file
$fileContent = Get-Content -Raw -Path 'C:\Path\To\Your\Directory\your_geojson_file.geojson'

# Convert the JSON content to a PowerShell object
$jsonObject = $fileContent | ConvertFrom-Json

# Define a function to calculate the distance between two sets of coordinates
function CalculateDistance($coord1, $coord2) {
    $lat1, $lon1 = $coord1
    $lat2, $lon2 = $coord2

    $earthRadius = 6371 # Earth radius in kilometers
    $dLat = ($lat2 - $lat1) * [math]::PI / 180
    $dLon = ($lon2 - $lon1) * [math]::PI / 180
    $a = [math]::Sin($dLat / 2) * [math]::Sin($dLat / 2) + [math]::Cos($lat1 * [math]::PI / 180) * [math]::Cos($lat2 * [math]::PI / 180) * [math]::Sin($dLon / 2) * [math]::Sin($dLon / 2)
    $c = 2 * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1 - $a))
    $distance = $earthRadius * $c

    return $distance
}

# Define a function to recursively extract coordinates from different geometry types
function GetCoordinates($geometry) {
    switch ($geometry.type) {
        'Point' {
             $geometry.coordinates 
        }
        'LineString', 'MultiPoint' {
            $geometry.coordinates
        }
        'Polygon', 'MultiLineString' {
            $geometry.coordinates | ForEach-Object {
                $_ | ForEach-Object {
                    $_
                }
            }
        }
        'MultiPolygon' {
            $geometry.coordinates | ForEach-Object {
                $_ | ForEach-Object {
                    $_ | ForEach-Object {
                        $_ 
                    } 
                } 
            } 
        }
        'GeometryCollection' {
            $geometry.geometries | ForEach-Object {
                GetCoordinates $_ 
            }
        }
        default { 
            Write-Warning "Unsupported geometry type: $($geometry.type)"
        }
    }
}

# Function to group coordinates within a specified distance
function GroupCoordinates($coordinates, $distanceThreshold) {
    $groups = @()

    foreach ($coord in $coordinates) {
        $grouped = $false

        foreach ($group in $groups) {
            foreach ($existingCoord in $group) {
                if ((CalculateDistance $coord $existingCoord) -le $distanceThreshold) {
                    $group += $coord
                    $grouped = $true
                    break
                }
            }
        }

        if (-not $grouped) {
            $groups += @($coord)
        }
    }

    return $groups
}

# Extract and group coordinates within a specified distance (0.0005 degrees)
$allCoordinates = @()
foreach ($feature in $jsonObject.features) {
    $geometry = $feature.geometry

    # Extract coordinates based on geometry type
    switch ($geometry.type) {
        'Point' {
            $allCoordinates += $geometry.coordinates
        }
        'LineString', 'MultiPoint' {
             $allCoordinates += $geometry.coordinates
        }
        'Polygon', 'MultiLineString', 'MultiPolygon', 'GeometryCollection' {
            $allCoordinates += GetCoordinates $geometry 
        }
        default { 
            Write-Warning "Unsupported geometry type: $($geometry.type)" 
        }
    }
}

# Group coordinates within a specified distance (0.0005 degrees)
$distanceThreshold = 0.0005
$coordinateGroups = GroupCoordinates $allCoordinates $distanceThreshold

# Output bounding boxes for each coordinate group to 'test1.txt'
foreach ($group in $coordinateGroups) {
    $minLat = ($group | ForEach-Object { $_[0] } | Measure-Object -Minimum).Minimum
    $maxLat = ($group | ForEach-Object { $_[0] } | Measure-Object -Maximum).Maximum
    $minLon = ($group | ForEach-Object { $_[1] } | Measure-Object -Minimum).Minimum
    $maxLon = ($group | ForEach-Object { $_[1] } | Measure-Object -Maximum).Maximum

    $boundingBox = "BoundingBox: ($minLat, $minLon), ($maxLat, $maxLon)"
    Write-Output $boundingBox | Out-File -Append -FilePath 'C:\Path\To\Your\Directory\test1.txt'
}