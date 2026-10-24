# The engine files, in load order: the shared helpers, the format-v1 modules (parts, geometry and faces), the motion
# tracks the host reads when it loads, the player that uses them all, then the host.
engine_scripts <- c(
  "mascot.js",
  "mascot-parts.js",
  "mascot-geometry.js",
  "mascot-faces.js",
  "mascot-motion.js",
  "mascot-player.js",
  "mascot-host.js"
)

# The file names a dependency's scripts load, in order.
script_files <- function(dep) {
  vapply(dep$script, function(script) script$src, character(1))
}
