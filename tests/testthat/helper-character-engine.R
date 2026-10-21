# Numeric tests use the packaged modules in a real browser, without the host.
local_character_engine <- function(env = parent.frame()) {
  checkmate::assert_environment(env)
  skip_without_chrome()
  dir <- withr::local_tempdir(.local_envir = env)
  scripts <- file.path(
    system.file("www", package = "mascot", mustWork = TRUE),
    c("mascot-parts.js", "mascot-geometry.js", "mascot-faces.js")
  )
  page <- file.path(dir, "parts.html")
  writeLines(
    c(
      '<!doctype html><html lang="en"><head><meta charset="utf-8"><title>parts</title></head><body>',
      unlist(lapply(c("classic", "screen"), function(id) {
        c(
          sprintf('<script type="application/json" data-mascot-kit="%s">', id),
          readLines(system.file("format", "kits", paste0(id, ".json"), package = "mascot")),
          "</script>"
        )
      })),
      sprintf('<script src="file://%s"></script>', normalizePath(scripts, winslash = "/")),
      '</body></html>'
    ),
    page
  )
  session <- local_chrome_session(env)
  loaded <- session$Page$loadEventFired(wait_ = FALSE)
  session$Page$navigate(paste0("file://", normalizePath(page, winslash = "/")), wait_ = FALSE)
  session$wait_for(loaded)
  function(js) {
    checkmate::assert_string(js)
    result <- session$Runtime$evaluate(js, returnByValue = TRUE)
    if (!is.null(result$exceptionDetails)) {
      cli::cli_abort("Browser numeric test failed: {result$exceptionDetails$text}")
    }
    result$result$value
  }
}


# Small complete face fixtures keep browser assertions independent of the host/adapter.
local_face_engine <- function(env = parent.frame()) {
  checkmate::assert_environment(env)
  js <- local_character_engine(env)
  js(
    r"(
    window.faceFixture=(kit='classic')=>({
      format_version:1, ground:{centre_height:100},
      parts:[{id:'body',at:[0,-100],items:[{shape:'rect',x:-80,y:-70,w:160,h:130,fill:'backdrop'}]}],
      anchors:{mark:{part:'body',at:[60,-30]}}, effects:{},
      colours:{feature:'#16201b',eye_white:'#f0f0f0',shine:'#ffffff',eyelid:'#3f8a66',outline:'#26312b',
        teeth:'#ffffff',tongue:'#a33a30',sweat:'#9dc3e6',sparkle:'#ffffff',sparkle_outline:'#d9b35c',
        blush:'#7fcba4',blush_strong:'#d9b35c',backdrop:'#3f8a66',iris:'#cc0033'},
      face:{part:'body',kit,kit_definition:mascot.faces.readKit(kit),eyes:{y:-12,spacing:30,lashes:true,iris:null},
        mouth:{y:24},blush:{x:36,y:18,rx:13,ry:7}}
    });
    window.paintFace=(source,controls={},options={})=>{
      const canvas=document.createElement('canvas');canvas.width=300;canvas.height=300;
      const ctx=canvas.getContext('2d'),parts=mascot.parts.compile(source),state=mascot.parts.frame(parts,{},options.band??'full');
      const compiled=mascot.faces.compile(source),counts=mascot.faces.draw(ctx,compiled,state,controls,source.colours,options);
      return {canvas,ctx,state,compiled,counts,pixel:(x,y)=>[...ctx.getImageData(x,y,1,1).data]};
    };
    true
  )"
  )
  js
}
