# KijijiListings

This module scrapes provided Kijiji urls for listings and converts them into PowerShell objects. Also included is a clickable image gallery viewer for aforementioned listings. 

## Requirments

This requires PowerShell v3.0 to run. Mostly because of the use of `[pscustomobject]` type accelerator but there are some other features that require that version as well.

# Sample Usage

See [Setup and Usage](https://github.com/NegativeZero000/KijijiListings/blob/master/Setup%20and%20Usage.md) for _way_ more details

- Find all listing with "yahtzee" in them in the board game category listed in the Ottawa location.

        $kijijiSearchURL = "https://www.kijiji.ca/b-toys-games/ottawa/{0}/k0c108l1700185r60.0"
        
        $listing= Get-KijijiURLListings -PlaceholderUrl $kijijiSearchURL -SearchString yahtzee
        "Total listings: $($listing.TotalNumberOfSearchResults)"
        $listing.Listings

# Notes

The core of how this work is that URLs are downloaded as strings and multiple regex strings are used to parse the searches meta data, individuals listings and those listing details.

Parsing html regex is not ideal and can result in many ancillary issues. I was forced to do this because of an [issue with Invoke-WebRequest](https://connect.microsoft.com/PowerShell/feedbackdetail/view/1557783/invoke-webrequest-hangs-in-some-cases-unless-usebasicparsing-is-used). So far it seems to be working fine. 

When importing this module you will get a warning

    WARNING: The names of some imported commands from the module 'KijijiListings' include unapproved verbs that might make them less discoverable. To find the commands with unapproved verbs, run the Import-Module command again with the Verbose parameter. For a list of approved verbs, type Get-Verb.
    
This is expected because of the function `Collect-SearchResults`. I like that name and am not sure what else to call it. You can avoid that by setting warning preference but it is not a show stopper. 
