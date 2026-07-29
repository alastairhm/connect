#!/usr/bin/osascript
on run argv
    tell application "iTerm2"
        activate
         tell current window
          set newTab to (create tab with profile "SSH")
         end tell
         tell current window
		tell newTab
			tell current session
                		write text "ssh " & item 1 of argv & ";exit"
			end tell
		end tell
         end tell
    end tell
end run
