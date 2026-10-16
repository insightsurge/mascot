describe("provisional Tessa adapter", {
  it("keeps the legacy path by default and paints real parts only when enabled", {
    skip_without_chrome()
    js <- local_engine_page()
    result <- js(paste0(
      "(() => {const ch=mascot.readCharacter('tessa'),c=document.createElement('canvas');",
      "c.width=300;c.height=300;const g=c.getContext('2d'),draw=mascot.geometry.draw;",
      "let calls=0,count={painted_items:0,paint_passes:0};mascot.geometry={...mascot.geometry,draw:(...args)=>{calls++;const c=draw(...args);count.painted_items+=c.painted_items;count.paint_passes+=c.paint_passes;return c;}};",
      "try{mascot.draw(g,ch,{x:150,baseY:270,pose:{mood:'idle'},frame:0});const before=calls;",
      "g.clearRect(0,0,300,300);mascot.internal={useCharacterAdapter:true};",
      "mascot.draw(g,ch,{x:150,baseY:270,pose:{mood:'idle'},frame:0});",
      "return {before,calls,count,pixel:[...g.getImageData(150,150,1,1).data],transform:g.getTransform().e};}",
      "finally{delete mascot.internal;mascot.geometry={...mascot.geometry,draw};}})()"
    ))
    expect_equal(result$before, 0)
    expect_equal(result$calls, 4)
    # Shadow, feet/body, bow and arms/hands; the generic face paints separately.
    expect_equal(result$count$painted_items, 15)
    expect_equal(result$count$paint_passes, 25)
    expect_equal(result$pixel[[4]], 255)
    expect_equal(result$transform, 0)
  })

  it("refuses another character and a missing adapter without silently changing paths", {
    skip_without_chrome()
    js <- local_engine_page()
    expect_match(
      js(paste0(
        "(() => {const ch=mascot.readCharacter('blob'),g=document.createElement('canvas').getContext('2d');",
        "try{mascot.tessaAdapter.scene(ch,{},{});}catch(e){return e.message;}})()"
      )),
      "supports only Tessa"
    )
    expect_match(
      js(paste0(
        "(() => {const adapter=mascot.tessaAdapter;mascot.internal={useCharacterAdapter:true};delete mascot.tessaAdapter;",
        "try{",
        draw_js("{mood:'idle'}"),
        ";}catch(e){return e.message;}",
        "finally{mascot.tessaAdapter=adapter;delete mascot.internal;}})()"
      )),
      "load the provisional Tessa adapter"
    )
    expect_match(
      js(paste0(
        "(() => {const ch=JSON.parse(JSON.stringify(mascot.readCharacter('tessa')));ch.accessories.bow.layer=2;",
        "const p=mascot.drawing.resolvePose(ch,{mood:'idle'},0);",
        "try{mascot.tessaAdapter.scene(ch,p,ch.colours);}catch(e){return e.message;}})()"
      )),
      "unsupported part layer"
    )
  })
})


describe("E1 Tessa matrices and attachment order", {
  it("matches legacy anchor coordinates under rotation, reflection, squash and tucked feet", {
    skip_without_chrome()
    js <- local_engine_page()
    result <- js(
      r"(
      (() => {
        const ch=mascot.readCharacter('tessa'),cases=[
          {mood:'idle'}, {mood:'thinking'}, {mood:'happy'}, {mood:'worried'}, {mood:'celebrating'},
          {mood:'celebrating',rot:0.37,flip:-1,sx:1.3,sy:0.7,scale:0.85,armJitter:0.12},
          {mood:'idle',rot:-0.28,feet:'tuck',armL:-0.7,armR:2.1}
        ];
        let maximum=0;
        for(const pose of cases){
          const p=mascot.drawing.resolvePose(ch,pose,12),scene=mascot.tessaAdapter.scene(ch,p,ch.colours,123,281);
          const old=mascot.drawing.anchors(ch,{x:123,baseY:281,pose,frame:12});
          for(const [id,point] of Object.entries(old)){
            const pairs=['hands','feet','shoulders'].includes(id)?[['left',point.L],['right',point.R]]:[['',point]];
            for(const [side,at] of pairs){
              const m=scene.state.anchors[side?id+'_'+side:id].matrix;
              for(const [a,b] of [[m[4],at.x],[m[5],at.y],[m[0],at.matrix.a],[m[1],at.matrix.b],[m[2],at.matrix.c],[m[3],at.matrix.d]]) maximum=Math.max(maximum,Math.abs(a-b));
            }
          }
        }
        return maximum;
      })()
      )"
    )
    expect_lt(result, 1e-9)
  })

  it("places attachments before arms, preserves caller state and collapses zero-scale owners", {
    skip_without_chrome()
    js <- local_engine_page()
    result <- js(
      r"(
      (() => {
        const ch=mascot.readCharacter('tessa'),p=mascot.drawing.resolvePose(ch,{mood:'idle'},0);
        const c=document.createElement('canvas');c.width=400;c.height=400;const g=c.getContext('2d');
        g.translate(7,9);g.scale(0.8,1.1);g.globalAlpha=0.65;g.lineWidth=7;g.lineCap='square';
        const before=[...['a','b','c','d','e','f'].map(k=>g.getTransform()[k]),g.globalAlpha,g.lineWidth,g.lineCap];
        let face=0,effects=0;const faces=mascot.faces;
        mascot.faces={...faces,draw:(...args)=>{face++;return faces.draw(...args);},effects:(...args)=>{effects++;return faces.effects(...args);}};
        const result=mascot.tessaAdapter.draw(g,ch,p,ch.colours,150,270);
        const after=[...['a','b','c','d','e','f'].map(k=>g.getTransform()[k]),g.globalAlpha,g.lineWidth,g.lineCap];
        const layers=result.state.layers.map(id=>result.state.parts[id].layer);
        const zero=mascot.tessaAdapter.draw(g,ch,{...p,scale:0,shadow:true},ch.colours,150,270);mascot.faces=faces;
        return {before,after,layers,face,effects,zero:zero.counts.painted_items};
      })()
      )"
    )
    expect_identical(result$before, result$after)
    expect_identical(unlist(result$layers), c(0L, 0L, 1L, 3L, 4L, 4L))
    expect_equal(result$face, 1)
    expect_equal(result$effects, 1)
    expect_equal(result$zero, 0)
  })

  it("leaves pixels and state untouched when required modules are absent", {
    skip_without_chrome()
    js <- local_engine_page()
    result <- js(
      r"(
      (() => {
        const ch=mascot.readCharacter('tessa'),g=document.createElement('canvas').getContext('2d');
        g.translate(3,4);g.fillStyle='#ff0000';g.fillRect(0,0,1,1);
        const before=g.canvas.toDataURL(),module=mascot.geometry;let error;
        mascot.internal={useCharacterAdapter:true};delete mascot.geometry;
        try{mascot.draw(g,ch,{pose:{mood:'idle'}});}catch(e){error=e.message;}
        finally{mascot.geometry=module;delete mascot.internal;}
        return {error,same:before===g.canvas.toDataURL(),x:g.getTransform().e,y:g.getTransform().f};
      })()
      )"
    )
    expect_match(result$error, "needs parts and geometry")
    expect_true(result$same)
    expect_equal(result$x, 3)
    expect_equal(result$y, 4)
  })
})


describe("adapter accessory placement and alpha", {
  it("attaches to the moving left hand or tucked foot and keeps translucent fill separate from stroke", {
    skip_without_chrome()
    js <- local_engine_page()
    result <- js(
      r"(
      (() => {
        const ch=mascot.readCharacter('tessa');let maximum=0;
        for(const name of ['hands','feet','shoulders']) {
          const copy=JSON.parse(JSON.stringify(ch));copy.accessories.bow.anchor=name;copy.accessories.bow.side='L';
          const p=mascot.drawing.resolvePose(copy,{mood:'celebrating',rot:0.3,flip:-1,sy:0.7},9);
          const scene=mascot.tessaAdapter.scene(copy,p,copy.colours,150,270);
          const attachment=scene.state.parts.wear_attachment_0_drawing.matrix;
          const target=scene.state.anchors[name+'_left'].matrix;
          attachment.forEach((v,i)=>{maximum=Math.max(maximum,Math.abs(v-target[i]));});
        }
        const copy=JSON.parse(JSON.stringify(ch));copy.body=[{shape:'roundRect',x:-50,y:-50,w:100,h:100,r:0,fill:'body',stroke:'outline',alpha:0.25,lineWidth:8}];
        const c=document.createElement('canvas');c.width=300;c.height=300;const g=c.getContext('2d');
        const pixels=[];
        for(const enabled of [false,true]) {
          g.clearRect(0,0,300,300);mascot.internal={useCharacterAdapter:enabled};
          mascot.draw(g,copy,{x:150,baseY:270,pose:{mood:'idle',accessory:'none',shadow:false,blush:false},colours:{body:'#00ff00',outline:'#000000'}});
          pixels.push({fill:[...g.getImageData(130,200,1,1).data],stroke:[...g.getImageData(100,200,1,1).data]});
        }
        delete mascot.internal;
        return {maximum,pixels};
      })()
      )"
    )
    expect_lt(result$maximum, 1e-9)
    expect_identical(result$pixels[[1]], result$pixels[[2]])
    expect_equal(unlist(result$pixels[[2]]$fill), c(0, 255, 0, 64))
    expect_equal(unlist(result$pixels[[2]]$stroke), c(0, 0, 0, 255))
  })
})

describe("adapter face mounting", {
  it("applies an authored face anchor once while mounting the generic face kit", {
    skip_without_chrome()
    js <- local_engine_page()
    result <- js(
      r"(
      (() => {
        const ch=JSON.parse(JSON.stringify(mascot.readCharacter('tessa')));
        ch.anchors.face={x:20,y:10,scale:0.5};
        const p=mascot.drawing.resolvePose(ch,{mood:'idle'},0);
        const frame=mascot.tessaAdapter.scene(ch,p,ch.colours,150,270);
        const point=mascot.parts.point(frame.state.anchors.face.matrix,[-ch.face.eyes.spacing,ch.face.eyes.y]);
        const c=document.createElement('canvas');c.width=300;c.height=300;const g=c.getContext('2d');
        const pixels=[];
        for(const enabled of [false,true]) {
          g.clearRect(0,0,300,300);mascot.internal={useCharacterAdapter:enabled};
          mascot.draw(g,ch,{x:150,baseY:270,pose:{mood:'idle'},colours:{feature:'#ff00ff',eyeWhite:'#ffffff',shine:'#00ffff',body:'#00ff00'}});
          pixels.push([...g.getImageData(Math.round(point[0]),Math.round(point[1]),1,1).data]);
        }
        delete mascot.internal;
        return pixels;
      })()
      )"
    )
    expect_equal(unlist(result[[1]]), c(255, 0, 255, 255))
    expect_identical(result[[1]], result[[2]])
  })
})


describe("TC-03 compiled adapter scenes", {
  it("reuses body and shadow compiles while applying frame channels and fresh colours", {
    skip_without_chrome()
    js <- local_engine_page()
    result <- js(
      r"(
      (() => {
        const ch=mascot.readCharacter('tessa'),compile=mascot.parts.compile;
        let calls=0;mascot.parts={...mascot.parts,compile:(...args)=>{calls++;return compile(...args);}};
        const g=document.createElement('canvas').getContext('2d'),painters={face:()=>{},effects:()=>{}};
        const p=mascot.drawing.resolvePose(ch,{mood:'idle'},0);
        try {
          const a=mascot.tessaAdapter.scene(ch,p,ch.colours);
          mascot.tessaAdapter.draw(g,ch,p,ch.colours,150,270,painters);
          const first=calls;
          const moved={...p,lift:5,rot:0.2,armL:0.7,armR:2,armJitter:0.1,t:9,sx:0.8};
          const b=mascot.tessaAdapter.scene(ch,moved,{...ch.colours,body:'#ff0000'});
          mascot.tessaAdapter.draw(g,ch,moved,ch.colours,123,260,painters);
          const second=calls;
          const tuck=mascot.tessaAdapter.scene(ch,{...p,feet:'tuck'},ch.colours);
          const bare=mascot.tessaAdapter.scene(ch,{...p,accessory:'none'},ch.colours);
          const back=mascot.tessaAdapter.scene(ch,p,ch.colours);
          const copy={...ch},other=mascot.tessaAdapter.scene(copy,p,ch.colours);
          return {first,second,same:a.compiled===b.compiled,back:a.compiled===back.compiled,
            different:[tuck,bare,other].every(f=>f.compiled!==a.compiled),
            moved:JSON.stringify(a.state.parts.arm_left.matrix)!==JSON.stringify(b.state.parts.arm_left.matrix),
            colour:b.colours.body,source:a.compiled.source.parts.find(p=>p.id==='arm_left').rotate};
        } finally {mascot.parts={...mascot.parts,compile};}
      })()
    )"
    )
    expect_equal(result$first, 4)
    expect_equal(result$second, 4)
    expect_true(result$same)
    expect_true(result$back)
    expect_true(result$different)
    expect_true(result$moved)
    expect_equal(result$colour, "#ff0000")
    expect_equal(result$source, 0)
  })
})
