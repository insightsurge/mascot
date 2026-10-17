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

  it("converts design blur to backing pixels and computes inflated scratch bounds", {
    skip_without_chrome()
    js <- local_character_engine()
    res <- js(
      "(() => {
        const blur = mascot.geometry.backingBlur(8, 160, 2);
        const bounds = mascot.geometry.scratchBounds([10, 10, 20, 20], 8, [1, 0, 0, 1, 0, 0]);
        return { blur, bounds };
      })()"
    )
    expect_equal(res$blur, 8 * (160 / 300) * 2, tolerance = 1e-6)
    expect_equal(res$bounds$left, -15)
    expect_equal(res$bounds$top, -15)
    expect_equal(res$bounds$width, 60)
    expect_equal(res$bounds$height, 60)
  })

  it("renders emission-only geometry and counts single blurred pass with 8 metrics", {
    skip_without_chrome()
    js <- local_character_engine()
    result <- js(
      "(() => {
        const canvas = document.createElement('canvas');
        canvas.width = 300;
        canvas.height = 300;
        const ctx = canvas.getContext('2d');
        const ch = {
          format_version: 1,
          ground: { centre_height: 0 },
          parts: [{
            id: 'lamp',
            at: [0, -30],
            glow: { item: 'bulb', colour: 'glow', blur: 6, alpha: 1 },
            items: [{ id: 'bulb', shape: 'circle', r: 10 }]
          }]
        };
        const p = mascot.parts.compile(ch);
        const s = mascot.parts.frame(p);
        const counts = mascot.geometry.draw(ctx, p, s, { glow: '#00ffff' });
        return {
          counts,
          pixel: [...ctx.getImageData(150, 240, 1, 1).data]
        };
      })()"
    )
    expect_equal(result$counts$active_parts, 1)
    expect_equal(result$counts$painted_items, 1)
    expect_equal(result$counts$paint_passes, 1)
    expect_equal(result$counts$path_numbers, 5)
    expect_equal(result$counts$glow_emitters, 1)
    expect_equal(result$counts$blur_design_units, 6)
    expect_gt(result$pixel[[4]], 0)
  })

  it("suppresses part glow in micro band and under zero alpha", {
    skip_without_chrome()
    js <- local_character_engine()
    result <- js(
      "(() => {
        const ctx = document.createElement('canvas').getContext('2d');
        const ch = {
          format_version: 1,
          ground: { centre_height: 0 },
          parts: [{
            id: 'lamp',
            glow: { item: 'bulb', colour: 'glow', blur: 8, alpha: 0 },
            items: [{ id: 'bulb', shape: 'circle', r: 10, fill: 'glow' }]
          }]
        };
        const p = mascot.parts.compile(ch);
        const sFull = mascot.parts.frame(p, {}, 'full');
        const countsZeroAlpha = mascot.geometry.draw(ctx, p, sFull, { glow: '#ff0000' });
        ch.parts[0].glow.alpha = 1;
        const p2 = mascot.parts.compile(ch);
        const sMicro = mascot.parts.frame(p2, {}, 'micro');
        const countsMicro = mascot.geometry.draw(ctx, p2, sMicro, { glow: '#ff0000' });
        return { countsZeroAlpha, countsMicro };
      })()"
    )
    expect_equal(result$countsZeroAlpha$glow_emitters, 0)
    expect_equal(result$countsZeroAlpha$blur_design_units, 0)
    expect_equal(result$countsMicro$glow_emitters, 0)
    expect_equal(result$countsMicro$blur_design_units, 0)
  })

  it("multiplies host ctx.globalAlpha into glow composite alpha", {
    skip_without_chrome()
    js <- local_character_engine()
    result <- js(
      "(() => {
        const render = (alpha) => {
          const canvas = document.createElement('canvas');
          canvas.width = 300;
          canvas.height = 300;
          const ctx = canvas.getContext('2d');
          ctx.globalAlpha = alpha;
          const ch = {
            format_version: 1,
            ground: { centre_height: 0 },
            parts: [{
              id: 'lamp',
              at: [0, -30],
              glow: { item: 'bulb', colour: 'glow', blur: 6, alpha: 1 },
              items: [{ id: 'bulb', shape: 'circle', r: 10 }]
            }]
          };
          const p = mascot.parts.compile(ch);
          const s = mascot.parts.frame(p);
          mascot.geometry.draw(ctx, p, s, { glow: '#00ffff' });
          return [...ctx.getImageData(150, 240, 1, 1).data];
        };
        return {
          full: render(1.0),
          half: render(0.5)
        };
      })()"
    )
    expect_gt(result$full[[4]], 0)
    expect_equal(result$half[[4]], round(result$full[[4]] * 0.5), tolerance = 1)
  })

  it("combines accounting across draw calls with blur maximum and active-parts set union", {
    skip_without_chrome()
    js <- local_character_engine()
    result <- js(
      "(() => {
        const first = {
          active_parts: 1,
          active_part_ids: ['part_a'],
          painted_items: 2,
          paint_passes: 2,
          path_numbers: 10,
          clip_applications: 0,
          gradient_uses: 0,
          glow_emitters: 1,
          blur_design_units: 4
        };
        const second = {
          active_parts: 2,
          active_part_ids: ['part_a', 'part_b'],
          painted_items: 1,
          paint_passes: 1,
          path_numbers: 5,
          clip_applications: 1,
          gradient_uses: 1,
          glow_emitters: 1,
          blur_design_units: 6
        };
        const combined = mascot.geometry.combineCounts(first, second);
        return combined;
      })()"
    )
    expect_equal(result$blur_design_units, 6)
    expect_equal(result$active_parts, 2)
    expect_equal(result$painted_items, 3)
    expect_equal(result$paint_passes, 3)
    expect_equal(result$path_numbers, 15)
    expect_equal(result$clip_applications, 1)
    expect_equal(result$gradient_uses, 1)
    expect_equal(result$glow_emitters, 2)
  })

  it("reuses prepared part lookup without mutating compiled data during draw", {
    skip_without_chrome()
    js <- local_character_engine()
    result <- js(
      "(() => {
        const ctx = document.createElement('canvas').getContext('2d');
        const ch = {
          format_version: 1,
          ground: { centre_height: 0 },
          parts: [{
            id: 'lamp',
            glow: { item: 'bulb', colour: 'glow', blur: 6, alpha: 1 },
            items: [{ id: 'bulb', shape: 'circle', r: 10 }]
          }]
        };
        const p = mascot.parts.compile(ch);
        const compiledBefore = JSON.stringify(p);
        const s = mascot.parts.frame(p);
        mascot.geometry.draw(ctx, p, s, { glow: '#00ffff' });
        const compiledAfterFirst = JSON.stringify(p);
        mascot.geometry.draw(ctx, p, s, { glow: '#00ffff' });
        const compiledAfterSecond = JSON.stringify(p);
        return {
          mutated: compiledBefore !== compiledAfterFirst || compiledAfterFirst !== compiledAfterSecond
        };
      })()"
    )
    expect_false(result$mutated)
  })

  it("renders emitter with both fill and stroke counting separate glow passes in JS", {
    skip_without_chrome()
    js <- local_character_engine()
    result <- js(
      "(() => {
        const canvas = document.createElement('canvas');
        canvas.width = 300;
        canvas.height = 300;
        const ctx = canvas.getContext('2d');
        const ch = {
          format_version: 1,
          ground: { centre_height: 0 },
          parts: [{
            id: 'lamp',
            at: [0, -30],
            glow: { item: 'bulb', colour: 'glow', blur: 6, alpha: 1 },
            items: [{ id: 'bulb', shape: 'circle', r: 10, fill: 'glow', stroke: 'glow', width: 2 }]
          }]
        };
        const p = mascot.parts.compile(ch);
        const s = mascot.parts.frame(p);
        const counts = mascot.geometry.draw(ctx, p, s, { glow: '#00ffff' });
        return {
          counts,
          pixel: [...ctx.getImageData(150, 240, 1, 1).data]
        };
      })()"
    )
    expect_equal(result$counts$active_parts, 1)
    expect_equal(result$counts$painted_items, 1)
    expect_equal(result$counts$paint_passes, 4)
    expect_equal(result$counts$path_numbers, 5)
    expect_equal(result$counts$glow_emitters, 1)
    expect_equal(result$counts$blur_design_units, 6)
    expect_gt(result$pixel[[4]], 0)
  })

  it("keeps glow rendering independent of prior pass surface size", {
    skip_without_chrome()
    js <- local_character_engine()
    result <- js(
      "(() => {
        const source = {
          format_version: 1, ground: { centre_height: 100 },
          parts: [{ id: 'body', at: [0, -100], items: [{ shape: 'rect', x: -80, y: -70, w: 160, h: 130, fill: 'backdrop' }] }],
          anchors: { mark: { part: 'body', at: [60, -30] } }, effects: {},
          colours: { feature: '#16201b', eye_white: '#f0f0f0', shine: '#ffffff', eyelid: '#3f8a66', outline: '#26312b',
            teeth: '#ffffff', tongue: '#a33a30', sweat: '#9dc3e6', sparkle: '#ffffff', sparkle_outline: '#d9b35c',
            blush: '#7fcba4', blush_strong: '#d9b35c', backdrop: '#3f8a66', iris: '#cc0033' },
          face: { part: 'body', kit: 'screen', kit_definition: mascot.faces.readKit('screen'),
            eyes: { y: -12, spacing: 30, lashes: true, iris: null },
            mouth: { y: 24 }, blush: { x: 36, y: 18, rx: 13, ry: 7 } }
        };
        const paint = () => {
          const canvas = document.createElement('canvas'); canvas.width = 300; canvas.height = 300;
          const ctx = canvas.getContext('2d'), parts = mascot.parts.compile(source), state = mascot.parts.frame(parts, {}, 'full');
          const compiled = mascot.faces.compile(source);
          mascot.faces.draw(ctx, compiled, state, {}, source.colours, {});
          return canvas;
        };
        mascot.geometry.resetScratch();
        const first = paint();
        const second = paint();
        return {
          same: first.toDataURL() === second.toDataURL()
        };
      })()"
    )
    expect_true(result$same)
  })
})

describe("E5b per-band work bound and policy caps", {
  it("keeps the browser's band caps equal to the shared policy for every metric it counts", {
    skip_without_chrome()
    js <- local_character_engine()
    caps <- js("mascot.geometry.bandCaps")
    policy <- character_format_policy()$bands
    for (band in c("full", "small", "micro")) {
      for (metric in names(caps[[band]])) {
        expect_equal(unname(unlist(caps[[band]][[metric]])), policy[[band]][[metric]], info = paste(band, metric))
      }
    }
  })

  it("counts the largest candidate variant of each part, respects band variants, hides and glow", {
    skip_without_chrome()
    js <- local_character_engine()
    result <- js(paste0(
      "(() => {const source={format_version:1,ground:{centre_height:100},",
      "parts:[{id:'body',items:[{id:'a',shape:'circle',r:4,fill:'ink'}],",
      "variants:{big:[{id:'b1',shape:'circle',r:4,fill:'ink'},{id:'b2',shape:'circle',r:4,fill:'ink'},",
      "{id:'b3',shape:'circle',r:4,fill:'ink'}]}},",
      "{id:'lamp',items:[{id:'bulb',shape:'circle',r:3,fill:'ink'}],",
      "glow:{item:'bulb',colour:'ink',blur:6,alpha:1}}],",
      "colours:{ink:'#000'},lod:{micro:{hide:['lamp.bulb']},small:{variants:{body:'big'}}}};",
      "const compiled=mascot.parts.compile(source);",
      "const bound=band=>mascot.geometry.bandBound(compiled,band);",
      "return {full:bound('full'),small:bound('small'),micro:bound('micro')};})()"
    ))
    # Full: the default body item (1) or the largest variant (3), plus the lamp: fill, glow fill, 1 item each.
    expect_equal(result$full$painted_items, 3 + 1)
    expect_equal(result$full$glow_emitters, 1)
    expect_equal(result$full$blur_design_units, 6)
    # Small: the band variant is the only candidate for body.
    expect_equal(result$small$painted_items, 3 + 1)
    # Micro: the lamp is hidden and micro has no glow; the body keeps its largest candidate.
    expect_equal(result$micro$glow_emitters, 0)
    expect_equal(result$micro$painted_items, 3)
  })

  it("refuses an over-budget band with budget at path $ before anything is painted", {
    skip_without_chrome()
    js <- local_character_engine()
    items <- paste(
      vapply(seq_len(31), function(i) sprintf("{id:'d%d',shape:'circle',r:2,fill:'ink'}", i), character(1)),
      collapse = ","
    )
    result <- js(sprintf(
      paste0(
        "(() => {const source={format_version:1,ground:{centre_height:100},",
        "parts:[{id:'body',items:[%s]}],colours:{ink:'#000'}};",
        "const compiled=mascot.parts.compile(source);",
        "const canvas=document.createElement('canvas');canvas.width=300;canvas.height=300;",
        "const ctx=canvas.getContext('2d');ctx.fillStyle='#fff';ctx.fillRect(0,0,300,300);",
        "const before=[...ctx.getImageData(0,0,300,300).data].join(',');",
        "let error=null;try{mascot.geometry.checkBudget(compiled,'micro');}catch(e){error=[e.code,e.path];}",
        "const after=[...ctx.getImageData(0,0,300,300).data].join(',');",
        "return {error,unchanged:before===after,full:mascot.geometry.checkBudget(compiled,'full').painted_items};})()"
      ),
      items
    ))
    expect_identical(unlist(result$error), c("budget", "$"))
    expect_true(result$unchanged)
    expect_equal(result$full, 31)
  })
})
