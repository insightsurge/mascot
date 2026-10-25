#!/usr/bin/env Rscript
# Remakes the logo's picture files from their SVG sources: Rscript tools/logo-assets.R
#
# Sources (edit these to change the logo): pkgdown/logo/logo.svg (the full hex) and pkgdown/logo/mark.svg (the small
# mark: the hex and the mascot only, for small sizes). Outputs: pkgdown/logo/logo.png, the favicons in
# pkgdown/favicon/ and the studio's copy of the mark. The repository's guard rails keep tools out of man/, so the
# script prints the command that copies logo.png to man/figures/ (README, help page, pkgdown) for you to run.
# PNGs are drawn by headless Chrome (set CHROME to its path if it is not found); nothing here runs when the package
# is installed or built.

chrome_path <- function() {
  path <- Sys.getenv("CHROME", "")
  if (!nzchar(path) && requireNamespace("chromote", quietly = TRUE)) {
    found <- chromote::find_chrome()
    if (is.character(found) && length(found) == 1 && !is.na(found)) {
      path <- found
    }
  }
  if (!nzchar(path) || !file.exists(path)) {
    cli::cli_abort("Chrome not found: set {.envvar CHROME} to its path.")
  }
  path
}

# Draws `svg` centred on a `width` x `height` PNG at `out`, the picture `img_w` x `img_h` pixels, on `background`.
render_png <- function(svg, out, width, height, img_w, img_h, background = "transparent") {
  checkmate::assert_file_exists(svg)
  checkmate::assert_path_for_output(out, overwrite = TRUE)
  checkmate::assert_count(width, positive = TRUE)
  checkmate::assert_count(height, positive = TRUE)
  checkmate::assert_number(img_w, lower = 1)
  checkmate::assert_number(img_h, lower = 1)
  checkmate::assert_string(background)
  page <- tempfile(fileext = ".html")
  on.exit(unlink(page), add = TRUE)
  writeLines(
    sprintf(
      paste0(
        '<html><body style="margin:0;background:transparent">',
        '<div style="position:absolute;left:0;top:0;width:%dpx;height:%dpx;background:%s"></div>',
        '<img src="file://%s" style="position:absolute;left:%.2fpx;top:%.2fpx;width:%.2fpx;height:%.2fpx">',
        "</body></html>"
      ),
      width,
      height,
      background,
      normalizePath(svg),
      (width - img_w) / 2,
      (height - img_h) / 2,
      img_w,
      img_h
    ),
    page
  )
  args <- c(
    "--headless=new",
    "--hide-scrollbars",
    "--default-background-color=00000000",
    sprintf("--window-size=%d,%d", width, height),
    paste0("--screenshot=", normalizePath(out, mustWork = FALSE)),
    paste0("file://", page)
  )
  status <- system2(chrome_path(), args, stdout = FALSE, stderr = FALSE)
  if (!identical(status, 0L) || !file.exists(out)) {
    cli::cli_abort("Chrome could not draw {.path {out}}.")
  }
  invisible(out)
}

# Writes an .ico file that holds the given square PNGs (an ICO entry may be a whole PNG).
write_ico <- function(pngs, sizes, out) {
  checkmate::assert_file_exists(pngs)
  checkmate::assert_integerish(sizes, lower = 1, upper = 256, len = length(pngs))
  checkmate::assert_path_for_output(out, overwrite = TRUE)
  data <- lapply(pngs, function(p) readBin(p, "raw", file.size(p)))
  con <- file(out, "wb")
  on.exit(close(con), add = TRUE)
  writeBin(as.integer(c(0, 1, length(pngs))), con, size = 2, endian = "little")
  offset <- 6 + 16 * length(pngs)
  for (i in seq_along(pngs)) {
    side <- as.raw(sizes[[i]] %% 256)
    writeBin(c(side, side, as.raw(0), as.raw(0)), con)
    writeBin(as.integer(c(1, 32)), con, size = 2, endian = "little")
    writeBin(as.integer(c(length(data[[i]]), offset)), con, size = 4, endian = "little")
    offset <- offset + length(data[[i]])
  }
  for (d in data) {
    writeBin(d, con)
  }
  invisible(out)
}

logo_assets <- function() {
  if (!file.exists("_pkgdown.yml")) {
    cli::cli_abort("Run from the package root (no {.path _pkgdown.yml} in {.path {getwd()}}).")
  }
  logo <- "pkgdown/logo/logo.svg"
  mark <- "pkgdown/logo/mark.svg"
  checkmate::assert_file_exists(c(logo, mark))
  ratio <- 100 / 116 # every hex here is 100 wide and 116 tall
  render_png(logo, "pkgdown/logo/logo.png", 240, 278, 240, 278)
  dir.create("pkgdown/favicon", showWarnings = FALSE)
  file.copy(mark, "pkgdown/favicon/favicon.svg", overwrite = TRUE)
  render_png(mark, "pkgdown/favicon/favicon-96x96.png", 96, 96, 96 * ratio, 96)
  for (side in c(180, 192, 512)) {
    out <- if (side == 180) {
      "pkgdown/favicon/apple-touch-icon.png"
    } else {
      sprintf("pkgdown/favicon/web-app-manifest-%dx%d.png", side, side)
    }
    render_png(mark, out, side, side, side * 0.86 * ratio, side * 0.86, background = "#101E22")
  }
  sizes <- c(16, 32, 48)
  icons <- file.path(tempdir(), sprintf("favicon-%d.png", sizes))
  on.exit(unlink(icons), add = TRUE)
  for (i in seq_along(sizes)) {
    render_png(mark, icons[[i]], sizes[[i]], sizes[[i]], sizes[[i]] * ratio, sizes[[i]])
  }
  write_ico(icons, sizes, "pkgdown/favicon/favicon.ico")
  file.copy(mark, "inst/examples/studio/www/mascot-mark.svg", overwrite = TRUE)
  cli::cli_inform(c(
    "v" = "Remade the logo PNG, the favicons and the studio's mark.",
    "i" = "Copy the logo for the README and help page: {.code cp pkgdown/logo/logo.png man/figures/logo.png}"
  ))
  invisible(TRUE)
}

logo_assets()
