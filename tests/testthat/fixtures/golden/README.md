Frozen copies of the character files and face kits of each released version. Never edit or delete a file in a
recorded folder: `checksums.txt` lists every file in those folders with its MD5 checksum, and
`test-character-check.R` fails when a listed file changes or goes, or an unlisted file appears in a listed folder.
The 0.1.0 folder stays provisional until CRAN accepts 0.1.0: if a change asked for in CRAN's review touches a file
in it, refresh the file and its line in `checksums.txt` in the release pull request.

## Adding a release folder

At each release:

1. Add a folder named for the version, such as `0.2.0/`.
2. Copy the shipped example and built-in character files into it (`inst/examples/characters/*.json` and
   `inst/format/characters/*.json`), and the shipped face kits into its `kits/` folder (`inst/format/kits/*.json`).
3. Append its lines to `checksums.txt`, one `<md5> <version>/<file>` line per file, with the folder's own lines
   sorted. The checksum is taken without carriage returns, so a Windows checkout gives the same result. From this
   folder:

   ```r
   files <- sort(list.files("0.2.0", recursive = TRUE, full.names = TRUE))
   md5 <- vapply(files, function(file) {
     bytes <- readBin(file, "raw", file.size(file))
     path <- tempfile()
     writeBin(bytes[bytes != as.raw(13L)], path)
     unname(tools::md5sum(path))
   }, character(1), USE.NAMES = FALSE)
   cat(paste(md5, files), file = "checksums.txt", sep = "\n", append = TRUE)
   ```

## Changing a shipped face kit

A source file that names a shipped kit (`"kit": "screen"`) draws with the kit as installed, so a change to a kit's
drawing changes how those files draw. `test-character-resolve.R` fails when a shipped kit differs from its newest
frozen copy here, or has none. To change a kit on purpose:

1. Put the changed kit in the folder for the next version, such as `0.2.0/kits/screen.json` (create the folder if
   needed; the rest of it is filled at the release).
2. Add a `NEWS.md` bullet saying what looks different and which files it affects.

A look that users should opt into ships under a new kit name instead. A new shipped kit also needs its frozen copy.

The format is experimental and its future direction is open; these points hold either way. Additions (new optional
keys, wider ranges, new categories) stay in format version 1, so existing files keep working. A file that uses an
addition lists it in `requires`, and an older version of mascot then stops with an error naming it instead of drawing
it wrongly. Only a change that would break existing files introduces format version 2; retiring an older format
version is announced in NEWS at least one release ahead. The checker may only get stricter in a new format version,
except for a documented security or resource-safety fix, which comes with a diagnostic and migration guidance. Files
are never modified or upgraded silently. Every package version that supports a format version must load the files
here for that format unchanged.
