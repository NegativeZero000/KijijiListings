# KijijiListings

This module scrapes provided Kijiji urls for listings and converts them into PowerShell objects. Also included is an image gallery viewer for aforementioned listings. 

# Sample Usage

See [SampleUsage](https://github.com/NegativeZero000/KijijiListings/blob/master/SampleUsage.ps1) for more details

- Find all listing with "yahtzee" in them in the board game category listed in the Ottawa location.

        $kijijiSearchURL = "https://www.kijiji.ca/b-toys-games/ottawa/{0}/k0c108l1700185r60.0"
        
        $listing= Get-KijijiURLListings -PlaceholderUrl $kijijiSearchURL -SearchString yahtzee
        "Total listings: $($listing.TotalNumberOfSearchResults)"
        $listing.Listings

# Notes

The core of how this work is that URLs are downloaded as strings and multiple regex strings are used to parse the searches meta data, individuals listings and those listing details.

Parsing html regex is not ideal and can result in many ancillary issue. I was forced to do this because of an [issue with Invoke-WebRequest](https://connect.microsoft.com/PowerShell/feedbackdetail/view/1557783/invoke-webrequest-hangs-in-some-cases-unless-usebasicparsing-is-used).

