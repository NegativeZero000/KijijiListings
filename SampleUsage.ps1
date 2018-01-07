


# Format string 
# 0 - The actual search string in kijiji
# 1 - Optional page. as page-#/

$kijijiSearchURL = "https://www.kijiji.ca/b-toys-games/ottawa/{0}/k0c108l1700185r60.0?address=Arnprior&ll=45.434745,-76.351847"
$allListingResults = New-Object "System.Collections.ArrayList"

$listing= Get-KijijiURLListings -PlaceholderUrl $kijijiSearchURL -SearchString yahtzee
"Total listings: $($listing.TotalNumberOfSearchResults)"
$allListingResults.AddRange(@($listing.Listings))

#while ($listing.hasMorePages()) {
#   $listing =  Get-KijijiURLListings $listing.nextPageUrl
#   $allListingResults.AddRange($listing.Listings)
#}

# $allListingResults | select title,distance,price,image

$listing | Out-KijijiGridView