try {
  $pp = New-Object -ComObject PowerPoint.Application
  $pres = $pp.Presentations.Open('D:\Moved_From_C\Desktop\GlobalVillage-Portable-20261111\PPT\GlobalVillage_Group_Presentation.pptx')
  Write-Output 'FULL DECK OPENS OK'
  $pres.SaveAs('D:\Moved_From_C\Desktop\GlobalVillage-Portable-20261111\_build_reports\ppt_preview.pdf', 32)
  $pres.Close(); $pp.Quit()
  Write-Output 'PDF preview saved'
} catch {
  Write-Output ('FAIL: ' + $_.Exception.Message)
  try { $pp.Quit() } catch {}
}
