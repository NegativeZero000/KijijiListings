function Show-ImageGallery{
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
                    ValueFromPipeline=$true,
                   Position=0)]
        [Object]$GalleryObject,

        [Parameter(Mandatory=$true,
                   Position=1)]
        [string]$Title,

        # Param2 help description
        [Parameter(Mandatory=$false)]
        [Drawing.Size]$GridSize= "5,5",

        [Parameter(Mandatory=$false)]
        [Drawing.Size]$ImageSize="100,100",

        [Parameter(Mandatory=$false)]
        [ValidateScript({Test-Path -LiteralPath $_ -PathType Leaf})]
        $PlaceholderImagePath = "m:\scripts\noimage.png"
    )

    begin{
        # Prepare some form elements, function and event handlers
        function Load-PictureBoxArray{
            [cmdletbinding()]
            # Using script scope variable this function will use a generated form and "gallery" objects to populate
            # a pictureBox array on the form with images and details from the gallery object array. 
            # Depending on the defined image grid size only so many images will fit on the form at one time.
            # Use StartIndex to define which object we start to display from the "gallery"
            param([int]$StartIndex)

            # Get current page information
            Write-Verbose "Current Page: $($pageLabel.Tag.CurrentPage)"
            Write-Verbose "Last Page   : $($pageLabel.Tag.LastPage)"

            # Cycle each picture box and attempt to populate it with content.
            For($pictureBoxIndex = 0; $pictureBoxIndex -lt $maximumImagesPerGrid ;$pictureBoxIndex++){
                # Adjust the gallery index based on the current page
                $galleryIndex = ($pageLabel.Tag.CurrentPage - 1) * $maximumImagesPerGrid + $pictureBoxIndex
                Write-Verbose "Processing pictureBox at Index: '$pictureBoxIndex' with gallery at Index: '$galleryIndex'. Max Objects: $($galleryObjects.Count)"

                # Fill the picture box. With an image if possible. If not attempt the place holder image or a random color
                if($galleryIndex -ge $galleryObjects.Count){
                    # Clear any existing image and tips
                    $imageMatrix[$pictureBoxIndex].Image = $null
                    # Set a tool tip for the picture box
                    $formToolTip.SetToolTip($imageMatrix[$pictureBoxIndex], $null)

                    # Set the random colour. Force a lower opacity so the colurs are not the forms focus
                    $imageMatrix[$pictureBoxIndex].BackColor =  [System.Drawing.Color]::FromArgb((random 32),(random 256),(random 256),(random 256))
                } else {
                    if($galleryObjects[$galleryIndex].ImageBytes){
                        $imageMatrix[$pictureBoxIndex].Image = [System.Drawing.Image]::FromStream([IO.MemoryStream]::new($galleryObjects[$galleryIndex].ImageBytes))
                    } elseif ($placeholderImage){
                        $imageMatrix[$pictureBoxIndex].Image = $placeholderImage
                    }

                    # Set a tool tip for the picture box
                    $formToolTip.SetToolTip($imageMatrix[$pictureBoxIndex], $galleryObjects[$galleryIndex].Title)
               
     
                    # Add a click event to the kijiji posting. Add the URL into the Tag so its accessible within the event
                    $imageMatrix[$pictureBoxIndex].Tag = $galleryObjects[$galleryIndex].Action
                    $imageMatrix[$pictureBoxIndex].add_click({param($Sender)if($sender.Tag){Start-Process $sender.Tag}})
                }
            }
        }

        # Form based navigation button event handler
        $navigationScriptBlock = {
            param($sender,$e)

            # Check the tag of the calling object to determine which button was pushed.
            if($this.tag -eq "Forward"){
                # Forward button was pressed.
                $pageLabel.setCurrentPage($pageLabel.Tag.currentPage + 1)

                # Enable the back button if it has not been already
                if(-not $backButton.Enabled){$backButton.Enabled=$true}

                # Check if we are at the page limit. If so disable this button and enable the other
                if($pageLabel.Tag.CurrentPage -eq $pageLabel.Tag.LastPage){
                    $forwardButton.Enabled = $false
                    $backButton.Enabled = $true 
                }

            } else {
                # Back button was pressed.
                $pageLabel.setCurrentPage($pageLabel.Tag.currentPage - 1)

                # Enable the back button if it has not been already
                if(-not $forwardButton.Enabled){$forwardButton.Enabled=$true}

                if($pageLabel.Tag.CurrentPage -eq 1){
                    $forwardButton.Enabled = $true
                    $backButton.Enabled = $false 
                }
            }

            # Update the picture box array to represent the page change
            $newgalleryStartIndex = ($pageLabel.Tag.CurrentPage - 1) * $maximumImagesPerGrid + 1
            Write-Verbose "Picture box array populated starting at new gallery index: $newgalleryStartIndex"
            Load-PictureBoxArray -StartIndex $newgalleryStartIndex
        }

        # Load the image place holder image.
        if(Test-Path $placeholderImagePath -PathType Leaf){
            $placeholderImage = [system.drawing.image]::FromStream([IO.MemoryStream]::new([System.IO.File]::ReadAllBytes($placeholderImagePath)))
        } else {
            Write-Warning "Could not find: '$placeholderImagePath '. Will use random colours instead"
        }

        # Create some Size aliases for code readability
        Add-Member -InputObject $GridSize -MemberType AliasProperty -Name "Horizontal" -Value Width
        Add-Member -InputObject $GridSize -MemberType AliasProperty -Name "Vertical" -Value Height

        # Initialize gallery object array
        $mandatoryGalleryObjectProperties = "ImageBytes"
        $essentialGalleryObjectProperties = "Title","Action"
        $galleryObjects = [System.Collections.ArrayList]::new()

    }
    process {
        # Validate the current object in the pipeline has the required properties.
        $mandatoryGalleryObjectProperties | Where-Object{$GalleryObject.psobject.properties.name -notcontains $_} | ForEach-Object{
            Write-Error "Object missing '$_' property. Cannot be added to gallery."
        }

        $essentialGalleryObjectProperties | Where-Object{$GalleryObject.psobject.properties.name -notcontains $_} | ForEach-Object{
            Write-Warning "Object missing '$_' property. Picture will be missing properties when rendered."
        }

        # Build the object array that will populate the form
        [void]$galleryObjects.add($GalleryObject)
    }
    end {
        # Finish form generation and display
        # Detemine number of pages for the amout of groups defined. 
        $maximumImagesPerGrid = $GridSize.Horizontal * $GridSize.Vertical
        $maximumNumberofPages = [System.Math]::Ceiling($galleryObjects.Count / $maximumImagesPerGrid)

        Write-Verbose "Maximum Images per grid page: $maximumImagesPerGrid"
        Write-Verbose "Number of pages required: $maximumNumberofPages"
        Write-Verbose "Displaying $($galleryObjects.Count) images in $($GridSize.Horizontal)x$($GridSize.Vertical) grid"
        $formOverallSize = [Drawing.Size]::new(
            $imageSize.Width * $GridSize.Horizontal,
            $imageSize.Height * $GridSize.Vertical
        )

        # Create the form
        $galleryImageForm = New-Object System.Windows.Forms.Form
        $galleryImageForm.Size  = $formOverallSize
        $galleryImageForm.Text  = $Title
        $galleryImageForm.MaximizeBox = $false
        $galleryImageForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
        $galleryImageForm.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen

        # Tool tip manager. To be used to populate all form tool tips.
        $formToolTip = [System.Windows.Forms.ToolTip]::new()

        # Create a new status strip with simple buttons and status information
        $statusStrip = [System.Windows.Forms.StatusStrip]::new()
        $statusStrip.Name = "galleryStatusStrip"
        $statusStrip.SizingGrip = $false

        # Create the back status strip button
        $backButton = [System.Windows.Forms.ToolStripDropDownButton]::new()
        $backButton.DisplayStyle = [System.Windows.Forms.ToolStripItemDisplayStyle]::Text
        $backButton.Name = "BackStatusButton"
        $backButton.ShowDropDownArrow = $false
        $backButton.Size = [System.Drawing.Size]::new(21, 20)
        $backButton.Tag = "Backward"
        $backButton.Text = "◀";
        $backButton.TextDirection = [System.Windows.Forms.ToolStripTextDirection]::Horizontal
        $backButton.Enabled = $false # Can't go back from first page.
        $backButton.add_Click($navigationScriptBlock)
        [void]$statusStrip.Items.Add($backButton)

        # Create the forward status strip button
        $forwardButton = [System.Windows.Forms.ToolStripDropDownButton]::new()
        $forwardButton.DisplayStyle = [System.Windows.Forms.ToolStripItemDisplayStyle]::Text
        $forwardButton.Name = "ForwardStatusButton"
        $forwardButton.ShowDropDownArrow = $false
        $forwardButton.Size = [System.Drawing.Size]::new(21, 20)
        $forwardButton.Tag = "Forward"
        $forwardButton.Text = "▶";
        $forwardButton.TextDirection = [System.Windows.Forms.ToolStripTextDirection]::Horizontal
        $forwardButton.add_Click($navigationScriptBlock)
        [void]$statusStrip.Items.Add($forwardButton)

        # Create the page navigation status label
        $pageLabel = [System.Windows.Forms.ToolStripStatusLabel]::new()
        $pageLabel.Name = "pageNavigation"
        # Set the page information. Always start on the first page
        $pageLabel.Tag = @{CurrentPage=1;LastPage=$maximumNumberofPages}
        $NavigationInfoAddMemberProperties = @{
            InputObject = $pageLabel
            MemberType = "ScriptMethod"
            Name = "setCurrentPage"
            Value = {
                param([int]$newpage)
                $this.Tag.CurrentPage = $newpage
                $this.Text = "{0} of {1}" -f $this.Tag.CurrentPage, $this.Tag.LastPage
            }
        }
        Add-Member @NavigationInfoAddMemberProperties
        $pageLabel.setCurrentPage(1)


        # If we only have one page then disable forward button.
        if($pageLabel.Tag.LastPage -eq 1){$forwardButton.Enabled = $false} 

        [void]$statusStrip.Items.Add($pageLabel)
    
        # Add the status strip
        [void]$galleryImageForm.Controls.Add($statusStrip)

        # Adjust the size of the form to account for the title bar and the width of the form border. 
        Write-Verbose "ClientSize.Width     : $($galleryImageForm.ClientSize.Width)" 
        Write-Verbose "ClientSize.Height    : $($galleryImageForm.ClientSize.Height)" 
        # Logic for determining titlebar height and width from https://ivision.wordpress.com/2007/01/05/title-bar-height-and-form-border-width-of-net-form/
        # In practice it is not perfect but it is good enough for this.
        $formBorderWidth = ($galleryImageForm.Width - $galleryImageForm.ClientSize.Width) / 2
        $formTitleBarHeight = $galleryImageForm.Height – $galleryImageForm.ClientSize.Height – 2 * $formBorderWidth
        Write-Verbose "Form Border Width    : $formBorderWidth"
        Write-Verbose "Form TitleBar Height : $formTitleBarHeight"
        $galleryImageForm.Size = [Drawing.Size]::new(
            $galleryImageForm.Size.Width + $formBorderWidth,
            $galleryImageForm.Size.Height + $formTitleBarHeight + $formBorderWidth + $statusStrip.Size.Height
        )
        Write-Verbose "Adjusted Form Height : $($galleryImageForm.Size.Height)"
        Write-Verbose "Adjusted Form Width  : $($galleryImageForm.Size.Width)"

        # Set the left/X and top/Y of the image matrix controls
        $imageMatrixXOffset = 0
        $imageMatrixYOffset = 0

        # Create the picture box array. 
        $imageMatrix = 0..($GridSize.Vertical * $GridSize.Horizontal) | ForEach-Object{[System.Windows.Forms.PictureBox]::new()}

        # Create an image matrix from the images provided in a gallery group
        for ($verticalImageIndex = 0; $verticalImageIndex -lt $GridSize.Vertical; $verticalImageIndex++){ 
            for ($horizonalImageIndex = 0; $horizonalImageIndex -lt $GridSize.Horizontal; $horizonalImageIndex++){

                # Determine the integer index of the next image in the collection
                $galleryIndex = $verticalImageIndex * $GridSize.Horizontal + $horizonalImageIndex

                # Write-Host '$verticalImageIndex * $GridSize.Vertical + $horizonalImageIndex' -ForegroundColor Green
                # Write-Host "$verticalImageIndex * $($GridSize.Vertical) + $horizonalImageIndex" -ForegroundColor Green
                # Write-Host "Building pictureBox with gallery at Index: '$galleryIndex'" -ForegroundColor Green
     
                # Configure the image box associated to this index
                $imageMatrix[$galleryIndex].Size = $imageSize
                $imageMatrix[$galleryIndex].BorderStyle = [System.Windows.Forms.BorderStyle]::None
                $imageMatrix[$galleryIndex].SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
                $imageMatrix[$galleryIndex].Location = [System.Drawing.Point]::new(
                    $horizonalImageIndex * $imageSize.Width  + $imageMatrixXOffset, 
                    $verticalImageIndex  * $imageSize.Height + $imageMatrixYOffset 
                )

                # Download the image as a memory stream to bypass saving the file
                $galleryImageForm.Controls.Add($imageMatrix[$galleryIndex])
            }
        }

        # Populate as many images as able into the image matrix.
        Load-PictureBoxArray -StartIndex 0


        # Show the form
        $galleryImageForm.Add_Shown({$galleryImageForm.Activate()})
        # [void]$galleryImageForm.ShowDialog()
        [System.Windows.Forms.Application]::Run($galleryImageForm)
        Write-Verbose "End Form Height     : $($galleryImageForm.Size.Height)"
        Write-Verbose "End Form Width      : $($galleryImageForm.Size.Width)"
        Write-Verbose "Image Height        : $($imageSize.Height)"
        Write-Verbose "Image Width         : $($imageSize.Width)"

        # The form is closed. Clean up
        $galleryImageForm.Dispose()

    }
}