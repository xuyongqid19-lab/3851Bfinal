$ErrorActionPreference = 'Stop'
try {
  $pp = New-Object -ComObject PowerPoint.Application
  $pres = $pp.Presentations.Open('D:\Moved_From_C\Desktop\GlobalVillage-Portable-20261111\PPT\GlobalVillage_Group_Presentation.pptx')
  $pres.SaveAs('D:\Moved_From_C\Desktop\GlobalVillage-Portable-20261111\_build_reports\ppt_preview.pdf', 32)
  $pres.Close()
  $pp.Quit()
  Write-Output 'PPT PDF saved'
} catch {
  Write-Output ("PPT ERROR: " + $_.Exception.Message)
}
try {
  $word = New-Object -ComObject Word.Application
  $word.Visible = $false
  $doc = $word.Documents.Open('D:\Moved_From_C\Desktop\GlobalVillage-Portable-20261111\final report\GlobalVillage_Final_Report_Group.docx', $false, $true)
  $doc.SaveAs([ref]'D:\Moved_From_C\Desktop\GlobalVillage-Portable-20261111\final report\GlobalVillage_Final_Report_Group.pdf', [ref]17)
  $doc.Close($false)
  $word.Quit()
  Write-Output 'Report PDF saved'
} catch {
  Write-Output ("WORD ERROR: " + $_.Exception.Message)
}
