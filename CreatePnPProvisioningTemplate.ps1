# 30.7.2020, Stefan: based on https://sharepoint.handsontek.net/2018/02/04/create-a-modern-sharepoint-site-template-with-multiple-pages-using-the-pnp-provisioning-engine/
# modifications:
# - Process classic experience pages instead of modern clientside pages. Clientside pages now exported with -IncludeAllClientSidePages option of Get-PnPProvisioningTemplate
# - Reset navigation on target site before applying navigation from this template
# - Remove already existing views on target site before creating the new ones deployed with this template
# - Handle calculated columns bug (only with non english sites): formulas have to reference displayname, not column title

pushd (Split-Path -Path $MyInvocation.MyCommand.Definition -Parent)

$saveDir = (Resolve-path ".\")
$siteURL = Read-Host "Please enter URL of site to generate the template from"
$saveFile = Read-Host @'
Please enter file name for template without extension. ".xml" will be appended
'@

$saveFile += ".xml"
Write-Host "Creating template $($saveDir.Path)\$saveFile"

Write-Host "Connecting to: $siteURL"

# Connect to site
# -UseWebLogin necessary for 2FA
Connect-PnPOnline -Url $siteURL -UseWebLogin 
Write-Host "Connected!"
 
$web = Get-PnPWeb
$sourceSite = $web.ServerRelativeUrl
 
# get all pages in the site pages library
$library = "SitePages"
$pages = Get-PnPListItem -List $library
 
# save current homepage
$currentHomePage = Get-PnPHomePage
 
$pagesList = New-Object System.Collections.Generic.List[System.Object]
 
$pageCount = 1
 
foreach($page in $pages){
	Write-Host ("Processing page " + $page.FieldValues["FileRef"] + " with ContentTypeId " + $page.FieldValues["ContentTypeId"])
    # process only file-objects with ContentTypeId <> "0x0101009D1CB255DA76424F860D91F20E6C4118". This is the content type for modern pages and these are covered by the -IncludeAllClientSidePages option of Get-PnPProvisioningTemplate
	if($page.FileSystemObjectType -eq "File" -and $page.FieldValues["ContentTypeId"].ToString().SubString(0,40) -ne "0x0101009D1CB255DA76424F860D91F20E6C4118") {
		$pagePath = $page.FieldValues["FileRef"]
	    $pageFile = $pagePath -replace $sourceSite, ""
		$pageTemplate = $pageFile -replace "/$library/","" -replace ".aspx",".xml"
	    $pagesList.Add($($pageTemplate -replace "./TemplateWithPages",""))	
		
		# set current page as home page because this will be exported with Get-PnPProvisioningTemplate
		Set-PnPHomePage -RootFolderRelativeUrl ($pagePath -replace ($sourceSite+"/"), "")
		
		Write-Host ("Saving page #" + $pageCount + " - " + $pageTemplate)
		
		if($pageCount -eq 1){
            # Generate provisioning site template for complete web in first iteration. -IncludeAllClientSidePages includes modern Site Pages in the template but NOT classic experience (web part) pages
			Get-PnPProvisioningTemplate -Out $($saveDir.Path + "\tmp\" + $pageTemplate) -IncludeAllClientSidePages -PersistBrandingFiles -Force
		}else{
            # only process page artifacts in subsequent iterations
			Get-PnPProvisioningTemplate -Out $($saveDir.Path + "\tmp\" + $pageTemplate) -Handlers PageContents -Force
		}
		
		$pageCount++
	}
}
 
$pagesList.ToArray()
 
# apply default homepage
Set-PnPHomePage -RootFolderRelativeUrl $currentHomePage
 
# copy base template 
Copy-item -path ($saveDir.Path + "\tmp\" + $pagesList[0]) -destination ($saveDir.Path + "\" + $saveFile)
 
# open main xml
$mainFile = [xml][io.File]::ReadAllText($($saveDir.Path + "\" + $saveFile))
$pages = $mainFile.Provisioning.Templates.ProvisioningTemplate.Pages
 
# remove page elements to avoid duplicates 
$pages.RemoveChild($mainFile.Provisioning.Templates.ProvisioningTemplate.Pages.Page)

# add page elements from per page provisioning templates
foreach($page in $pagesList){
	# open provisioning template for page
	$xmlContents = [xml][io.File]::ReadAllText($saveDir.Path + "\tmp\" + $page)
    foreach($node in $xmlContents.Provisioning.Templates.ProvisioningTemplate.Pages.Page)
	{
		# copy nodes from page xml
        $importNode = $pages.OwnerDocument.ImportNode($node, $true);
        Write-Host ("Append node " + $node.Url + "to <pnp:Pages>");
        $pages.AppendChild($importNode) | Out-Null
	}
}

# reset navigation on target site before applying navigation from this template
$globalNavigation = $mainFile.Provisioning.Templates.ProvisioningTemplate.Navigation.GlobalNavigation.StructuralNavigation
$currentNavigation = $mainFile.Provisioning.Templates.ProvisioningTemplate.Navigation.CurrentNavigation.StructuralNavigation

$globalNavigation.SetAttribute("RemoveExistingNodes", "true")
$currentNavigation.SetAttribute("RemoveExistingNodes", "true")

# set atribute "RemoveExistingViews" to "true" - already existing views on target site will be removed before creating the new ones deployed with this template
$nsmgr = New-Object System.Xml.XmlNamespaceManager $mainFile.NameTable
$nsmgr.AddNamespace('pnp','http://schemas.dev.office.com/PnP/2020/02/ProvisioningSchema')
$nodes = $mainFile.SelectNodes("//pnp:Views", $nsmgr)
foreach($node in $nodes) {
  $attrib = $node.OwnerDocument.CreateAttribute("RemoveExistingViews")
  $attrib.Value = "true"
  $node.Attributes.Append($attrib)
}

# calculated columns bug (only with non english sites): formula has to reference displayname, not column title
# has to be hardcoded for each calculated column
$calculatedColumn = $mainFile.SelectNodes('//Formula[text()="=Probability*Impact"]')
$calculatedColumn[0].InnerText = '=Wahrscheinlichkeit*Einfluss'

# save final tempate
$mainFile.Save($($saveDir.Path + "\" + $saveFile))
Write-Host "Created template $($saveDir.Path)\$saveFile"

Read-Host -Prompt "Press Enter to exit"
 
popd