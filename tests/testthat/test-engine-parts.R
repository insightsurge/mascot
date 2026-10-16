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
    expect_equal(unlist(state$parts$wear_badge_disc$matrix)[5:6], c(168, 198))
    expect_true(state$parts$wear_badge_disc$available)
    state <- js("mascot.parts.frame(probe, {'panel.variant':'raised'})")
    expect_equal(unlist(state$anchors$badge$matrix)[5:6], c(170, 200))
    state <- js("mascot.parts.frame(probe, {'panel.visible':false})")
    expect_false(state$anchors$badge$available)
    expect_false(state$parts$wear_badge_disc$available)
    expect_equal(unlist(state$anchors$badge$matrix)[5:6], c(168, 198))
    state <- js("mascot.parts.frame(probe, {}, 'micro')")
    expect_false(state$parts$wear_badge_disc$available)
    state <- js("mascot.parts.frame(probe, {'root.scale_x':0})")
    expect_false(state$anchors$badge$available)
    expect_false(state$parts$wear_badge_disc$available)
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
    expect_true(anchor$parts$wear_badge_disc$available)
    expect_equal(unlist(anchor$anchors$constructor$matrix)[5:6], c(168, 198))
    accessory <- run("ch.accessories={constructor:ch.accessories.badge};ch.wear=['constructor']")
    expect_true(accessory$parts$wear_constructor_disc$available)
    expect_equal(unlist(accessory$parts$wear_constructor_disc$matrix)[5:6], c(168, 198))
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
