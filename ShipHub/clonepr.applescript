on waitfor(mytab)
	using terms from application "Terminal"
		repeat while mytab is busy
			delay 0.1
		end repeat
	end using terms from
    delay 0.1 -- for good measure
end waitfor

on do_clone(scriptPath)
	tell application "Terminal"
		activate
        do script "source '" & scriptPath & "'"
	end tell
end do_clone
