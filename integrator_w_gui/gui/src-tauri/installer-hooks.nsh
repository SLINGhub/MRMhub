; Refreshes Windows shortcuts after an icon update. Keeping the icon in its own
; installed file avoids stale executable-icon cache entries during upgrades.
!macro NSIS_HOOK_POSTINSTALL
  WriteRegStr SHCTX "${UNINSTKEY}" "DisplayIcon" "$\"$INSTDIR\mrmhub.ico$\""

  IfFileExists "$SMPROGRAMS\${PRODUCTNAME}.lnk" 0 mrmhub_start_menu_done
    Delete "$SMPROGRAMS\${PRODUCTNAME}.lnk"
    CreateShortcut "$SMPROGRAMS\${PRODUCTNAME}.lnk" "$INSTDIR\${MAINBINARYNAME}.exe" "" "$INSTDIR\mrmhub.ico" 0
    !insertmacro SetLnkAppUserModelId "$SMPROGRAMS\${PRODUCTNAME}.lnk"
  mrmhub_start_menu_done:

  IfFileExists "$DESKTOP\${PRODUCTNAME}.lnk" 0 mrmhub_desktop_done
    Delete "$DESKTOP\${PRODUCTNAME}.lnk"
    CreateShortcut "$DESKTOP\${PRODUCTNAME}.lnk" "$INSTDIR\${MAINBINARYNAME}.exe" "" "$INSTDIR\mrmhub.ico" 0
    !insertmacro SetLnkAppUserModelId "$DESKTOP\${PRODUCTNAME}.lnk"
  mrmhub_desktop_done:

  ; Tell Explorer, Start, and the taskbar to discard cached icon associations.
  System::Call "shell32::SHChangeNotify(i 0x08000000, i 0x00001000, p 0, p 0)"
!macroend
