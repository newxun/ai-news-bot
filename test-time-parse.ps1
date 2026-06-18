# Test time parsing and timezone conversion

$rawTime = "2026-06-16T22:59:32Z"

Write-Output "Raw GitHub API time: $rawTime"
Write-Output ""

# Method 1: Parse with AssumeUniversal
$parsed1 = [DateTime]::Parse($rawTime, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal)
Write-Output "Method 1 - Parse with AssumeUniversal:"
Write-Output "  Parsed: $parsed1"
Write-Output "  Kind: $($parsed1.Kind)"
Write-Output ""

# Method 2: Specify as UTC explicitly
$specifiedUtc = [DateTime]::SpecifyKind($parsed1, [DateTimeKind]::Utc)
Write-Output "Method 2 - SpecifyKind as UTC:"
Write-Output "  Specified: $specifiedUtc"
Write-Output "  Kind: $($specifiedUtc.Kind)"
Write-Output ""

# Method 3: Convert to Beijing time
$beijingTz = [System.TimeZoneInfo]::FindSystemTimeZoneById("China Standard Time")
$beijingTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($specifiedUtc, $beijingTz)
Write-Output "Method 3 - Convert to Beijing:"
Write-Output "  Beijing time: $beijingTime"
Write-Output ""

# Method 4: What if we parse directly to local?
Write-Output "Method 4 - Direct Parse to Local:"
$parsedLocal = [DateTime]::Parse($rawTime)
Write-Output "  Parsed Local: $parsedLocal"
Write-Output "  Kind: $($parsedLocal.Kind)"
Write-Output ""

# Method 5: Using DateTimeOffset
Write-Output "Method 5 - Using DateTimeOffset:"
$offset = [DateTimeOffset]::Parse($rawTime)
Write-Output "  DateTimeOffset: $offset"
Write-Output "  UTC: $($offset.UtcDateTime)"
Write-Output "  LocalDateTime: $($offset.LocalDateTime)"
