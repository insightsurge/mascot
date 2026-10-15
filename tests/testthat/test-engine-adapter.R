describe("provisional Tessa adapter", {
  it("keeps the legacy path by default and paints real parts only when enabled", {
    skip_without_chrome()
    js <- local_engine_page()
    result <- js(paste0(
      "(() => {const ch=mascot.readCharacter('tessa'),c=document.createElement('canvas');",
      "c.width=300;c.height=300;const g=c.getContext('2d'),draw=mascot.geometry.draw;",
      "let calls=0,count;mascot.geometry={...mascot.geometry,draw:(...args)=>{calls++;count=draw(...args);return count;}};",
      "try{mascot.draw(g,ch,{x:150,baseY:270,pose:{mood:'idle'},frame:0});const before=calls;",
      "g.clearRect(0,0,300,300);mascot.internal={useCharacterAdapter:true};",
      "mascot.draw(g,ch,{x:150,baseY:270,pose:{mood:'idle'},frame:0});",
      "return {before,calls,count,pixel:[...g.getImageData(150,150,1,1).data],transform:g.getTransform().e};}",
      "finally{delete mascot.internal;mascot.geometry={...mascot.geometry,draw};}})()"
    ))
    expect_equal(result$before, 0)
    expect_equal(result$calls, 1)
    # Two standing feet plus three authored body shapes, five fills plus two foot
    # strokes and one rim stroke = eight passes. No face is counted by this bridge.
    expect_equal(result$count$painted_items, 5)
    expect_equal(result$count$paint_passes, 8)
    expect_equal(result$pixel[[4]], 255)
    expect_equal(result$transform, 0)
  })

  it("refuses another character and a missing adapter without silently changing paths", {
    skip_without_chrome()
    js <- local_engine_page()
    expect_match(
      js(paste0(
        "(() => {const ch=mascot.readCharacter('blob'),g=document.createElement('canvas').getContext('2d');",
        "try{mascot.tessaAdapter.drawBase(g,ch,{},{});}catch(e){return e.message;}})()"
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
  })
})
