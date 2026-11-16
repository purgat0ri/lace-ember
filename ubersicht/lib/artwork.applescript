-- Write the current Apple Music track's artwork to the path given.
-- Errors (non-zero exit) when the track has no artwork. Only called by
-- column.sh after nowplaying.js has seen Music playing, so it never launches Music.
on run argv
	set p to item 1 of argv
	tell application "Music"
		if (count of artworks of current track) is 0 then error "no artwork"
		set d to raw data of artwork 1 of current track
	end tell
	set f to open for access (POSIX file p) with write permission
	try
		set eof f to 0
		write d to f
	end try
	close access f
end run
