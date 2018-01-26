Installing the module
===
You should just be able to copy to folder and all files into your `$env:PSModulePath`. If you have PowerShell 3.0 installed then that module will autoload with Powershell.

If you don't have PowerShell 3.0 or don't want to have the module autoload you can put it in another location and import the module manifest

    Import-Module M:\Code\KijijiListings\KijijiListings.psd1 -Verbose

Have a look at [docs.microsoft.com](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/import-module?view=powershell-5.1) for more on `Import-Module` and [MSDN for more on Import Modules](https://msdn.microsoft.com/en-us/library/dd878284(v=vs.85).aspx)

When importing this module you will get a warning

WARNING: The names of some imported commands from the module 'KijijiListings' include unapproved verbs that might make them less discoverable. To find the commands with unapproved verbs, run the Import-Module command again with the Verbose parameter. For a list of approved verbs, type Get-Verb.
This is expected because of the function Collect-SearchResults. I like that name and am not sure what else to call it. You can avoid that by setting warning preference but it is not a show stopper.


Sample Usage
===

Most of the power of this module comes from using preconfigured search URL in [Kijiji](https://www.kijiji.ca). For instance if you were to go looking for "Monopoly" in Ottawa you would be using the following URL: https://www.kijiji.ca/b-toys-games/ottawa/monopoly/k0c108l1700185r60.0. Making a search string is just a matter of going to the site and typing in what you want. Once that is done save that URL for use with this module.

<sup>Please note that I actually loathe Monopoly but it was an easy test case becasue of the unique search results. </sup>

Where there is a reference to a search string by the variable `$kijijiSearchURL` it is that Kijiji URL.

When a search is done it will convert and listings it finds into objects. This can be anywhere from 0 to 20 depending on the search. The search object has the means to know if there are more results available and provides some methods that can be used in loops to pull down all results. You can look at examples of this with the [Gallery View Example](#gallery-view) Be careful as vauge or generic terms can returns 1000's of results. 

### Simple Search

This will search for Monopoly in the Toys and Games category in the Ottawa location. 

    $kijijiSearchURL = "https://www.kijiji.ca/b-toys-games/ottawa/monopoly/k0c108l1700185r60.0"
    $searchListing = Get-KijijiURLListings -BaseUrl $kijijiSearchURL 
    
Now search listing will contain a search object that has a Listing property containing all of the actual listings found in the search. 

    Requested URL              : https://www.kijiji.ca/b-toys-games/ottawa/monopoly/k0c108l1700185r60.0
    FirstListingResultIndex    : 1
    LastListingResultIndex     : 20
    TotalNumberOfSearchResults : 87
    Has More Pages             : Yes
    Listings                   : {Simpsons Monopoly, Monopoly Disney  Edition Bilingual Edition,....}
    
Note that there are more properties available for both the search object and the nested listing object. This is just what is shown by default as per [KijijiListings.format.ps1xml](https://github.com/NegativeZero000/KijijiListings/blob/master/KijijiListings.format.ps1xml)

Here a look at what the listing objects look like

    $searchListing.Listings | Select-Object -First 3

    ID         Title                          Price      Location        Posted         ShortDescription                                 
    --         -----                          -----      --------        ------         ----------------                                  
    1325722903 Board games                    $25.00     Ottawa          09/01/2018     Yahtzee Junior Pictionary Askin $25 for BOTH     
    1013648072 Toys/Games for Sale            $50.00     Ottawa          07/01/2018     Dozens of toys/games for sale: - Board games (Y...
    1129655081 Yahtzee Classic Board Bilin... $10.00     Ottawa          04/01/2018     Product Description Yahtzee Classic Board Bilin...

Again, there are more properties available then what is exposed in the default view. 

### Placeholder Search

You can use a placeholder search when you have a string with a prefered category and location. While not required in the least it can be useful for multiple searches in the scope. Same results can be garnered from using pre-formatted string and the Simple Search

    $kijijiSearchURL = "https://www.kijiji.ca/b-toys-games/ottawa/{0}/k0c108l1700185r60.0"
    $searchListing = Get-KijijiURLListings -PlaceholderUrl $kijijiSearchURL -SearchString yahtzee
    

### Gallery View

By default the module will also save the thumbnail image, in bytes, for each listing object. This is done so that we can output results to a gallery-like form. 

We are going to search for all Monopoly board games in the Ottawa area and display all of the images in a paged form.

    $kijijiSearchURL = "https://www.kijiji.ca/b-ottawa/monopoly/k0l1700185r60.0?dc=true"
    $searchListing = Get-KijijiURLListings -BaseUrl $kijijiSearchURL 
    # Create a collection to store the listing returned from each search
    $allListings = [System.Collections.ArrayList]::new($searchListing.Listings)

    # Keep getting more results as long as they are available or until we get more than 101
    while($searchListing.hasMorePages() -and $allListings.Count -lt 101){
        $searchListing = Get-KijijiURLListings -BaseUrl $searchListing.nextPageUrl
        $allListings.AddRange($searchListing.Listings)
    }

    # Show the listings in the gallery with custom Image and Grid sizes
    $allListings | Show-ImageGallery -Title $searchListing.RequestedURL -ImageSize "150,150" -GridSize "6,4"
    
A gallery view should then be displayed. See the following example:

![Sample Gallery View](https://user-images.githubusercontent.com/14927596/34894937-6f56f494-f7b1-11e7-929f-e22d7e6b6edf.jpg)


    




