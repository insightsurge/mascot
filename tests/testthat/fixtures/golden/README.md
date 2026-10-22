Frozen copies of the character files of each released version. At each release add a folder named for that version
and copy the shipped example and built-in character files into it. Never edit a file in an existing folder.
Until the 0.1.0 release this folder is provisional and may be refreshed.

The format is experimental and its future direction is open; these points hold either way. Additions (new optional
keys, wider ranges, new categories) stay in format version 1, so existing files keep working. A file that uses an
addition lists it in `requires`, and an older version of mascot then stops with an error naming it instead of drawing
it wrongly. Only a change that would break existing files introduces format version 2; retiring an older format
version is announced in NEWS at least one release ahead. The checker may only get stricter in a new format version,
except for a documented security or resource-safety fix, which comes with a diagnostic and migration guidance. Files
are never modified or upgraded silently. Every package version that supports a format version must load the files
here for that format unchanged.
