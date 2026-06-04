# VHS tape to record the maze animation into demo.gif
#   vhs demo.tape
Output demo.gif

Set Shell zsh
Set FontSize 14
Set Padding 20
Set Width 900
Set Height 580
Set Framerate 20
Set CursorBlink false

Hide
Type "./zig-out/bin/mouse-maze"
Enter
Show
Sleep 19s
