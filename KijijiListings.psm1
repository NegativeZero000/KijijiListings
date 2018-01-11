Add-Type -AssemblyName System.Web
Add-Type -AssemblyName System.Windows.Forms

function Get-SearchListingMetaData{
    param(
        [parameter(ValueFromPipeLine=$true)]
        $ListingString
    )
    $searchMetaData = @{}
    $numberofListingsRegex = '(?sm)<div class="showing">.*?Showing (?<FirstListingResultIndex>[\d,]+) - (?<LastListingResultIndex>[\d,]+) of (?<TotalNumberOfSearchResults>[\d,]+) Ads</div>'

    # Assume no results
    $searchMetaData.FirstListingResultIndex    = 0
    $searchMetaData.LastListingResultIndex     = 0 
    $searchMetaData.TotalNumberOfSearchResults = 0


    if($ListingString -match $numberofListingsRegex ){
        $searchMetaData.FirstListingResultIndex    = $Matches["FirstListingResultIndex"] -as [int]
        $searchMetaData.LastListingResultIndex     = $Matches["LastListingResultIndex"]  -as [int]
        $searchMetaData.TotalNumberOfSearchResults = $Matches["TotalNumberOfSearchResults"]  -as [int]
    }
    return $searchMetaData
}

function Get-KijijiURLPageNumber{
    param(
        [validatePattern("^https://www\.kijiji\.ca")]
        [validatescript({$_ -as [uri]})]
        [string]$URL
    )

    # Check to see if this url has a page number component. 
    # When split on forward slashes the page should be the second last component.
    # If the user search query is exactly page # then this could fail if we are the first page
    # but the risk is minimal. It seems that the page number is always the 5th segement in the URI. 


    # Pull the page number out of the segment "page-##/"
    $URI = $URL -as [uri]
    # [int]$pageNumber = $URI.segments | Where-Object{$_ -match "page\-(\d+)"} | Select-Object -Last 1 | ForEach-Object{$Matches[1]}
    [int]$pageNumber = if($URI.segments[4] -match "page\-(\d+)"){$Matches[1]}else{1}

    return $pageNumber
}

function Set-KijijiURLPageNumber{
    param(
        [validatePattern("^https://www\.kijiji\.ca")]
        [validatescript({$_ -as [uri]})]
        [string]$URL,

        [ValidateScript({$_ -gt 0})]
        [int]$PageNumber
    )

    $URI = $URL -as [uri]

    # Rebuild the url based on the URI parts. 
    # Edit the segments to either add a page designation or replace the existing one.
    $updatedSegments = 0..($URI.Segments.Count - 1) | ForEach-Object{
        switch($_){
            # It seems that the page number is always the 5th segement in the URI. 
            4{
                # Substitute this segment with a new page number
                "page-$PageNumber/"

                # If this segment is not already a page number then add this back to the segment chain.
                if($URI.Segments[$_] -notmatch "page\-\d+"){
                    $URI.Segments[$_]
                }
            }
            default{$URI.Segments[$_]}
        }
    }

    # Rebuild the URI and return
    return ([System.UriBuilder]::new($URI.Scheme,$URI.Host,$URI.port, -join $updatedSegments,$URI.Query)).Uri.AbsoluteUri
}

function Convert-KijijiListingToObject{
    param(
        [parameter(
            Mandatory,
            Position=0,
            ValueFromPipeline=$true)]
        $MatchObject,

        [parameter(
            Mandatory)]
        [validatescript({$_ -as [uri]})]
        $RootListingURL,

        [switch]$DownloadImages=$false
    )

    begin{
        # Set some listing regex patterns
		$idRegex          = '(?sm)data-ad-id="(\w+)"'
		$urlRegex         = '(?sm)data-vip-url="(.*?)"'
		$priceRegex       = '(?sm)<div class="price">(.*?)</div>'
        $imageRegex       = '(?sm)<div class="image">.*?<img src="(.*?)"'
		$titleRegex       = '(?sm)<div class="title">.*?">(.*?)</a>'
		$distanceRegex    = '(?sm)<div class="distance">(.*?)</div>'
		$locationRegex    = '(?sm)<div class="location">(.*?)<span'
		$postedTimeRegex  = '<span class="date-posted">(.*?)</span>'
		$descriptionRegex = '(?sm)<div class="description">(.*?)<div class="details">'
            
        # Get the initial text from the page
        $webClient = New-Object System.Net.WebClient
    }
    process{
        $listingObject = [pscustomobject]@{
            PSTypeName       = "Kijiji.Listing"
			ID               = if($MatchObject.value -match $idRegex){$matches[1]};
			URL              = if($MatchObject.value -match $urlRegex){$matches[1]};
            AbsoluteURL      = ''
			Price            = if($MatchObject.value -match $priceRegex){$matches[1].trim().trimstart('$')};
			Title            = if($MatchObject.value -match $titleRegex){[System.Web.HttpUtility]::HtmlDecode($matches[1].trim())};
			Distance         = if($MatchObject.value -match $distanceRegex){[System.Web.HttpUtility]::HtmlDecode($matches[1].trim())};
			Location         = if($MatchObject.value -match $locationRegex){[System.Web.HttpUtility]::HtmlDecode($matches[1].trim())};
			Posted           = if($MatchObject.value -match $postedTimeRegex){[System.Web.HttpUtility]::HtmlDecode($matches[1].trim())};
			ShortDescription = if($MatchObject.value -match $descriptionRegex){[System.Web.HttpUtility]::HtmlDecode($matches[1].trim())};
            ImageURL         = if($MatchObject.value -match $imageRegex){$matches[1]};
            ImageBytes       = ''
        }

        $listingObject.AbsoluteURL = ([System.UriBuilder]::new($RootListingURL + $listingObject.URL)).Uri.AbsoluteUri

        if($DownloadImages.IsPresent){
            $listingObject.ImageBytes = $webClient.DownloadData($listingObject.ImageURL)
        }

        # If this object will be displayed in a gallery use the AbsoluteURL as the Action
        Add-Member -InputObject $listingObject -MemberType AliasProperty -Name "Action" -Value 'AbsoluteURL'

        return $listingObject
    }
}

function Get-KijijiURLListings{
    [cmdletbinding(DefaultParameterSetName="Simple")]
    param(
        [Parameter(
            Mandatory,
            ParameterSetName="Simple",
            Position=0)]
        [ValidateScript({$_ -as [uri]})]
        $BaseUrl,

        [Parameter(
            Mandatory,
            ParameterSetName="Formatted",
            Position=0)]
        [ValidatePattern("\{0}")]
        $PlaceholderUrl,

        [Parameter(
            Mandatory,
            ParameterSetName="Formatted",
            Position=1)]
        $SearchString,

        [Parameter(Mandatory=$false)]
        [switch]$All
    )

    # Get the initial text from the page
    $webClient = New-Object System.Net.WebClient

    # Update the search string based on the parameter set
    if($pscmdlet.ParameterSetName -eq "Formatted"){
        $BaseUrl = $PlaceholderUrl -f $SearchString
    }

    # Attempt to download the page as a string
    $scrapedText = $webClient.DownloadString($BaseUrl)

    # Gather the search meta data for making the listing object
    $listingMetaData = $scrapedText | Get-SearchListingMetaData
    $listingMetaData.PSTypeName = "Kijiji.SearchResult"
    $listingMetaData.RequestedURL = $BaseUrl
    $listingMetaData.SearchString = $SearchString
    # Parse some information from the supplied $baseurl
    $listingMetaData.URLLeftPart = ([uri]$BaseUrl).GetLeftPart([System.UriPartial]::Authority)
    $listingMetaData.URLType = $pscmdlet.ParameterSetName

    # Convert the listing into objects and add it to the search results
    $kijijiListingRegex = '(?sm)data-ad-id="(\w+)".*?<div class="details">'
    $listingObjects = Select-String -InputObject $scrapedText -Pattern $kijijiListingRegex -AllMatches | Select -ExpandProperty Matches | Convert-KijijiListingToObject -RootListingURL $listingMetaData.URLLeftPart -DownloadImages
    $listingMetaData.Listings = $listingObjects

    # Add some methods to this for determining pages
    $listingSearchObject = [pscustomobject]$listingMetaData
    # If the lastIndex in the current search is less than the Total then there are more searches that can be performed
    Add-Member -InputObject $listingSearchObject -MemberType ScriptMethod -Name "hasMorePages" -Value {$this.LastListingResultIndex -lt $this.TotalNumberOfSearchResults}
    Add-Member -InputObject $listingSearchObject -MemberType ScriptProperty -Name "currentPageNumber" -Value {Get-KijijiURLPageNumber -URL $this.RequestedURL}
    # Take the current URL of the search and add a page to it. If there are no more pages use the current URL instead
    Add-Member -InputObject $listingSearchObject -MemberType ScriptProperty -Name "nextPageUrl" -Value {
        # If there are no more pages return the same url as the current one
        if($this.hasMorePages()){
            return Set-KijijiURLPageNumber -URL $this.RequestedURL -PageNumber ($this.currentPageNumber + 1)
        } else {
            return $this.URL
        }
    }

    # In trying to avoid being flagged by the system create a small delay between searches
    # Removing this is not recommended.
    Sleep -Seconds 1

    return $listingSearchObject
}