on do_mail(theSubject, theContent)
    tell application "Mail"
        activate
        set theAddress to "support@realartists.com" -- the receiver
        
        set msg to make new outgoing message with properties {subject: theSubject, content: theContent, visible:true}
        
        tell msg to make new to recipient at end of every to recipient with properties {address:theAddress}
    end tell
end do_mail
