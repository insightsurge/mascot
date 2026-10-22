Frozen copies of the character files of each released version. At each release add a folder named for that version
and copy the shipped example and built-in character files into it. Never edit a file in an existing folder.
Until the 0.1.0 release this folder is provisional and may be refreshed.

Version-1 character files keep loading until a breaking change introduces format version 2. Retiring an older format
version is announced in NEWS at least one release ahead. Every package version that supports a format version must load the files here
for that format unchanged. The checker may only become stricter in a new format version, except for a
documented security or resource-safety fix with a diagnostic and migration guidance. Added features use separate
capability names in `requires`. Files are never modified or upgraded silently.
