describe("character-format geometry and painting", {
  it("expands logical operands for all basic shapes, repeated refs and paths", {
    skip_without_chrome()
    js <- local_character_engine()
    numbers <- js(
      "[ {shape:'circle',r:2}, {shape:'ellipse',rx:2,ry:3}, {shape:'rect',w:2,h:3}, {shape:'round_rect',w:2,h:3,r:1}, {shape:'arc',r:2,start:0,end:1}, {shape:'polyline',points:[[0,0],[1,2],[2,0]],stroke:'ink'}, {shape:'polygon',sides:5,r:2}, {shape:'hexagon',r:2,corner:1}, {shape:'path',d:'M 1e1,-.5 2 3 L4 5 Q6 7 8 9 C0 1 2 3 4 5 Z'}].map(x=>mascot.geometry.compile(x).numbers)"
    )
    expect_equal(unlist(numbers), c(5, 7, 4, 8, 5, 6, 10, 36, 16))
    expect_identical(js("mascot.geometry.commands('M0 0 1 2 3 4').map(x=>x[0])"), list("M", "L", "L"))
    expect_equal(
      js(
        "mascot.geometry.compile({shape:'ref',use:'disc',x:10,scale:2},{disc:{shape:'circle',r:3,fill:'ink'}}).numbers"
      ),
      5
    )
  })

  it("rejects malformed paths and forbidden ref geometry before canvas painting", {
    skip_without_chrome()
    js <- local_character_engine()
    for (path in c("L0 0", "M", "M0 0 Q1 2 3", "M0 0 C1 2 L3 4", "M0 0 ?1 2", "M0 0 1e400 0", "M0 0 l1 1")) {
      text <- as.character(jsonlite::toJSON(path, auto_unbox = TRUE))
      expect_true(js(paste0(
        "(() => {try {mascot.geometry.commands(",
        text,
        ");return false;}catch(e){return !!e.code;}})()"
      )))
    }
    expect_identical(
      js(
        "(() => {try {mascot.geometry.compile({shape:'ref',use:'disc',r:9},{disc:{shape:'circle',r:2}});}catch(e){return e.code;}})()"
      ),
      "unknown_key"
    )
    expect_identical(
      js(
        "(() => {try {mascot.geometry.compile({shape:'polyline',points:[[0,0],[1,1]],fill:'ink'});}catch(e){return e.code;}})()"
      ),
      "input_type"
    )
    # Inherited names such as toString are not declared shapes or paints.
    expect_identical(
      js("(() => {try {mascot.geometry.compile({shape:'ref',use:'toString'},{});}catch(e){return e.code;}})()"),
      "missing_reference"
    )
    expect_identical(
      js(paste0(
        "(() => {const ctx=document.createElement('canvas').getContext('2d');",
        "try {mascot.geometry.paint(ctx,{paint:'constructor'},{paints:{}},{},'$.fill');}catch(e){return e.code;}})()"
      )),
      "missing_reference"
    )
  })

  it("clips against hidden active geometry in its own world coordinates", {
    skip_without_chrome()
    js <- local_character_engine()
    result <- js(
      "(() => {const canvas=document.createElement('canvas');canvas.width=300;canvas.height=300;const ctx=canvas.getContext('2d');const ch={format_version:1,ground:{centre_height:0},parts:[{id:'mask',at:[-20,-30],visible:false,items:[{id:'cut',shape:'rect',w:10,h:10}]},{id:'ink',at:[-30,-40],items:[{shape:'rect',w:40,h:40,fill:'ink',clip:'mask.cut'}]}]};const p=mascot.parts.compile(ch);const s=mascot.parts.frame(p);const counts=mascot.geometry.draw(ctx,p,s,{ink:'#ff0000'});return {counts,inside:[...ctx.getImageData(135,245,1,1).data],outside:[...ctx.getImageData(125,235,1,1).data],matrix:[ctx.getTransform().a,ctx.getTransform().e]};})()"
    )
    expect_equal(unlist(result$inside), c(255, 0, 0, 255))
    expect_equal(unlist(result$outside), rep(0, 4))
    expect_equal(result$counts$painted_items, 1)
    expect_equal(result$counts$clip_applications, 1)
    expect_equal(result$counts$path_numbers, 8)
    expect_equal(unlist(result$matrix), c(1, 0))
  })

  it("suppresses a source with a collapsed clip and rejects an absent active target", {
    skip_without_chrome()
    js <- local_character_engine()
    result <- js(
      "(() => {const ctx=document.createElement('canvas').getContext('2d');const ch={format_version:1,ground:{centre_height:0},parts:[{id:'mask',scale:0,items:[{id:'cut',shape:'rect',w:10,h:10}]},{id:'ink',items:[{shape:'circle',r:10,fill:'ink',clip:'mask.cut'}]}]};const p=mascot.parts.compile(ch);const count=mascot.geometry.draw(ctx,p,mascot.parts.frame(p),{ink:'#fff'});ch.parts[0].variants={empty:[]};ch.parts[0].scale=1;const q=mascot.parts.compile(ch);let error;try{mascot.geometry.draw(ctx,q,mascot.parts.frame(q,{'mask.variant':'empty'}),{ink:'#fff'});}catch(e){error=e.code;}return {count,error};})()"
    )
    expect_equal(result$count$painted_items, 0)
    expect_identical(result$error, "missing_reference")
  })

  it("counts each gradient and outline pass and multiplies ancestral opacity", {
    skip_without_chrome()
    js <- local_character_engine()
    result <- js(
      "(() => {const canvas=document.createElement('canvas');canvas.width=300;canvas.height=300;const ctx=canvas.getContext('2d');ctx.globalAlpha=.5;const ch={format_version:1,ground:{centre_height:0},outline:{width:2,colour:'ink',second:{width:4,colour:'ink'}},paints:{fade:{type:'linear',from:[0,0],to:[20,0],stops:[[0,'red'],[1,'red']]}},shapes:{block:{shape:'rect',w:20,h:20,fill:{paint:'fade'},outline:true}},parts:[{id:'parent',opacity:.5},{id:'child',parent:'parent',opacity:.5,at:[-30,-40],items:[{shape:'ref',use:'block',alpha:.5},{shape:'ref',use:'block',x:30}]}]};const p=mascot.parts.compile(ch);const counts=mascot.geometry.draw(ctx,p,mascot.parts.frame(p),{red:'#f00',ink:'#000'});return {counts,alpha:ctx.globalAlpha,pixel:[...ctx.getImageData(130,240,1,1).data]};})()"
    )
    expect_equal(result$counts$painted_items, 2)
    expect_equal(result$counts$paint_passes, 6)
    expect_equal(result$counts$path_numbers, 8)
    expect_equal(result$counts$gradient_uses, 2)
    expect_equal(result$alpha, .5)
    expect_equal(result$pixel[[4]], 16, tolerance = 1)
  })

  it("scales reusable-shape outlines with the geometry", {
    skip_without_chrome()
    js <- local_character_engine()
    alpha <- js(
      "(() => {const canvas=document.createElement('canvas');canvas.width=300;canvas.height=300;const ctx=canvas.getContext('2d');const ch={format_version:1,ground:{centre_height:0},outline:{width:2,colour:'ink'},shapes:{disc:{shape:'circle',r:10,outline:true}},parts:[{id:'disc',at:[0,-50],items:[{shape:'ref',use:'disc',scale:2}]}]};const p=mascot.parts.compile(ch);mascot.geometry.draw(ctx,p,mascot.parts.frame(p),{ink:'#000'});return ctx.getImageData(171,220,1,1).data[3];})()"
    )
    # Radius 10 and half-stroke 1 both double: this pixel lies inside radius 22.
    expect_gt(alpha, 100)
  })

  it("draws a radial paint offline with stop alpha and restores context on error", {
    skip_without_chrome()
    js <- local_character_engine()
    result <- js(
      "(() => {const c=document.createElement('canvas');c.width=300;c.height=300;const ctx=c.getContext('2d');const ch={format_version:1,ground:{centre_height:0},paints:{spot:{type:'radial',centre:[0,0],r1:20,stops:[[0,'red',.5],[1,'red',.5]]}},parts:[{id:'disc',at:[0,-30],items:[{shape:'circle',r:15,fill:{paint:'spot'}}]}]};const p=mascot.parts.compile(ch);const state=mascot.parts.frame(p);mascot.geometry.draw(ctx,p,state,{red:'rgba(255,0,0,0.5)'});let error;try {mascot.geometry.draw(ctx,p,state,{});}catch(e){error=e.code;}return {alpha:ctx.getImageData(150,240,1,1).data[3],error,transform:ctx.getTransform().e};})()"
    )
    expect_equal(result$alpha, 64, tolerance = 1)
    expect_identical(result$error, "invalid_colour")
    expect_equal(result$transform, 0)
  })
})
