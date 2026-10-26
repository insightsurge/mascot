# Skips the whole file on CRAN or without Chrome, before any of its code runs.
skip_without_chrome()

describe("generic face kits", {
  it("draws every shipped eye, brow and mouth operation and accepts data-named styles", {
    skip_without_chrome()
    js <- local_face_engine()
    result <- js(
      r"(
      (()=>{
        const counts={};
        for(const id of ['classic','screen']) {
          const source=faceFixture(id),kit=source.face.kit_definition;
          const images=new Set();let renders=0;
          for(const [field,styles] of Object.entries({eyes:kit.eye_styles,brows:kit.brow_styles,mouth:kit.mouth_styles}))
            for(const name of Object.keys(styles)) {const view=paintFace(source,{[field]:name});images.add(view.canvas.toDataURL());renders++;}
          counts[id]={renders,images:images.size};
        }
        const source=faceFixture('screen'),kit=source.face.kit_definition;
        source.face.kit=kit.id='my_panel';kit.eye_styles.pinhole=kit.eye_styles.dot;delete kit.eye_styles.dot;kit.defaults.eyes='pinhole';
        const a=paintFace(source),b=paintFace(faceFixture('screen'));
        return {...counts,same:a.canvas.toDataURL()===b.canvas.toDataURL()};
      })()
    )"
    )
    expect_equal(result$classic$renders, 22)
    expect_gte(result$classic$images, 12)
    expect_equal(result$screen$renders, 12)
    expect_gte(result$screen$images, 9)
    expect_true(result$same)
  })

  it("lets blink win on both eyes and suppresses brows only for the selected eye", {
    skip_without_chrome()
    js <- local_face_engine()
    result <- js(
      r"(
      (()=>{
        const source=faceFixture();
        const closed=paintFace(source,{eyes:'closed'}),blink=paintFace(source,{eyes:'happy',blink:0.96});
        const happy=paintFace(source,{eyes:'happy'}),almost=paintFace(source,{eyes:'happy',blink:0.95});
        const pair=paintFace(source,{eyes:['happy','open'],brows:'raised'}),bare=paintFace(source,{eyes:['happy','open']});
        const both=paintFace(source,{eyes:'open',brows:'raised'}),noBrows=paintFace(source,{eyes:'open'});
        return {closed:closed.canvas.toDataURL()===blink.canvas.toDataURL(),happy:happy.canvas.toDataURL()===almost.canvas.toDataURL(),
          one:pair.counts.painted_items-bare.counts.painted_items,two:both.counts.painted_items-noBrows.counts.painted_items};
      })()
    )"
    )
    expect_true(result$closed)
    expect_true(result$happy)
    expect_equal(result$one, 1)
    expect_equal(result$two, 2)
  })

  it("keeps gaze and glints in face space and clips pupils to one inset ellipse", {
    skip_without_chrome()
    js <- local_face_engine()
    result <- js(
      r"(
      (()=>{
        const source=faceFixture();source.face.eyes.lashes=false;
        const pupil=source.face.kit_definition.eye_styles.open.pupil;pupil.glints=[{at:[0.6,0],r:0.2}];
        const normal=paintFace(source),gaze=paintFace(source,{look_x:1,look_y:1});
        pupil.mirror_glints=true;const mirrored=paintFace(source);
        pupil.at=[100,0];pupil.glints=[];const clipped=paintFace(source);
        return {normal:[normal.pixel(126,158),normal.pixel(186,158)],mirrored:[mirrored.pixel(114,158),mirrored.pixel(126,158)],
          gaze:[gaze.pixel(127,165),gaze.pixel(187,165)],outside:clipped.pixel(280,158),clips:clipped.counts.clip_applications};
      })()
    )"
    )
    expect_equal(unlist(result$normal), rep(c(255, 255, 255, 255), 2))
    expect_equal(unlist(result$mirrored[[1]]), c(255, 255, 255, 255))
    expect_equal(unlist(result$mirrored[[2]]), c(22, 32, 27, 255))
    expect_equal(unlist(result$gaze), rep(c(22, 32, 27, 255), 2))
    expect_equal(unlist(result$outside), c(0, 0, 0, 0))
    expect_equal(result$clips, 2)
  })

  it("applies whole styles before tuning, follows implicit lash radii and leaves explicit radii alone", {
    skip_without_chrome()
    js <- local_face_engine()
    result <- js(
      r"(
      (()=>{
        const source=faceFixture(),raw=source.face.kit_definition.eye_styles.open.rx;
        const style=source.face.kit_definition.eye_styles.open;style.lashes={angles:[0],length:10,width:4};
        source.face.tune={eyes:{open:{rx:25,ry:26}}};
        const follow=paintFace(source);style.lashes.radii=[5,5];const explicit=paintFace(source);
        source.face.styles={eyes:{open:{op:'eye_dots',centres:[[0,0]],r:3}}};source.face.tune={eyes:{open:{r:5}}};
        const replacement=paintFace(source);
        const errors=[];
        for(const tune of [{eyes:{open:{r:-1}}},{eyes:{open:{op:3}}},{eyes:{open:{centres:[[0,0],[1,1]]}}}]) {
          source.face.tune=tune;try{mascot.faces.compile(source);}catch(e){errors.push(e.code);}
        }
        return {follow:follow.pixel(211,158)[3],explicit:explicit.pixel(211,158)[3],replacement:replacement.pixel(123,158)[3],
          unchanged:source.face.kit_definition.eye_styles.open.rx===raw,errors};
      })()
    )"
    )
    expect_equal(result$follow, 255)
    expect_equal(result$explicit, 0)
    expect_equal(result$replacement, 255)
    expect_true(result$unchanged)
    expect_identical(result$errors, list("input_type", "input_type", "input_type"))
  })

  it("batches disjoint blush geometry while retaining alpha composition for overlaps and RGB overrides", {
    skip_without_chrome()
    js <- local_face_engine()
    result <- js(
      r"(
      (()=>{
        const source=faceFixture(),view=paintFace(source,{blush:0}),g=view.ctx;
        g.save();g.transform(...view.state.parts.body.matrix);g.fillStyle='rgba(127,203,164,0.45)';g.beginPath();
        g.ellipse(-36,18,13,7,0,0,7);g.moveTo(49,18);g.ellipse(36,18,13,7,0,0,7);g.fill();g.restore();
        const batched=paintFace(source);source.colours.blush='rgb(127,203,164)';const rgb=paintFace(source);
        source.face.blush.x=0;const overlap=paintFace(source);
        return {same:view.canvas.toDataURL()===batched.canvas.toDataURL(),rgb:rgb.canvas.toDataURL()===batched.canvas.toDataURL(),alpha:overlap.pixel(150,188)[3]};
      })()
    )"
    )
    expect_true(result$same)
    expect_true(result$rgb)
    expect_gt(result$alpha, 170)
    expect_lt(result$alpha, 185)
  })

  it("maps mouth geometry through box and openness without scaling stroke width", {
    skip_without_chrome()
    js <- local_face_engine()
    result <- js(
      r"(
      (()=>{
        const source=faceFixture();source.face.styles={mouth:{line:{op:'mouth_path',box:[10,20],items:[{shape:'path',d:'M-1 1 L1 1',stroke:'feature',width:4}]}}};
        return [1,0.5,0].map(open=>{
          const view=paintFace(source,{mouth:'line',open}),rows=[];
          for(let y=190;y<222;y++)if(view.pixel(150,y)[3])rows.push(y);
          return {height:rows.length,start:rows[0],passes:view.counts.paint_passes};
        });
      })()
    )"
    )
    expect_equal(vapply(result, `[[`, numeric(1), "height"), c(4, 4, 4))
    expect_equal(result[[1]]$start - result[[2]]$start, 10)
    expect_equal(result[[1]]$start - result[[3]]$start, 20)
  })

  it("applies an outer active-item clip, owner opacity and face transforms while restoring caller state", {
    skip_without_chrome()
    js <- local_face_engine()
    result <- js(
      r"(
      (()=>{
        const source=faceFixture();source.parts[0].opacity=0.5;
        source.parts.push({id:'mask',parent:'body',at:[-10,-60],visible:false,items:[{id:'cut',shape:'rect',w:20,h:120}]});source.face.clip='mask.cut';
        const parts=mascot.parts.compile(source),state=mascot.parts.frame(parts),face=mascot.faces.compile(source);
        const c=document.createElement('canvas');c.width=c.height=300;const g=c.getContext('2d');
        g.globalAlpha=0.4;g.lineWidth=9;g.lineCap='square';g.lineJoin='bevel';
        const before=[g.globalAlpha,g.lineWidth,g.lineCap,g.lineJoin,g.getTransform().a,g.getTransform().e];
        const count=mascot.faces.draw(g,face,state,{mouth:'flat'},source.colours);
        const after=[g.globalAlpha,g.lineWidth,g.lineCap,g.lineJoin,g.getTransform().a,g.getTransform().e];
        const moved=paintFace({...source,face:{...source.face,clip:undefined,at:[10,0],scale:0.5}},{mouth:'flat'});
        const dead=mascot.parts.frame(parts,{'body.scale_x':0});
        return {before,after,eye:[...g.getImageData(120,158,1,1).data],mouth:[...g.getImageData(150,202,1,1).data],
          clips:count.clip_applications,moved:moved.pixel(160,186)[3],zero:mascot.faces.draw(g,face,dead,{},source.colours).painted_items};
      })()
    )"
    )
    expect_identical(result$before, result$after)
    expect_equal(unlist(result$eye), c(0, 0, 0, 0))
    expect_equal(result$mouth[[4]], 51)
    expect_equal(result$clips, 3)
    expect_gt(result$moved, 0)
    expect_equal(result$zero, 0)
  })

  it("draws a bounded screen glow per glyph and keeps micro glyphs crisp without glow", {
    skip_without_chrome()
    js <- local_face_engine()
    result <- js(
      r"(
      (()=>{
        const source=faceFixture('screen'),full=paintFace(source),micro=paintFace(source,{}, {band:'micro'});
        const c=document.createElement('canvas');c.width=c.height=600;const g=c.getContext('2d');g.scale(2,2);
        mascot.faces.draw(g,full.compiled,full.state,{},source.colours);
        return {full:full.counts,micro:micro.counts,halo:full.pixel(127,158)[3],plain:micro.pixel(127,158)[3],
          dpr2:[...g.getImageData(254,316,1,1).data][3],centre:micro.pixel(120,158)[3]};
      })()
    )"
    )
    expect_equal(result$full$glow_emitters, 3)
    expect_equal(result$full$paint_passes, 6)
    expect_equal(result$micro$glow_emitters, 0)
    expect_gt(result$halo, 0)
    expect_equal(result$plain, 0)
    expect_gt(result$dpr2, 0)
    expect_equal(result$centre, 255)
  })

  it("uses full glow alpha when an embedded kit omits it", {
    skip_without_chrome()
    js <- local_face_engine()
    result <- js(
      r"(
      (()=>{
        const source=faceFixture('screen');source.face.kit_definition.glow.alpha=1;
        const explicit=paintFace(source);delete source.face.kit_definition.glow.alpha;
        const implicit=paintFace(source);
        return {same:explicit.canvas.toDataURL()===implicit.canvas.toDataURL(),halo:implicit.pixel(127,158)[3]};
      })()
    )"
    )
    expect_true(result$same)
    expect_gt(result$halo, 0)
  })

  it("retains static sweat under reduction, bounds pulse phase and reuses effect compiles", {
    skip_without_chrome()
    js <- local_face_engine()
    result <- js(
      r"(
      (()=>{
        const source=faceFixture();source.effects={sweat:{anchor:'mark',layer:3},sparkle:{anchor:'mark',layer:3}};
        const parts=mascot.parts.compile(source),state=mascot.parts.frame(parts),compile=mascot.parts.compile;let calls=0;
        mascot.parts={...mascot.parts,compile:(...args)=>{calls++;return compile(...args);}};
        try {
          const face=mascot.faces.compile(source),first=calls;
          const paint=(controls,options)=>{const c=document.createElement('canvas');c.width=c.height=300;const counts=mascot.faces.effects(c.getContext('2d'),face,state,controls,source.colours,options);return {png:c.toDataURL(),counts};};
          const sweat=paint({sweat:0.5},{frame:90}),reduced=paint({sweat:0.5},{frame:90,reduced:true});
          const a=paint({sparkle:true},{frame:30,activity_deadline:30}),b=paint({sparkle:true},{frame:300,activity_deadline:30});
          const staticStar=paint({sparkle:true},{frame:300,reduced:true});
          return {same:sweat.png===reduced.png,sweat:sweat.counts.painted_items,held:a.png===b.png,
            reduced:staticStar.counts.painted_items,first,last:calls};
        } finally {mascot.parts={...mascot.parts,compile};}
      })()
    )"
    )
    expect_true(result$same)
    expect_equal(result$sweat, 2)
    expect_true(result$held)
    expect_equal(result$reduced, 1)
    expect_equal(result$first, 2)
    expect_equal(result$last, 2)
  })

  it("inherits the effect anchor owner's opacity and restores the caller alpha", {
    skip_without_chrome()
    js <- local_face_engine()
    result <- js(
      r"(
      (()=>{
        const source=faceFixture();source.parts[0].opacity=0.5;source.effects={mark:{anchor:'mark'}};
        source.face.kit_definition.effects.mark={op:'sweat_drop',mode:'progress',travel:0,sway:0,items:[{shape:'circle',r:6,fill:'feature'}]};
        const state=mascot.parts.frame(mascot.parts.compile(source)),face=mascot.faces.compile(source);
        const c=document.createElement('canvas');c.width=c.height=300;const g=c.getContext('2d');g.globalAlpha=0.4;
        mascot.faces.effects(g,face,state,{mark:0.5},source.colours);
        return {pixel:[...g.getImageData(210,140,1,1).data],alpha:g.globalAlpha};
      })()
    )"
    )
    expect_equal(result$pixel[[4]], 51)
    expect_equal(result$alpha, 0.4)
  })

  it("locates invalid tuned brow and mouth values in the embedded kit", {
    skip_without_chrome()
    js <- local_face_engine()
    result <- js(
      r"(
      (()=>{
        const paths=[];
        for(const tune of [{brows:{neutral:{width:-1}}},{mouth:{flat:{box:[-1,20]}}}]){
          const source=faceFixture();source.face.tune=tune;
          try{mascot.faces.compile(source);}catch(e){paths.push(e.path);}
        }
        return paths;
      })()
    )"
    )
    expect_identical(
      result,
      list(
        "$.face.kit_definition.brow_styles.neutral.width",
        "$.face.kit_definition.mouth_styles.flat.box[0]"
      )
    )
  })

  it("supports faceless drawing and fails missing data or unsupported operations without painting", {
    skip_without_chrome()
    js <- local_face_engine()
    result <- js(
      r"(
      (()=>{
        const source=faceFixture();source.face=null;
        const parts=mascot.parts.compile(source),state=mascot.parts.frame(parts),face=mascot.faces.compile(source);
        const c=document.createElement('canvas');c.width=c.height=300;const g=c.getContext('2d');
        mascot.geometry.draw(g,parts,state,source.colours);const before=c.toDataURL();
        const zero=mascot.faces.draw(g,face,state,{},source.colours),same=before===c.toDataURL();
        const errors=[];
        for(const variant of ['faceless','operation','mode','reduction','style','paint']) {
          const ch=faceFixture();
          try {
            if(variant==='faceless'){ch.face=null;ch.effects={sweat:{anchor:'mark'}};}
            if(variant==='operation')ch.face.kit_definition.eye_styles.open.op='callback';
            if(variant==='mode'){ch.effects={sweat:{anchor:'mark'}};ch.face.kit_definition.effects.sweat.mode='pulse';}
            if(variant==='reduction'){ch.effects={sweat:{anchor:'mark'}};ch.face.kit_definition.effects.sweat.reduced_items=[];}
            const compiled=mascot.faces.compile(ch);
            if(variant==='style')mascot.faces.draw(g,compiled,state,{eyes:'constructor'},ch.colours);
            if(variant==='paint'){delete ch.colours.feature;mascot.faces.draw(g,compiled,state,{},ch.colours);}
          } catch(e){errors.push(e.code);}
        }
        return {zero:zero.painted_items,same,errors,unchanged:before===c.toDataURL()};
      })()
    )"
    )
    expect_equal(result$zero, 0)
    expect_true(result$same)
    expect_identical(
      result$errors,
      list("missing_reference", "capability", "capability", "input_type", "missing_reference", "invalid_colour")
    )
    expect_true(result$unchanged)
  })
})

describe("face clips and effect anchors", {
  it("compiles a face clip's geometry once per clip item: the second draw of the same face compiles nothing", {
    skip_without_chrome()
    js <- local_face_engine()
    result <- js(
      r"(
      (()=>{
        const source=faceFixture();
        source.parts.push({id:'mask',parent:'body',at:[-10,-60],visible:false,items:[{id:'cut',shape:'rect',w:20,h:120}]});
        source.face.clip='mask.cut';
        const parts=mascot.parts.compile(source),state=mascot.parts.frame(parts),face=mascot.faces.compile(source);
        const geometry=mascot.geometry;let calls=0;
        mascot.geometry={...geometry,compile:(...args)=>{calls++;return geometry.compile(...args);}};
        try {
          const c=document.createElement('canvas');c.width=c.height=300;const g=c.getContext('2d');
          const first=mascot.faces.draw(g,face,state,{mouth:'flat'},source.colours);
          const afterFirst=calls;
          const second=mascot.faces.draw(g,face,state,{mouth:'flat'},source.colours);
          return {clips:first.clip_applications,clipsAgain:second.clip_applications,firstCompiles:afterFirst,
            secondCompiles:calls-afterFirst};
        } finally {mascot.geometry=geometry;}
      })()
    )"
    )
    expect_equal(result$clips, 3)
    expect_equal(result$clipsAgain, 3)
    expect_gt(result$firstCompiles, 0)
    expect_equal(result$secondCompiles, 0)
  })

  it("draws a triggered effect at the anchor the trigger names, and at the mapping's anchor when none is named", {
    skip_without_chrome()
    js <- local_face_engine()
    result <- js(
      r"(
      (()=>{
        const source=faceFixture();source.parts[0].opacity=1;
        source.anchors.other={part:'body',at:[-60,-30]};
        source.effects={mark:{anchor:'mark'}};
        source.face.kit_definition.effects.mark={op:'sweat_drop',mode:'progress',travel:0,sway:0,items:[{shape:'circle',r:6,fill:'feature'}]};
        const state=mascot.parts.frame(mascot.parts.compile(source)),face=mascot.faces.compile(source);
        const paint=(options)=>{const c=document.createElement('canvas');c.width=c.height=300;const g=c.getContext('2d');
          mascot.faces.effects(g,face,state,{mark:0.5},source.colours,options);return c;};
        const at=(c,x,y)=>[...c.getContext('2d').getImageData(x,y,1,1).data][3];
        const mapped=paint({}), named=paint({effect_anchors:{mark:'other'}});
        // The mark is at the body origin plus (60, -30); the other anchor is at (-60, -30), a mirror of it about the body.
        return {mappedRight:at(mapped,210,140),mappedLeft:at(mapped,90,140),namedRight:at(named,210,140),namedLeft:at(named,90,140)};
      })()
    )"
    )
    expect_gt(result$mappedRight, 0)
    expect_equal(result$mappedLeft, 0)
    expect_equal(result$namedRight, 0)
    expect_gt(result$namedLeft, 0)
  })
})
