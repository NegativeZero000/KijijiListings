Add-Type -AssemblyName System.Web
Add-Type -AssemblyName System.Windows.Forms

function Get-SearchListingMetaData{
    param(
        [parameter(ValueFromPipeLine=$true)]
        $ListingString
    )
    $searchMetaData = @{}
    $numberofListingsRegex = '(?sm)<div class="showing">.*?Showing (?<FirstListingResultIndex>\d+) - (?<LastListingResultIndex>\d+) of (?<TotalNumberOfSearchResults>\d+) Ads</div>'

    # Assume no results
    $searchMetaData.FirstListingResultIndex    = 0
    $searchMetaData.LastListingResultIndex     = 0 
    $searchMetaData.TotalNumberOfSearchResults = 0


    if($ListingString -match $numberofListingsRegex ){
        $searchMetaData.FirstListingResultIndex    = $Matches["FirstListingResultIndex"] 
        $searchMetaData.LastListingResultIndex     = $Matches["LastListingResultIndex"] 
        $searchMetaData.TotalNumberOfSearchResults = $Matches["TotalNumberOfSearchResults"] 
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
			Price            = if($MatchObject.value -match $priceRegex){$matches[1].trim()};
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
    Add-Member -InputObject $listingSearchObject -MemberType ScriptProperty -Name "currentPageNumber" -Value {Get-KijijiURLPageNumber -URL $this.URL}
    # Take the current URL of the search and add a page to it. If there are no more pages use the current URL instead
    Add-Member -InputObject $listingSearchObject -MemberType ScriptProperty -Name "nextPageUrl" -Value {
        # If there are no more pages return the same url as the current one
        if($this.hasMorePages()){
            return Set-KijijiURLPageNumber -URL $this.URL -PageNumber ($this.currentPageNumber + 1)
        } else {
            return $this.URL
        }
    }

    # In trying to avoid being flagged by the system create a small delay between searches
    # Removing this is not recommended.
    Sleep -Seconds 1

    return $listingSearchObject
}

function Out-KijijiGridView{
<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   Position=0,
                   ValueFromPipeLine=$true,
                   ParameterSetName="SearchObject")]
        [PSTypeName("Kijiji.SearchResult")]
        $ListingSearchObject,

        [Parameter(Mandatory=$true,
                   Position=0,
                   ParameterSetName="ListingObjects")]
        [PSTypeName("Kijiji.Listing")]
        $ListingObjects,

        # Param2 help description
        [validatepattern({$_ -match "\d+[,x]\d+"})]
        [string]$GridSize="7,7"
    )

    Write-Verbose "ParameterSetName: $($pscmdlet.ParameterSetName)"
    if($pscmdlet.ParameterSetName -eq "SearchObject"){
        $ListingObjects = $ListingSearchObject.Listings
    }

    Add-Type -AssemblyName System.Windows.Forms

    # Load the image place holder image.
    $placeholderImagePath = "m:\scripts\noimage.png"
    if(Test-Path $placeholderImagePath -PathType Leaf){
        $placeholderImage = [system.drawing.image]::FromStream([IO.MemoryStream]::new([System.IO.File]::ReadAllBytes($placeholderImagePath)))
    } else {
        Write-Warning "Could not find: '$placeholderImagePath '. Will use random colours instead"
    }

    # Set the form and images sizes based on user input
    $imageContainerSize = [Drawing.Size]::new(100,100)  # Width, Height
    $numberofHorizontallImages,$numberofVerticalImages = [int[]]($GridSize.Split("x,"))
    $numberOfImages = [pscustomobject]@{
        Horizontal = $numberofHorizontallImages
        Vertical = $numberofVerticalImages
    }
    Write-Verbose "Displaying $($numberofHorizontallImages * $numberofVerticalImages) images in ${numberofHorizontallImages}x$numberofVerticalImages grid"
    $formOverallSize = [Drawing.Size]::new(
        $imageContainerSize.Width * $numberOfImages.Horizontal,
        $imageContainerSize.Height * $numberOfImages.Vertical
    )

    # Create the form
    $listingImageForm = New-Object System.Windows.Forms.Form
    $listingImageForm.Size  = $formOverallSize
    $listingImageForm.Text  = $listing.URL
    $listingImageForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $listingImageForm.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $formToolTip = [System.Windows.Forms.ToolTip]::new()

    # Adjust the size of the form to account for the title bar and the width of the form border. 
    Write-Verbose "ClientSize.Width     : $($listingImageForm.ClientSize.Width)" 
    Write-Verbose "ClientSize.Height    : $($listingImageForm.ClientSize.Height)" 
    # Logic for determining titlebar height and width from https://ivision.wordpress.com/2007/01/05/title-bar-height-and-form-border-width-of-net-form/
    # In practice it is not perfect but it is good enough for this.
    $formBorderWidth = ($listingImageForm.Width - $listingImageForm.ClientSize.Width) / 2
    $formTitleBarHeight = $listingImageForm.Height – $listingImageForm.ClientSize.Height – 2 * $formBorderWidth
    Write-Verbose "Form Border Width    : $formBorderWidth"
    Write-Verbose "Form TitleBar Height : $formTitleBarHeight"
    $listingImageForm.Size = [Drawing.Size]::new(
        $listingImageForm.Size.Width + $formBorderWidth,
        $listingImageForm.Size.Height + $formTitleBarHeight + $formBorderWidth 
    )
    Write-Verbose "Adjusted Form Height : $($listingImageForm.Size.Height)"
    Write-Verbose "Adjusted Form Width  : $($listingImageForm.Size.Width)"

    # Set the left/X and top/Y of the image matrix controls
    $imageMatrixXOffset = 0
    $imageMatrixYOffset = 0

    # Create an image matrix from the images provided in a listing group
    for ($verticalImageIndex = 0; $verticalImageIndex -lt $numberOfImages.Vertical; $verticalImageIndex++){ 
        for ($horizonalImageIndex = 0; $horizonalImageIndex -lt $numberOfImages.Horizontal; $horizonalImageIndex++){ 
     
            $listingImage = [System.Windows.Forms.PictureBox]::new()
            $listingImage.Size = $imageContainerSize
            $listingImage.BorderStyle = [System.Windows.Forms.BorderStyle]::None
            $listingImage.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::StretchImage
            $listingImage.Location = [System.Drawing.Point]::new($horizonalImageIndex * $listingImage.Size.Width  + $imageMatrixXOffset, 
                                                                 $verticalImageIndex  * $listingImage.Size.Height + $imageMatrixYOffset )
            
            # Determine the integer index of the next image in the collection
            $listingIndex = $verticalImageIndex * $numberOfImages.Vertical + $horizonalImageIndex
            
            # Set a tool tip for the picture box
            $formToolTip.SetToolTip($listingImage, $ListingObjects[$listingIndex].Title)

            # Fill the picture box. With an image if possible. If not attempt the place holder image or a random color
            if($ListingObjects[$listingIndex].ImageBytes){
                $listingImage.Image = [System.Drawing.Image]::FromStream([IO.MemoryStream]::new($ListingObjects[$listingIndex].ImageBytes))
            } elseif ($placeholderImage){
                $listingImage.Image = $placeholderImage
            } else {
                $listingImage.BackColor =  [System.Drawing.Color]::FromArgb((random 256),(random 256),(random 256),(random 256))
            }
            
            # Add a click event to the kijiji posting. Add the URL into the Tag so its accessible within the event
            $listingImage.Tag = $ListingObjects[$listingIndex].AbsoluteURL
            $listingImage.add_click({param($Sender)Start-Process $sender.Tag})
            

            # Download the image as a memory stream to bypass saving the file
            $listingImageForm.Controls.Add($listingImage)
        }
    }

    # Show the form
    $listingImageForm.Add_Shown({$listingImageForm.Activate()})
    [void]$listingImageForm.ShowDialog()
    Write-Verbose "End Form Height     : $($listingImageForm.Size.Height)"
    Write-Verbose "End Form Width      : $($listingImageForm.Size.Width)"
    Write-Verbose "Image Height        : $($imageContainerSize.Height)"
    Write-Verbose "Image Width         : $($imageContainerSize.Width)"

    # The form is closed. Clean up
    $listingImageForm.Dispose()
}

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