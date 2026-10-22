# Bookmark and restore

URL bookmarking (`enableBookmarking = "url"`) with a note input. The app changes the mascot, bookmarks, and the
page is reloaded from the bookmark URL. `onRestore()` sets the mascot from the restored note.
The buttons are excluded from the bookmark, as in most apps; a restored click count would replay their observers.

Tries to break:

- The mascot's private input leaking into the bookmark URL, and an update sent from `onRestore()` before the
  mascot has appeared in the new session.

Should hold:

- The URL has the note and no mascot input; the restored page shows "Restored <note>", not the pre-bookmark state.

From the checkout root, run `Rscript tools/stress/run-stress.R 09` with the
R environment described in the parent README.

Reproduction sequence:

1. Type "stress" in Note, click Update (worried, "Changed 1"), then click Bookmark.
2. Reload the page with the bookmark URL: the mascot is happy with "Restored stress" and the note is "stress".
