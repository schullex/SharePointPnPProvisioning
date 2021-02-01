$traceLogFile = Read-Host "Please enter full path to trace log file if you want to have a trace log to be created (optional) (WITHOUT QUOTES!)"
$provisioningTemplateFile = Read-Host "Please enter full path to the provisioning template file you want to apply to the new site (WITHOUT QUOTES!)"
$parentSiteURL = Read-Host "Please enter URL of parent site where a new sub site has to be created from the template"
$newSiteTitle = Read-Host "Please enter title for the new site to be created from the template"
$newSiteURL = Read-Host "Please enter site URL for the new site to be created from the template (folder name under parent site URL)"
$newSiteDescription = Read-Host "Please enter site description for the new site to be created from the template"
$newSiteLocale = Read-Host "Please enter locale for the new site to be created from the template (should be the same as the locale of the site the template was created from, e.g. 1031 for german)"

if ($traceLogFile -ne '') {
    Set-PnPTraceLog -On -LogFile $traceLogFile -Level Debug
}

Connect-PnPOnline -Url $parentSiteURL  -UseWebLogin

# If chosing -Locale parameter with a value <> 1033 you might get following error for the default "documents"-library: 
# "Apply-PnPProvisioningTemplate : A list, survey, discussion board, or document library with the specified title already exists in this Web site.  Please choose another title
$web = New-PnpWeb -Title $newSiteTitle -Url $newSiteURL -Description $newSiteDescription -Locale $newSiteLocale -Template "STS#0" 

Connect-PnPOnline -Url "$parentSiteURL/$newSiteURL"  -UseWebLogin
Remove-PnPList -Force -Identity Dokumente # for -identity use title of documents-library in language according to locale provided in -Locale parameter 

Apply-PnPProvisioningTemplate -Web $web -Path $provisioningTemplateFile

Write-Host "Site $parentSiteURL/$newSiteURL created succesfully."
Write-Host "Template $provisioningTemplateFile applied succesfully."
Write-Host @'
If navigation is incomplete after provisioning this can be resolved by clicking "Refresh"-button on Site Settings -> Navigation
'@

Set-PnPTraceLog -Off

Read-Host -Prompt "Press Enter to exit"