Add-Type -AssemblyName System.Web
Add-Type -AssemblyName System.Windows.Forms

<#
.SYNOPSIS
    Parses webcontent for meta data to describe a search 
.DESCRIPTION
    Gather information via webscraping from search results for statistics on the search itself. 
    These are useful for determining how many items were found and if there are more on other pages.
.PARAMETER HTMLString
    String containing the raw HTML from a web page.
.EXAMPLE
    $listingMetaData = $scrapedText | Get-SearchListingMetaData
.EXAMPLE
    Get-SearchListingMetaData -HTML $scrapedText
.INPUTS
   System.String. You can pipe HTML strings to Get-SearchListingMetaData
.OUTPUTS
   System.Collections.Hashtable. Get-SearchListingMetaData returns a hashtable of navigation based findings.
#>
function Get-SearchListingMetaData{
    param(
        [parameter(ValueFromPipeLine=$true)]
        [string]$HTMLString
    )
    $searchMetaData = @{}
    $numberofListingsRegex = '(?sm)<div class="showing">.*?Showing (?<FirstListingResultIndex>[\d,]+) - (?<LastListingResultIndex>[\d,]+) of (?<TotalNumberOfSearchResults>[\d,]+) Ads</div>'

    # Assume no results
    $searchMetaData.FirstListingResultIndex    = 0
    $searchMetaData.LastListingResultIndex     = 0 
    $searchMetaData.TotalNumberOfSearchResults = 0


    if($HTMLString -match $numberofListingsRegex ){
        $searchMetaData.FirstListingResultIndex    = $Matches["FirstListingResultIndex"] -as [int]
        $searchMetaData.LastListingResultIndex     = $Matches["LastListingResultIndex"]  -as [int]
        $searchMetaData.TotalNumberOfSearchResults = $Matches["TotalNumberOfSearchResults"]  -as [int]
    }
    return $searchMetaData
}

<#
.SYNOPSIS
    Get the current Kijiji page in a given search.
.DESCRIPTION
    Parses a URI to get the page number in a Kijiji search. If no page number is present then 1 is assumed.
.PARAMETER URL
    A Kijiji search address
.EXAMPLE
    Get-KijijiURLPageNumber $Kijijiwebaddress
.INPUTS
   None. You cannot pipe objects to Get-KijijiURLPageNumber
.OUTPUTS
   System.Int32. The page number found in a URI segement or 1
#>
function Get-KijijiURLPageNumber{
    param(
        [validateScript({$_.Host -eq "www.kijiji.ca"})]
        [Alias("URI")]
        [uri]$URL
    )

    # Check to see if this url has a page number component. 
    # When split on segments the page should be the second last component.

    # Pull the page number out of the segment "page-##/"
    [int]$pageNumber = if($URL.segments[-2] -match "page\-(\d+)"){$Matches[1]}else{1}

    return $pageNumber
}

<#
.SYNOPSIS
    Set a given page number into a given Kijiji search.
.DESCRIPTION
    Parses a URI to get the page number in a Kijiji search. If no page number is present then 1 is assumed.
    This will not validate if the search will return anything of value. 
.PARAMETER URL
    A Kijiji search address
.PARAMETER PageNumber
    A new non-zero integer that will be used as the new page number.
.EXAMPLE
    Set-KijijiURLPageNumber $Kijijiwebaddress -PageNumber 2
.INPUTS
   None. You cannot pipe objects to Set-KijijiURLPageNumber
.OUTPUTS
   System.String. A rebuilt search URL is returned
#>
function Set-KijijiURLPageNumber{
    [cmdletbinding()]
    param(
        [validateScript({$_.Host -eq "www.kijiji.ca"})]
        [Alias("URI")]
        [uri]$URL,

        [ValidateScript({$_ -gt 0})]
        [Alias("Number")]
        [int]$PageNumber
    )

    # Rebuild the url based on the URI parts. 
    Write-Verbose "Adjusting page of: '$URL'"
    Write-Verbose "Segments: $($URL.Segments.Count) - '$($URL.Segments -join '')'"
    # Edit the segments to either add a page designation or replace the existing one.
    $updatedSegments = 0..($URL.Segments.Count - 1) | ForEach-Object{
        
        
        # It seems the page segment is always the second last when present.
        If($_ -eq ($URL.Segments.Count -2)){
            Write-Verbose "URI Segment $_`: $($URL.Segments[$_])"
            # If this segment is not already a page number then add this back to the segment chain.
            if($URL.Segments[$_] -notmatch "page\-\d+"){
                Write-Verbose "Added non-page segment back to chain"
                $URL.Segments[$_]
            }

            # Substitute or add this segment with a new page number
            "page-$PageNumber/"
        } else {
            # Pass this segment as normal
            $URL.Segments[$_]
        }
    }

    # Rebuild the URI and return
    return ([System.UriBuilder]::new($URL.Scheme,$URL.Host,$URL.port, -join $updatedSegments,$URL.Query)).Uri.AbsoluteUri
}

<#
.SYNOPSIS
    Parses webcontent for meta data to describe a search 
.DESCRIPTION
    Gather information via webscraping from search results for statistics on the search itself. 
    These are useful for determining how many items were found and if there are more on other pages.
.PARAMETER HTMLString
    String containing the raw HTML from a web page.
.EXAMPLE
    $listingMetaData = $scrapedText | Get-SearchListingMetaData
.EXAMPLE
    Get-SearchListingMetaData -HTML $scrapedText
.INPUTS
   System.String. You can pipe HTML strings to Get-SearchListingMetaData
.OUTPUTS
   System.Collections.Hashtable. Get-SearchListingMetaData returns a hashtable of navigation based findings.
#>
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

<#
.SYNOPSIS
    Creates a search object containing meta data and listings from a Kijiji web search
.DESCRIPTION
    Collects information from other module cmdlets to build one final search object that has information
    about the search itself as well as the individual listings found.
    Slightly more complex searches can be done with preconfigured strings that allow for mulitple kijiji seaches 
    within the same location and category.
.PARAMETER BaseUrl
    String containing the Kjiji search URL.
.PARAMETER PlaceholderUrl
    String containing the Kjiji search URL with a format placeholder to allow for search strings to be used.
.PARAMETER SearchString
    String used to limit search much the same as the interactive site.
.EXAMPLE
    $searchListing = Get-KijijiURLListings -BaseUrl $kijijiSearchURL 
.EXAMPLE
    Get-KijijiURLListings -PlaceholderUrl "https://www.kijiji.ca/b-toys-games/ottawa/{0}/k0c108l1700185r60.0" -SearchString yahtzee
.INPUTS
   System.String. You can pipe HTML strings to Get-SearchListingMetaData
.OUTPUTS
   System.Management.Automation.PSCustomObject. Get-KijijiURLListings returns a custom Kijiji.SearchResult object
#>
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
        $SearchString
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