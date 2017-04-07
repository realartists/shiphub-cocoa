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
		set mytab to do script ""
		my waitfor(mytab)
        do script "source '" & scriptPath & "'"
		my waitfor(mytab)
	end tell
end do_clone
