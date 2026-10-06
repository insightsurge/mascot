# The host is JavaScript, so it has its own browser test file, like the engine.
describe("mascot.host", {
  it("mounts static markup at the CSS size and is idempotent", {
    skip_without_chrome()
    js <- local_host_page()
    result <- js(
      "(() => {
      const el = document.getElementById('a'), c = el.querySelector('canvas');
      const before = mascot.host.state(el); mascot.host.mount(el);
      return { state: mascot.host.state(el), same: JSON.stringify(before) === JSON.stringify(mascot.host.state(el)),
        mood: el.dataset.shownMood, character: el.dataset.shownCharacter, swapping: el.dataset.swapping,
        status: el.querySelector('.mascot-status').textContent, aria: c.getAttribute('aria-label'),
        width: c.width, height: c.height, ratio: devicePixelRatio, transform: c.getContext('2d').getTransform().a };
    })()"
    )
    expect_true(result$same)
    expect_identical(result$mood, "idle")
    expect_identical(result$character, "tessa")
    expect_identical(result$swapping, "false")
    expect_identical(result$status, "Idle")
    expect_identical(result$aria, "Tessa, idle")
    expect_equal(result$width, round(160 * result$ratio))
    expect_equal(result$height, result$width)
    expect_equal(result$transform, result$width / 300, tolerance = 1e-6)
  })
  it("follows the shown mood, preserves custom text and hands it back", {
    skip_without_chrome()
    js <- local_host_page()
    result <- js(
      "(() => {
      const el = document.getElementById('a'), text = () => el.querySelector('.mascot-status').textContent;
      const send = patch => mascot.host.receive({id:'a',patch});
      send({mood:'happy'}); const happy = text();
      send({status:{mode:'custom',text:'<b>Saved</b>'}}); send({mood:'thinking'});
      const custom = text(), markup = el.querySelector('.mascot-status').innerHTML;
      send({status:{mode:'mood'}});
      return {happy, custom, markup, thinking:text(), mood:el.dataset.shownMood, aria:el.querySelector('canvas').getAttribute('aria-label')};
    })()"
    )
    expect_identical(result$happy, "Happy")
    expect_identical(result$custom, "<b>Saved</b>")
    expect_identical(result$markup, "&lt;b&gt;Saved&lt;/b&gt;")
    expect_identical(result$thinking, "Thinking")
    expect_identical(result$mood, "thinking")
    expect_identical(result$aria, "Tessa, thinking")
  })
  it("swaps to the fixture's first mood while keeping custom text", {
    skip_without_chrome()
    js <- local_host_page()
    result <- js(
      "(() => {
      const el = document.getElementById('a'), blob = mascot.readCharacter('blob');
      mascot.host.receive({id:'a',patch:{mood:'happy',status:{mode:'custom',text:'Still saving'}}});
      mascot.host.receive({id:'a',patch:{character:{id:blob.id,name:blob.name,json:JSON.stringify(blob)}}});
      return {state:mascot.host.state(el), first:Object.keys(blob.moods)[0], status:el.querySelector('.mascot-status').textContent,
        character:el.dataset.shownCharacter, aria:el.querySelector('canvas').getAttribute('aria-label'), name:blob.name};
    })()"
    )
    expect_identical(result$character, "blob")
    expect_identical(result$state$mood, result$first)
    expect_identical(result$state$current$mood, result$first)
    expect_identical(result$status, "Still saving")
    expect_identical(result$aria, paste0(result$name, ", ", result$first))
  })
  it("rejects entire invalid patches, including their text and desired state", {
    skip_without_chrome()
    js <- local_host_page()
    result <- js(
      "(() => {
      const el = document.getElementById('a'), warnings = [], original = console.warn;
      const snapshot = () => JSON.stringify({state:mascot.host.state(el),html:el.outerHTML});
      console.warn = message => warnings.push(message);
      const before = snapshot(), outcomes = [];
      for (const patch of [
        {mood:'missing',status:{mode:'custom',text:'Wrong'}},
        {mood:'happy',status:{mode:'bad'}},
        {mood:'happy',status:{mode:'custom',text:''}},
        {character:{id:'blob',name:'Blob',json:'{'},status:{mode:'custom',text:'Wrong'}},
        {character:{id:'blob',name:'Blob',json:JSON.stringify({id:'blob'})},status:{mode:'custom',text:'Wrong'}}
      ]) { mascot.host.receive({id:'a',patch}); outcomes.push(snapshot() === before); }
      console.warn = original; return {outcomes,warnings};
    })()"
    )
    expect_true(all(unlist(result$outcomes)))
    expect_length(result$warnings, 5)
    expect_true(all(startsWith(unlist(result$warnings), "mascot: ")))
  })
  it("merges late state, drops superseded moods and warns for late gestures", {
    skip_without_chrome()
    js <- local_host_page()
    result <- js(
      "(() => {
      const source = document.getElementById('a'), blob = mascot.readCharacter('blob');
      const send = (id,patch) => mascot.host.receive({id,patch});
      const add = id => {const el=source.cloneNode(true); el.id=id; document.body.append(el); mascot.host.mount(el); return el;};
      send('late',{mood:'thinking',status:{mode:'custom',text:'Waiting'}});
      send('late',{mood:'happy'}); const late = add('late');
      send('swap',{mood:'happy'});
      send('swap',{character:{id:blob.id,name:blob.name,json:JSON.stringify(blob)}}); const swap=add('swap');
      const warnings=[], original=console.warn; console.warn=message=>warnings.push(message);
      send('gesture',{gesture:'wave'}); console.warn=original; const gesture=add('gesture');
      send('problem',{mood:'happy',status:{mode:'custom',text:'Kept'}});
      send('problem',{problem:'mascot: bad mood'}); const problem=add('problem');
      send('clear',{problem:'mascot: old error'}); send('clear',{mood:'thinking'}); const clear=add('clear');
      return {late:mascot.host.state(late), text:late.querySelector('.mascot-status').textContent,
        swap:mascot.host.state(swap),first:Object.keys(blob.moods)[0],warnings,
        gesture:mascot.host.state(gesture),problem:mascot.host.state(problem),clear:mascot.host.state(clear)};
    })()"
    )
    expect_identical(result$late$current$mood, "happy")
    expect_identical(result$text, "Waiting")
    expect_identical(result$swap$current$character, "blob")
    expect_identical(result$swap$current$mood, result$first)
    expect_identical(result$gesture$current$mood, "idle")
    expect_identical(
      unlist(result$warnings),
      'mascot: gesture "wave" for "gesture" was dropped: the mascot was not on the page yet'
    )
    expect_identical(result$problem$mood, "happy")
    expect_identical(result$problem$current$mood, "worried")
    expect_identical(result$problem$status$text, "Kept")
    expect_null(result$clear$problem)
    expect_identical(result$clear$current$mood, "thinking")
  })
  it("layers problems temporarily and restores the earlier mood on recovery", {
    skip_without_chrome()
    js <- local_host_page()
    result <- js(
      "(() => {
      const el=document.getElementById('a'), send=patch=>mascot.host.receive({id:'a',patch});
      const text=()=>el.querySelector('.mascot-status').textContent, messages=[];
      window.Shiny={}; window.addEventListener('shiny:client-message', event=>messages.push(event.detail));
      send({mood:'happy',status:{mode:'custom',text:'Saved'}});
      send({problem:'mascot: invalid mood'}); const problem=mascot.host.state(el), problemText=text();
      send({problem:'mascot: another problem'});
      send({status:{mode:'mood'}}); const recovered=mascot.host.state(el), recoveredText=text();
      send({problem:'mascot: invalid again'}); send({mood:'thinking'});
      return {problem,problemText,recovered,recoveredText,last:mascot.host.state(el),messages};
    })()"
    )
    expect_identical(result$problem$current$mood, "worried")
    expect_identical(result$problemText, "mascot: invalid mood")
    expect_identical(result$recovered$current$mood, "happy")
    expect_identical(result$recoveredText, "Happy")
    expect_null(result$recovered$problem)
    expect_identical(result$last$current$mood, "thinking")
    expect_identical(
      result$messages[[1]],
      list(headline = "mascot", message = "mascot: invalid mood", status = "warning")
    )
  })
  it("destroys the controller and removes its record on unmount", {
    skip_without_chrome()
    js <- local_host_page()
    result <- js(
      "(() => {
      const el=document.getElementById('a'); mascot.host.unmount(el);
      const mount=mascot.mount; let controller;
      mascot.mount=(...args)=>{controller=mount(...args);return controller;};
      mascot.host.mount(el); mascot.mount=mount;
      mascot.host.unmount(el); mascot.host.unmount(el);
      const html=el.outerHTML, before=controller.current(); controller.update({mood:'happy'}); controller.redraw();
      return {state:mascot.host.state(el),inert:JSON.stringify(before)===JSON.stringify(controller.current()),same:html===el.outerHTML};
    })()"
    )
    expect_null(result$state)
    expect_true(result$inert)
    expect_true(result$same)
  })
  it("updates every bound element with an exact matching id and no others", {
    skip_without_chrome()
    js <- local_host_page()
    result <- js(
      "(() => {
      const first=document.getElementById('a'), duplicate=first.cloneNode(true), other=first.cloneNode(true);
      other.id='other'; document.body.append(duplicate,other); mascot.host.mount(duplicate); mascot.host.mount(other);
      mascot.host.receive({id:'a',patch:{mood:'happy'}});
      return [first,duplicate,other].map(el=>mascot.host.state(el).current.mood);
    })()"
    )
    expect_identical(unlist(result), c("happy", "happy", "idle"))
  })
})
