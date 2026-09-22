# Updates hosted Auth Site URL + Additional Redirect URLs for production bundle ID.
# Create a token at https://supabase.com/dashboard/account/tokens
# Usage:
#   $env:SUPABASE_ACCESS_TOKEN = "sbp_..."
#   .\scripts\update-supabase-auth-urls.ps1

param(
  [string]$ProjectRef = "dcpltazuzyyhxtkpbuiu",
  [string]$AccessToken = $env:SUPABASE_ACCESS_TOKEN
)

if (-not $AccessToken) {
  Write-Error "Set SUPABASE_ACCESS_TOKEN (Personal Access Token) first."
  exit 1
}

$uriAllowList = @(
  "com.ballonetwork.app://login-callback",
  "com.ballonetwork.app://**",
  "https://app.ballonetwork.com/login-callback",
  "https://app.ballonetwork.com/**",
  "https://app.ballonetwork.com"
) -join ","

$body = @{
  site_url = "https://app.ballonetwork.com"
  uri_allow_list = $uriAllowList
} | ConvertTo-Json

$headers = @{
  Authorization = "Bearer $AccessToken"
  "Content-Type" = "application/json"
}

$uri = "https://api.supabase.com/v1/projects/$ProjectRef/config/auth"
$result = Invoke-RestMethod -Method Patch -Uri $uri -Headers $headers -Body $body
Write-Host "Updated Auth URL config for $ProjectRef"
Write-Host ("site_url: " + $result.site_url)
Write-Host ("uri_allow_list: " + $result.uri_allow_list)
