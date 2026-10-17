describe("character-format part transforms", {
  it("filters inherited orientation without moving the world pivot", {
    skip_without_chrome()
    js <- local_character_engine()
    expect_equal(
      unlist(js("mascot.parts.child([0,1,-1,0,0,0], {id:'tool',at:[10,0],keep_upright:true})")),
      c(1, 0, 0, 1, 0, 10)
    )
    expect_equal(
      unlist(js("mascot.parts.child([-1,0,0,1,0,0], {id:'tool',at:[10,0],no_flip:true})")),
      c(1, 0, 0, 1, -10, 0)
    )
    expect_equal(
      unlist(js("mascot.parts.child([0,2,-3,0,0,0], {id:'tool',at:[10,0],keep_upright:true})")),
      c(2, 0, 0, 3, 0, 20)
    )
    # Reflection plus shear: QR removes rotation/shear, keeps positive stretches.
    expect_equal(
      unlist(js("mascot.parts.child([-2,0,4,3,7,9], {id:'tool',at:[10,2],keep_upright:true})")),
      c(-2, 0, 0, 3, -5, 15)
    )
    expect_equal(
      unlist(js("mascot.parts.child([-2,0,4,3,7,9], {id:'tool',at:[10,2],keep_upright:true,no_flip:true})")),
      c(2, 0, 0, 3, -5, 15)
    )
  })

  it("uses absolute resting channels and preserves authored local rotation", {
    skip_without_chrome()
    js <- local_character_engine()
    expect_equal(
      unlist(js("mascot.parts.child([0,1,-1,0,0,0], {id:'tool',keep_upright:true,rotate:Math.PI/2,scale:[2,3]})")),
      c(0, 2, -3, 0, 0, 0),
      tolerance = 1e-12
    )
    expect_equal(
      unlist(js("mascot.parts.child([1,0,0,1,0,0], {id:'tool',rotate:1,scale:2}, {'tool.rotate':0,'tool.scale_x':3})")),
      c(3, 0, 0, 2, 0, 0)
    )
    # Ground squash happens before the centre-height pivot rotation.
    expect_equal(
      unlist(js(
        "mascot.parts.point(mascot.parts.root(60, {'root.rotate':Math.PI/2,'root.scale_x':2,'root.lift':5}),[0,-60])"
      )),
      c(150, 205)
    )
    expect_equal(unlist(js("mascot.parts.point(mascot.parts.root(60, {'root.rotate':Math.PI/2}),[0,0])")), c(90, 210))
  })

  it("does not resurrect descendants of singular ancestors", {
    skip_without_chrome()
    js <- local_character_engine()
    expect_equal(
      unlist(js("mascot.parts.child([0,0,0,1,5,7],{id:'tool',at:[10,20],keep_upright:true,no_flip:true})")),
      c(0, 0, 0, 0, 5, 27)
    )
    expect_equal(unlist(js("mascot.parts.child([1e-13,0,0,1,0,0],{id:'tool',keep_upright:true})"))[1:4], rep(0, 4))
  })

  it("moves variant anchors and suppresses attachments of hidden or excluded owners", {
    skip_without_chrome()
    js <- local_character_engine()
    recipe <- jsonlite::fromJSON(test_path("fixtures", "format", "anchor_probe.json"), simplifyVector = FALSE)
    payload <- as.character(jsonlite::toJSON(recipe, auto_unbox = TRUE, null = "null"))
    js(paste0("window.probe=mascot.parts.compile(", payload, ")"))
    state <- js("mascot.parts.frame(probe)")
    expect_equal(unlist(state$anchors$badge$matrix)[5:6], c(168, 198))
    expect_equal(unlist(state$parts$wear__badge__disc$matrix)[5:6], c(168, 198))
    expect_true(state$parts$wear__badge__disc$available)
    state <- js("mascot.parts.frame(probe, {'panel.variant':'raised'})")
    expect_equal(unlist(state$anchors$badge$matrix)[5:6], c(170, 200))
    state <- js("mascot.parts.frame(probe, {'panel.visible':false})")
    expect_false(state$anchors$badge$available)
    expect_false(state$parts$wear__badge__disc$available)
    expect_equal(unlist(state$anchors$badge$matrix)[5:6], c(168, 198))
    state <- js("mascot.parts.frame(probe, {}, 'micro')")
    expect_false(state$parts$wear__badge__disc$available)
    state <- js("mascot.parts.frame(probe, {'root.scale_x':0})")
    expect_false(state$anchors$badge$available)
    expect_false(state$parts$wear__badge__disc$available)
  })

  it("reads data-named keys as own properties, so a part may be called constructor", {
    skip_without_chrome()
    js <- local_character_engine()
    # A valid id that is also an Object.prototype name, with an LOD variant map in the band.
    text <- gsub(
      '"panel',
      '"constructor',
      readLines(test_path("fixtures", "format", "anchor_probe.json")),
      fixed = TRUE
    )
    recipe <- jsonlite::fromJSON(paste(text, collapse = "\n"), simplifyVector = FALSE)
    recipe$lod$small <- list(variants = character_object())
    checked <- character_format_check(recipe)
    payload <- as.character(jsonlite::toJSON(unclass(checked), auto_unbox = TRUE, null = "null", digits = NA))
    js(paste0("window.proto=mascot.parts.compile(", payload, ")"))
    for (band in c("full", "small", "micro")) {
      state <- js(paste0("mascot.parts.frame(proto, {}, '", band, "')"))
      expect_identical(state$parts$constructor$variant, "default", info = band)
    }
    expect_identical(js("mascot.parts.own({}, 'toString')"), NULL)
  })

  it("keeps parenting separate from stable paint order and freezes a private copy", {
    skip_without_chrome()
    js <- local_character_engine()
    result <- js(
      "(() => {const ch={format_version:1,ground:{centre_height:0},parts:[{id:'child',parent:'parent',layer:1},{id:'parent',layer:2},{id:'peer',layer:1}]}; const p=mascot.parts.compile(ch);ch.parts[0].layer=99; return {order:p.order,layers:mascot.parts.frame(p).layers,frozen:Object.isFrozen(p.parts[0])};})()"
    )
    expect_identical(unlist(result$order), c("parent", "child", "peer"))
    expect_identical(unlist(result$layers), c("child", "peer", "parent"))
    expect_true(result$frozen)
  })

  it("rejects bad references and unsafe values with diagnostic codes", {
    skip_without_chrome()
    js <- local_character_engine()
    evaluate_error <- function(code) {
      js(paste0("(() => {try {", code, "; return null;} catch(e) {return {code:e.code,path:e.path};}})()"))
    }
    result <- evaluate_error("mascot.parts.compile({format_version:1,parts:[{id:'a',parent:'b'},{id:'b',parent:'a'}]})")
    expect_identical(result$code, "missing_reference")
    expect_identical(result$path, "$.parts[0].parent")
    expect_identical(evaluate_error("mascot.parts.root(0,{'root.scale_x':17})")$code, "input_type")
    expect_identical(evaluate_error("mascot.parts.root(0,{'root.flip':0})")$code, "invalid_channel")
    expect_identical(evaluate_error("mascot.parts.child([NaN,0,0,1,0,0],{id:'a'})")$code, "non_finite")
    expect_identical(evaluate_error("mascot.parts.compile({format_version:2,parts:[]})")$code, "version")
  })

  it("requires changing wave and nod tracks in the browser validator", {
    skip_without_chrome()
    js <- local_character_engine()
    payload <- as.character(jsonlite::toJSON(format_recipe(), auto_unbox = TRUE, null = "null", digits = NA))
    js(paste0("window.gestureSource=", payload))
    run <- function(mutation) {
      js(paste0(
        "(() => {const ch=JSON.parse(JSON.stringify(gestureSource));",
        mutation,
        ";try {mascot.parts.compile(ch);mascot.parts.requireGreetings(ch);return null;}catch(e) {return {code:e.code,path:e.path,message:e.message};}})()"
      ))
    }
    missing_wave <- run("delete ch.gestures.wave")
    expect_identical(missing_wave$path, "$.gestures.wave")
    expect_match(missing_wave$message, "required 'wave' gesture", fixed = TRUE)
    missing_nod <- run("delete ch.gestures.nod")
    expect_identical(missing_nod$path, "$.gestures.nod")
    expect_match(missing_nod$message, "required 'nod' gesture", fixed = TRUE)
    root_wave <- run("ch.gestures.wave.tracks={'root.rotate':[[0,0],[0.5,0.2],[1,0]]}")
    expect_identical(root_wave$path, "$.gestures.wave.tracks")
    expect_match(root_wave$message, "at least one non-root part channel", fixed = TRUE)
    static_nod <- run("ch.gestures.nod.tracks={'root.rotate':[[0,0],[0.5,0],[1,0]]}")
    expect_identical(static_nod$path, "$.gestures.nod.tracks")
    expect_match(static_nod$message, "at least one track with changing keyed values", fixed = TRUE)
  })
})

describe("prototype names in anchors and accessories", {
  it("rejects undeclared prototype names at their authored paths and accepts declared names", {
    skip_without_chrome()
    js <- local_character_engine()
    payload <- as.character(jsonlite::toJSON(format_recipe(), auto_unbox = TRUE, null = "null", digits = NA))
    js(paste0("window.prototypeSource=", payload))
    run <- function(mutation) {
      js(paste0(
        "(() => {const ch=JSON.parse(JSON.stringify(prototypeSource));",
        mutation,
        ";try {return mascot.parts.frame(mascot.parts.compile(ch), {}, 'full');}",
        "catch(e) {return {code:e.code,path:e.path};}})()"
      ))
    }
    bad_wear <- run("ch.wear=['toString']")
    expect_identical(bad_wear$code, "missing_reference")
    expect_identical(bad_wear$path, "$.wear[0]")
    bad_anchor <- run("ch.accessories.badge.anchor='valueOf'")
    expect_identical(bad_anchor$code, "missing_reference")
    expect_identical(bad_anchor$path, "$.accessories.badge.anchor")
    anchor <- run("ch.anchors={constructor:ch.anchors.badge};ch.accessories.badge.anchor='constructor'")
    expect_true(anchor$anchors$constructor$available)
    expect_true(anchor$parts$wear__badge__disc$available)
    expect_equal(unlist(anchor$anchors$constructor$matrix)[5:6], c(168, 198))
    accessory <- run("ch.accessories={constructor:ch.accessories.badge};ch.wear=['constructor']")
    expect_true(accessory$parts$wear__constructor__disc$available)
    expect_equal(unlist(accessory$parts$wear__constructor__disc$matrix)[5:6], c(168, 198))
  })

  it("uses distinct expanded ids for accessory and local names and rejects reserved separators", {
    skip_without_chrome()
    js <- local_character_engine()
    payload <- as.character(jsonlite::toJSON(format_recipe(), auto_unbox = TRUE, null = "null", digits = NA))
    js(paste0("window.separatorSource=", payload))
    result <- js(
      paste0(
        "(() => {const ch=JSON.parse(JSON.stringify(separatorSource));",
        "const base=ch.accessories.badge;",
        "ch.accessories={a_b:{...base,slot:'a_b',parts:[{...base.parts[0],id:'c'}]},",
        "a:{...base,slot:'a',parts:[{...base.parts[0],id:'b_c'}]}};ch.wear=['a_b','a'];",
        "try {const p=mascot.parts.compile(ch);return p.parts.map(x=>x.id).filter(x=>x.startsWith('wear__'));}",
        "catch(e) {return {code:e.code,path:e.path};}})()"
      )
    )
    expect_setequal(result, c("wear__a_b__c", "wear__a__b_c"))
    invalid <- js(
      paste0(
        "(() => {const ch=JSON.parse(JSON.stringify(separatorSource));ch.parts[0].id='bad__id';",
        "try {mascot.parts.compile(ch);return {code:'none'};} catch(e) {return {code:e.code,path:e.path,message:e.message};}})()"
      )
    )
    expect_identical(invalid$code, "input_type")
    expect_identical(invalid$path, "$.parts[0].id")
    expect_match(invalid$message, "without consecutive underscores", fixed = TRUE)
  })
})

describe("declarative threshold switches and variant anchors", {
  it("evaluates threshold switch strictly above the boundary and recomputes variant anchors", {
    skip_without_chrome()
    js <- local_character_engine()
    recipe <- jsonlite::fromJSON(test_path("fixtures", "format", "anchor_probe.json"), simplifyVector = FALSE)
    recipe$parts[[1]]$switch <- list(
      channel = "root.lift",
      above = 6,
      variant = "raised"
    )
    payload <- as.character(jsonlite::toJSON(recipe, auto_unbox = TRUE, null = "null", digits = NA))
    js(paste0("window.switchProbe = mascot.parts.compile(", payload, ")"))

    state_boundary <- js("mascot.parts.frame(window.switchProbe, { 'root.lift': 6.0 })")
    expect_identical(state_boundary$parts$panel$variant, "default")
    expect_equal(unlist(state_boundary$anchors$badge$matrix)[5:6], c(168, 192))

    state_above <- js("mascot.parts.frame(window.switchProbe, { 'root.lift': 6.001 })")
    expect_identical(state_above$parts$panel$variant, "raised")
    expect_equal(unlist(state_above$anchors$badge$matrix)[5:6], c(170, 193.999), tolerance = 1e-4)
  })

  it("passes resolved item overrides into frame state for geometry rendering", {
    skip_without_chrome()
    js <- local_character_engine()
    recipe <- jsonlite::fromJSON(test_path("fixtures", "format", "anchor_probe.json"), simplifyVector = FALSE)
    recipe$moods$worried$items <- list(
      "panel.surface" = list(fill = "outline", alpha = 0.5)
    )
    payload <- as.character(jsonlite::toJSON(recipe, auto_unbox = TRUE, null = "null", digits = NA))
    js(paste0("window.overrideProbe = mascot.parts.compile(", payload, ")"))

    state <- js("mascot.parts.frame(window.overrideProbe, {}, 'full', { mood: 'worried' })")
    expect_identical(state$item_overrides$`panel.surface`$fill, "outline")
    expect_equal(state$item_overrides$`panel.surface`$alpha, 0.5)
  })

  it("omits item_overrides on frame when absent and avoids item lookups during draw", {
    skip_without_chrome()
    js <- local_character_engine()
    recipe <- jsonlite::fromJSON(test_path("fixtures", "format", "anchor_probe.json"), simplifyVector = FALSE)
    payload <- as.character(jsonlite::toJSON(recipe, auto_unbox = TRUE, null = "null", digits = NA))
    js(paste0("window.overrideProbe = mascot.parts.compile(", payload, ")"))

    # When no mood/item overrides are present, state.item_overrides is absent
    state_no_overrides <- js("mascot.parts.frame(window.overrideProbe, {}, 'full')")
    expect_null(state_no_overrides$item_overrides)

    # In draw(), when no overrides are present, item keys are not looked up
    res <- js(
      "(() => {
      const canvas = document.createElement('canvas');
      canvas.width = 300;
      canvas.height = 300;
      const ctx = canvas.getContext('2d');
      const state = mascot.parts.frame(window.overrideProbe, {}, 'full');
      let lookupCount = 0;
      state.item_overrides = new Proxy({}, {
        get(target, prop) {
          lookupCount++;
          return target[prop];
        }
      });
      mascot.geometry.draw(ctx, window.overrideProbe, state, window.overrideProbe.source.colours);
      return { lookupCount: lookupCount };
    })()"
    )
    expect_identical(res$lookupCount, 0L)
  })
})

describe("E5b detail bands and compile-time band policy", {
  it("classifies the unrounded CSS width: micro below 48, small from 48 to 127.999, full from 128", {
    skip_without_chrome()
    js <- local_character_engine()
    expect_identical(
      unlist(js("[47.999, 48, 127.999, 128, 0, 300].map(w => mascot.parts.bandFor(w))")),
      c("micro", "small", "small", "full", "micro", "full")
    )
    for (bad in c("NaN", "-1", "'48'", "Infinity")) {
      expect_true(js(sprintf(
        "(() => {try {mascot.parts.bandFor(%s);return false;} catch (e) {return e.code === 'input_type' && e.path === '$.width';}})()",
        bad
      )))
    }
  })

  it("rejects unknown bands, keys, face flags, part bands and micro glow with code and path at compile time", {
    skip_without_chrome()
    js <- local_character_engine()
    compile_result <- function(lod = "undefined", part_lod = "undefined") {
      js(sprintf(
        paste0(
          "(() => {const source={format_version:1,ground:{centre_height:100},",
          "parts:[{id:'body',lod:%s,items:[{id:'dot',shape:'circle',r:4,fill:'ink'}]}],",
          "colours:{ink:'#000'},lod:%s};",
          "try{mascot.parts.compile(source);return 'ok';}catch(e){return [e.code,e.path];}})()"
        ),
        part_lod,
        lod
      ))
    }
    # Micro glow is a drawing-budget diagnostic: code budget at the root path, naming the band, key and fix.
    expect_identical(unlist(compile_result('{ micro: { glow: true } }')), c("budget", "$"))
    micro_message <- js(paste0(
      "(() => {const source={format_version:1,ground:{centre_height:100},parts:[],",
      "lod:{micro:{glow:true}}};try{mascot.parts.compile(source);return '';}catch(e){return e.message;}})()"
    ))
    expect_match(micro_message, "band micro")
    expect_match(micro_message, "lod.micro.glow")
    expect_match(micro_message, "remove")
    # full is the file as written, not an override: JS rejects it as R does.
    expect_identical(unlist(compile_result('{ full: { hide: [] } }')), c("unknown_key", "$.lod.full"))
    expect_identical(unlist(compile_result('{ tiny: {} }')), c("unknown_key", "$.lod.tiny"))
    expect_identical(unlist(compile_result('{ micro: { tint: 1 } }')), c("unknown_key", "$.lod.micro.tint"))
    expect_identical(
      unlist(compile_result('{ micro: { face: { blink: true } } }')),
      c("unknown_key", "$.lod.micro.face.blink")
    )
    expect_identical(unlist(compile_result('{ small: { glow: "yes" } }')), c("input_type", "$.lod.small.glow"))
    expect_identical(unlist(compile_result("undefined", "['huge']")), c("unknown_key", "$.parts[0].lod[0]"))
    expect_identical(
      unlist(compile_result('{ small: { glow: true }, micro: { face: { lashes: false }, note: "x" } }')),
      "ok"
    )
    expect_identical(unlist(compile_result("undefined", "['small', 'micro']")), "ok")
  })

  it("applies a band variant over the default and hides parts only in the bands they are not listed for", {
    skip_without_chrome()
    js <- local_character_engine()
    result <- js(paste0(
      "(() => {const source={format_version:1,ground:{centre_height:100},",
      "parts:[{id:'body',items:[{id:'plain',shape:'circle',r:4,fill:'ink'}],",
      "variants:{alt:[{id:'alt_dot',shape:'circle',r:2,fill:'ink'}]}},",
      "{id:'badge',lod:['full'],items:[{id:'b',shape:'circle',r:3,fill:'ink'}]}],",
      "colours:{ink:'#000'},lod:{small:{variants:{body:'alt'}}}};",
      "const compiled=mascot.parts.compile(source);",
      "const full=mascot.parts.frame(compiled,{},'full'),small=mascot.parts.frame(compiled,{},'small');",
      "return {fullItem:full.parts.body.items[0].id,smallItem:small.parts.body.items[0].id,",
      "fullBadge:full.parts.badge.available,smallBadge:small.parts.badge.available};})()"
    ))
    expect_identical(result$fullItem, "plain")
    expect_identical(result$smallItem, "alt_dot")
    expect_true(result$fullBadge)
    expect_false(result$smallBadge)
  })

  it("lets a band variant beat the mood variant and the switch variant", {
    skip_without_chrome()
    js <- local_character_engine()
    result <- js(paste0(
      "(() => {const item=id=>({id,shape:'circle',r:4,fill:'ink'});",
      "const source={format_version:1,ground:{centre_height:100},",
      "parts:[{id:'body',items:[item('plain')],switch:{channel:'root.lift',above:0,variant:'switched'},",
      "variants:{switched:[item('switched')],mood_v:[item('mood')],band_v:[item('band')]}}],",
      "colours:{ink:'#000'},lod:{small:{variants:{body:'band_v'}}}};",
      "const compiled=mascot.parts.compile(source);",
      "const pick=(channels,band)=>mascot.parts.frame(compiled,channels,band).parts.body.items[0].id;",
      "return {mood:pick({'body.variant':'mood_v'},'full'),switched:pick({'root.lift':5},'full'),",
      "bandOverMood:pick({'body.variant':'mood_v'},'small'),bandOverSwitch:pick({'root.lift':5},'small'),",
      "bandOverBoth:pick({'root.lift':5,'body.variant':'mood_v'},'small')};})()"
    ))
    expect_identical(result$mood, "mood")
    expect_identical(result$switched, "switched")
    expect_identical(result$bandOverMood, "band")
    expect_identical(result$bandOverSwitch, "band")
    expect_identical(result$bandOverBoth, "band")
  })
})

describe("reserved capabilities in compile()", {
  it("rejects every reserved capability with code capability and its R path, as the R checker does", {
    skip_without_chrome()
    js <- local_character_engine()
    cases <- jsonlite::fromJSON(test_path("fixtures", "format", "diagnostic-expected.json"), simplifyVector = FALSE)
    reserved <- Filter(function(case) identical(case$code, "capability"), cases)
    expect_length(reserved, 11)
    for (case in reserved) {
      # The same fixture file as the R check; JSON is a JavaScript object literal, so it is passed as one.
      text <- paste(readLines(test_path("fixtures", "format", case$file), warn = FALSE), collapse = "\n")
      result <- js(paste0(
        "(() => {try {mascot.parts.compile(",
        text,
        "); return null;} ",
        "catch (e) {return {code: e.code, path: e.path, message: e.message};}})()"
      ))
      expect_identical(result$code, "capability", info = case$id)
      expect_identical(result$path, case$path, info = case$id)
      expect_match(result$message, "not supported by this version of mascot", fixed = TRUE, info = case$id)
    }
  })

  it("does not reject a data-named key such as a colour role called follow", {
    skip_without_chrome()
    js <- local_character_engine()
    result <- js(paste0(
      "(() => {try {mascot.parts.compile({format_version:1,ground:{centre_height:100},parts:[],",
      "colours:{follow:'#78c8a0'}}); return null;} catch (e) {return {code: e.code};}})()"
    ))
    expect_null(result$code)
  })
})

describe("reserved names in fixed and data positions in compile()", {
  # Runs compile() on a JSON document and returns the thrown code and path, or NULL when it compiles.
  compile_outcome <- function(js, json) {
    js(paste0(
      "(() => {try {mascot.parts.compile(",
      json,
      "); return null;} ",
      "catch (e) {return {code: e.code, path: e.path};}})()"
    ))
  }

  it("accepts reserved names used as data keys, as R does", {
    skip_without_chrome()
    js <- local_character_engine()
    json <- as.character(jsonlite::toJSON(format_data_named_recipe(), auto_unbox = TRUE, null = "null", digits = NA))
    expect_null(compile_outcome(js, json))
  })

  it("rejects a reserved key in a palette preset, not in a palette id called colours", {
    skip_without_chrome()
    js <- local_character_engine()
    json <- paste0(
      "{format_version:1,ground:{centre_height:100},parts:[],",
      "palettes:{colours:{description:'A palette called colours.',light:{body:'#000000'},vividness:1}}}"
    )
    result <- compile_outcome(js, json)
    expect_identical(result$code, "capability")
    expect_identical(result$path, "$.palettes.colours.vividness")
    expect_match(
      js(paste0("(() => {try {mascot.parts.compile(", json, ");} catch (e) {return e.message;}})()")),
      "not supported by this version of mascot",
      fixed = TRUE
    )
  })

  it("reports the earlier structural error when a reserved key sits in a later part, as R does", {
    skip_without_chrome()
    js <- local_character_engine()
    json <- paste0(
      "{format_version:1,ground:{centre_height:100},parts:[{id:'Bad Id',items:[]},",
      "{id:'panel',items:[],follow:{target:'badge'}}]}"
    )
    result <- compile_outcome(js, json)
    expect_identical(result$code, "input_type")
    expect_identical(result$path, "$.parts[0].id")
  })

  it("reports a top-level reserved key before a later structural error, where R reports the structural error", {
    # Documented difference: R walks keys in document order, so a structural error in parts[0] comes first when
    # `extends` is written last (as in the R test); compile() checks the top-level object before its parts.
    skip_without_chrome()
    js <- local_character_engine()
    json <- paste0(
      "{format_version:1,ground:{centre_height:100},parts:[{id:'Bad Id',items:[]}],extends:'tessa'}"
    )
    result <- compile_outcome(js, json)
    expect_identical(result$code, "capability")
    expect_identical(result$path, "$.extends")
  })

  it("rejects a reserved key in a family default mood, as R does", {
    skip_without_chrome()
    js <- local_character_engine()
    json <- paste0(
      "{format_version:1,ground:{centre_height:100},parts:[],",
      "family_definition:{defaults:{moods:{happy:{description:'Done.',status:'Done',channels:{},follow:1}}}}}"
    )
    result <- compile_outcome(js, json)
    expect_identical(result$code, "capability")
    expect_identical(result$path, "$.family_definition.defaults.moods.happy.follow")
  })
})
