# Import the module. 
# Load this into a common module location as defined by $env:PSModulePath
# or use an absolute path
Import-Module M:\Code\KijijiListings\KijijiListings\Kijiji-Listings.psm1

# Note the region comments will appear to be doubled. This is so I can see it easier on my darktheme in ISE
# Bug: https://windowsserver.uservoice.com/forums/301869-powershell/suggestions/18838177-collapsed-region-in-dark-mode-is-hardly-visible

# region Simple search
#region Simple search
# A manual search of kijiji is required to get the correct location and category.
$kijijiSearchURL = "https://www.kijiji.ca/b-toys-games/ottawa/monopoly/k0c108l1700185r60.0"
$searchListing = Get-KijijiURLListings -BaseUrl $kijijiSearchURL 

# Display information of the results.
Write-Host "Total listings: $($listing.TotalNumberOfSearchResults)" -ForegroundColor Green
$listing.Listings
#endregion

# region Keyword seach
#region Keyword seach
# A manual search of kijiji is required to get the correct location and category.
# You can use a placeholder URL which allows the insertion of search terms.
$kijijiSearchURL = "https://www.kijiji.ca/b-toys-games/ottawa/{0}/k0c108l1700185r60.0"
$searchListing = Get-KijijiURLListings -PlaceholderUrl $kijijiSearchURL -SearchString yahtzee

# Display information of the results.
Write-Host "Total listings: $($listing.TotalNumberOfSearchResults)" -ForegroundColor Green
$listing.Listings
#endregion

# region Simple search image gallery
#region Simple search image gallery
# A manual search of kijiji is required to get the correct location and category.
# The output of this searches images will be displayed as an image gallery with clickable 
# links to the actual posts. 
$kijijiSearchURL = "https://www.kijiji.ca/b-toys-games/ottawa/monopoly/k0c108l1700185r60.0"
$searchListing = Get-KijijiURLListings -BaseUrl $kijijiSearchURL 
# Display information of the results.
Write-Host "Total listings: $($listing.TotalNumberOfSearchResults)" -ForegroundColor Green
$listing | Out-KijijiGridView
#endregion