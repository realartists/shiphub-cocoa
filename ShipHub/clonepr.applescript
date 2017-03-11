on waitfor(mytab)
	using terms from application "Terminal"
		repeat while mytab is busy
			delay 0.1
		end repeat
	end using terms from
    delay 0.1 -- for good measure
end waitfor

on do_clone(issueIdentifier, repoName, repoPath, remoteURL, refName, branchName, baseRev, headRev)
	tell application "Terminal"
		activate
		set mytab to do script ""
		my waitfor(mytab)
		do script "cd /tmp && cd `mktemp -d '" & repoName & ".XXXXXX'`" & " && git clone -l -n -o file '" & repoPath & "' '" & repoName & "'" & " && cd '" & repoName & "'" & " && git remote add origin '" & remoteURL & "'" & " && git pull file " & refName & ":" & branchName & " && git checkout '" & branchName & "'" & " && git remote remove file && git branch -q -d master" & " && echo '*** Change Summary ***' && git diff --summary --stat " & baseRev & "..." & headRev in mytab
		my waitfor(mytab)
	end tell
end do_clone
