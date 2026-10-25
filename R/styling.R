#' Styling
#'
#' Style a mascot's panels and restore button with CSS. Use [mascot_theme()]
#' for the character's drawn colours.
#'
#' @section Public classes:
#' These classes are styling hooks: `.mascot` (the whole mascot),
#' `.mascot-status` (status text), `.mascot-bubble` (speech panel),
#' `.mascot-menu` (menu panel) and `.mascot-tooltip` (tooltip panel).
#' Other classes and all `--_mascot-*` properties are private and may change.
#' Use [mascot_size()] and [mascot_placement()] for size and position.
#'
#' @section Public custom properties:
#' Set these on `.mascot`, an individual mascot's id, or an ancestor such as
#' `:root`. A colour you set wins over the page colours mascot copies and over
#' Bootstrap variables, also in a `bslib` app. The package sets none of these
#' colour properties itself. When you set none, panels follow the page and the
#' restore button follows the character. When a mascot floats, it copies the
#' values it inherited from its original container; values set on the mascot
#' itself win.
#'
#' * `--mascot-panel-bg`: bubble, menu and tooltip backgrounds and tails.
#'   Default: page background; otherwise `#fff` in light mode, `#212529` in dark.
#' * `--mascot-panel-color`: panel text and minimise control.
#'   Default: page text; otherwise `#212529` in light mode, `#f8f9fa` in dark.
#' * `--mascot-panel-border`: panel and tail borders, bubble close border.
#'   Default: page border; otherwise `#dee2e6` in light mode, `#495057` in dark.
#' * `--mascot-restore-bg`: round restore button background.
#'   Default: character body colour, or its first colour if absent.
#' * `--mascot-restore-fg`: restore button text, border and focus outline.
#'   Default: character outline colour, or its first colour if absent.
#' * `--mascot-restore-glow`: restore button glow on hover or keyboard focus.
#'   Default: the character's accent colour (its secondary brand colour, or `rim`), then
#'   its main colour, then its first colour.
#' * `--mascot-z-index`: floating mascot's stacking order.
#'   Default: `1031`, above Bootstrap fixed navigation bars and below overlay
#'   panels and modals. A supplied value wins over this default.
#'
#' @section CSS example:
#' Add this CSS to your app or site's CSS file. The panel colour properties
#' style all three panel kinds; the restore properties style the restore button.
#' ```css
#' .mascot {
#'   --mascot-panel-bg: #153448;
#'   --mascot-panel-color: #ffffff;
#'   --mascot-panel-border: #8fc7e8;
#'   --mascot-restore-bg: #153448;
#'   --mascot-restore-fg: #ffffff;
#'   --mascot-restore-glow: #8fc7e8;
#'   --mascot-z-index: 1040;
#' }
#' ```
#' Choose readable colours for your page's light and dark modes. CSS hooks do
#' not change the character's drawn colours or check colour contrast.
#'
#' @name mascot_styling
#' @seealso [mascot_theme()], [mascot_size()], [mascot_placement()]
#' @examples
#' # In an app, the same CSS usually lives in a file under www/.
#' css <- "
#' .mascot {
#'   --mascot-panel-bg: #153448;
#'   --mascot-panel-color: #ffffff;
#'   --mascot-panel-border: #8fc7e8;
#'   --mascot-restore-bg: #153448;
#'   --mascot-restore-fg: #ffffff;
#' }"
#' ui <- htmltools::tagList(
#'   htmltools::tags$style(css),
#'   mascot("helper", bubble = "Hello!")
#' )
NULL
