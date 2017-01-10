#!/usr/bin/osascript
on run argv
tell application "System Events"
    set appWasRunning to exists (processes where name is "iTerm")

    tell application "iTerm"
        activate

        if not appWasRunning then
            terminate the first session of the first terminal
        end if

        set myterm to (make new terminal)

        tell myterm
            set dev_session to (make new session at the end of sessions)
            tell dev_session
                #exec command "ssh " & item 1 of argv & "@" & item 2 of argv
                exec command "ssh " & item 1 of argv 
            end tell

            select dev_session
        end tell
    end tell
end tell
end run
