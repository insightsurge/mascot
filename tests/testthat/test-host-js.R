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
  it("warns once in development mode when an update misses a namespaced mascot on the page", {
    skip_without_chrome()
    js <- local_host_page()
    result <- js(
      "(async () => {
      const source = document.getElementById('a'), warnings = [], events = [], original = console.warn;
      const add = id => {const el=source.cloneNode(true); el.id=id; document.body.append(el); mascot.host.mount(el); return el;};
      console.warn = message => warnings.push(message);
      window.addEventListener('shiny:client-message', event => events.push(event.detail.message));
      add('first-helper');
      window.Shiny = {inDevMode: () => false};
      mascot.host.receive({id:'helper',patch:{mood:'happy'}});
      await new Promise(resolve => setTimeout(resolve, 2200));
      const production = warnings.length;
      window.Shiny = {inDevMode: () => true};
      mascot.host.receive({id:'helper',patch:{mood:'thinking'}});
      mascot.host.receive({id:'helper',patch:{mood:'happy'}});
      mascot.host.receive({id:'later',patch:{mood:'happy'}});
      add('summary');
      mascot.host.receive({id:'second-summary',patch:{mood:'happy'}});
      await new Promise(resolve => setTimeout(resolve, 2200));
      console.warn = original; delete window.Shiny;
      return {production, warnings, events};
    })()"
    )
    expect_identical(result$production, 0L)
    expect_length(result$warnings, 2)
    expect_match(result$warnings[[1]], 'no mascot "helper".*"first-helper".*from inside its module')
    expect_match(result$warnings[[2]], 'no mascot "second-summary".*"summary".*ns\\("summary"\\)')
    expect_identical(result$events[[1]], sub("^mascot: ", "", result$warnings[[1]]))
  })
  it("bounds the queue for an id that has not appeared and asks the server for its full state", {
    skip_without_chrome()
    js <- local_host_page()
    result <- js(
      "(() => {
      const source = document.getElementById('a');
      const add = id => {const el=source.cloneNode(true); el.id=id; document.body.append(el); mascot.host.mount(el); return el;};
      for (let i = 1; i <= 5; i++) mascot.host.receive({id:'few',patch:{mood:'thinking'},revision:i,fields:{mood:i}});
      for (let i = 1; i <= 25; i++)
        mascot.host.receive({id:'many',patch:{mood:i % 2 ? 'thinking' : 'happy'},revision:i,fields:{mood:i}});
      return {few:mascot.host.state(add('few')), many:mascot.host.state(add('many'))};
    })()"
    )
    # Within the limit the mount reports the last revision it applied; beyond it, 0 asks the server to re-send.
    expect_identical(result$few$revision, 5L)
    expect_identical(result$few$current$mood, "thinking")
    expect_identical(result$many$revision, 0L)
    expect_identical(result$many$current$mood, "thinking")
  })
  it("merges late state, drops superseded moods and keeps the latest late gesture", {
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
      const gestures=[], mount=mascot.mount;
      mascot.mount=(...args)=>{const controller=mount(...args), original=controller.gesture;
        controller.gesture=name=>{gestures.push({name,character:controller.current().character,mood:controller.current().mood});return original(name);};return controller;};
      send('gesture',{gesture:'nod'}); send('gesture',{mood:'happy',gesture:'wave'});
      const gesture=add('gesture'); mascot.mount=mount; console.warn=original;
      send('problem',{mood:'happy',status:{mode:'custom',text:'Kept'}});
      send('problem',{problem:'mascot: bad mood'}); const problem=add('problem');
      send('clear',{problem:'mascot: old error'}); send('clear',{mood:'thinking'}); const clear=add('clear');
      return {late:mascot.host.state(late), text:late.querySelector('.mascot-status').textContent,
        swap:mascot.host.state(swap),first:Object.keys(blob.moods)[0],warnings,
        gestures,gesture:mascot.host.state(gesture),problem:mascot.host.state(problem),clear:mascot.host.state(clear)};
    })()"
    )
    expect_identical(result$late$current$mood, "happy")
    expect_identical(result$text, "Waiting")
    expect_identical(result$swap$current$character, "blob")
    expect_identical(result$swap$current$mood, result$first)
    expect_identical(result$gesture$current$mood, "happy")
    expect_length(result$warnings, 0)
    expect_length(result$gestures, 1)
    expect_identical(result$gestures[[1]], list(name = "wave", character = "tessa", mood = "happy"))
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


# Control only the bubble clock; the real engine and DOM still run in Chrome.
install_bubble_clock <- function(js) {
  js(
    "(() => {
    let now = 0, next = 0;
    const timers = new Map();
    window.performance.now = () => now;
    window.setTimeout = (fn, delay) => { const id = ++next; timers.set(id, {fn, due: now + delay}); return id; };
    window.clearTimeout = id => timers.delete(id);
    window.bubbleClock = {
      advance(ms) { now += ms; },
      tick(ms) { now += ms; for (const [id,timer] of [...timers]) if (timer.due <= now) { timers.delete(id); timer.fn(); } },
      count() { return timers.size; }
    };
    return true;
  })()"
  )
}

describe("mascot.host bubbles", {
  it("starts a static bubble's timer when mounted and announces it separately", {
    skip_without_chrome()
    js <- local_host_page(bubble = mascot_bubble("Initial", duration = 5))
    js("mascot.host.unmount(document.getElementById('a'))")
    install_bubble_clock(js)
    result <- js(
      "(() => {
      const el = document.getElementById('a'); mascot.host.mount(el);
      const text = el.querySelector('.mascot-bubble-text'), close = el.querySelector('button');
      const initial = {bubble:mascot.host.state(el).bubble, status:el.querySelector('.mascot-status').textContent,
        role:el.querySelector('.mascot-bubble-region').getAttribute('role'),
        live:el.querySelector('.mascot-bubble-region').getAttribute('aria-live'), name:close.getAttribute('aria-label'),
        type:close.type, tabs:[el.querySelector('canvas').tabIndex,text.tabIndex,close.tabIndex],
        timers:bubbleClock.count(), animation:getComputedStyle(el.querySelector('.mascot-bubble')).animationName};
      bubbleClock.tick(5000);
      return {initial, expired:mascot.host.state(el).bubble, hidden:el.querySelector('.mascot-bubble').hidden,
        timers:bubbleClock.count()};
    })()"
    )
    expect_identical(result$initial$bubble$text, "Initial")
    expect_equal(result$initial$bubble$remaining, 5)
    expect_identical(result$initial$status, "Idle")
    expect_identical(result$initial$role, "status")
    expect_identical(result$initial$live, "polite")
    expect_identical(result$initial$name, "Close message")
    expect_identical(result$initial$type, "button")
    expect_equal(unlist(result$initial$tabs), c(0, -1, 0))
    expect_identical(result$initial$animation, "none")
    expect_equal(result$initial$timers, 1)
    expect_null(result$expired)
    expect_true(result$hidden)
    expect_equal(result$timers, 0)
  })
  it("creates, replaces and clears text or HTML, and keeps an infinite bubble", {
    skip_without_chrome()
    js <- local_host_page()
    install_bubble_clock(js)
    result <- js(
      "(() => {
      const el=document.getElementById('a'), send=bubble=>mascot.host.receive({id:'a',patch:{bubble}});
      send({text:'<b>Ready</b>',html:false,closable:true,duration:5});
      const plain=el.querySelector('.mascot-bubble-text').innerHTML, first=mascot.host.state(el).bubble;
      bubbleClock.advance(1000);
      send({text:'<b>New</b>',html:true,closable:false,duration:null});
      const html=el.querySelector('.mascot-bubble-text').innerHTML, second=mascot.host.state(el).bubble,
        buttons=el.querySelectorAll('.mascot-bubble button').length, timers=bubbleClock.count();
      bubbleClock.tick(100000);
      const stays=mascot.host.state(el).bubble;
      send({clear:true});
      return {plain,first,html,second,buttons,timers,stays,cleared:mascot.host.state(el).bubble,
        hidden:el.querySelector('.mascot-bubble').hidden,empty:el.querySelector('.mascot-bubble-text').textContent};
    })()"
    )
    expect_identical(result$plain, "&lt;b&gt;Ready&lt;/b&gt;")
    expect_false(result$first$html)
    expect_identical(result$html, "<b>New</b>")
    expect_true(result$second$html)
    expect_false(result$second$closable)
    expect_null(result$second$remaining)
    expect_equal(result$buttons, 0)
    expect_equal(result$timers, 0)
    expect_identical(result$stays, result$second)
    expect_null(result$cleared)
    expect_true(result$hidden)
    expect_identical(result$empty, "")
  })
  it("pauses on pointer and mascot focus, resuming only the remaining time", {
    skip_without_chrome()
    js <- local_host_page()
    install_bubble_clock(js)
    result <- js(
      "(() => {
      const el=document.getElementById('a'), bubble=el.querySelector('.mascot-bubble'), canvas=el.querySelector('canvas');
      mascot.host.receive({id:'a',patch:{bubble:{text:'Timed',html:false,closable:true,duration:5}}});
      bubbleClock.advance(2000);
      bubble.dispatchEvent(new PointerEvent('pointerover',{bubbles:true}));
      bubbleClock.tick(10000); const hovered=mascot.host.state(el).bubble.remaining;
      canvas.focus(); bubble.dispatchEvent(new PointerEvent('pointerout',{bubbles:true}));
      bubbleClock.tick(10000); const focused=mascot.host.state(el).bubble.remaining, paused=bubbleClock.count();
      const outside=document.createElement('button'); document.body.append(outside); outside.focus();
      bubbleClock.tick(2999); const alive=mascot.host.state(el).bubble.remaining;
      bubbleClock.tick(1);
      return {hovered,focused,paused,alive,expired:mascot.host.state(el).bubble,timers:bubbleClock.count()};
    })()"
    )
    expect_equal(result$hovered, 3)
    expect_equal(result$focused, 3)
    expect_equal(result$paused, 0)
    expect_equal(result$alive, 0.001, tolerance = 1e-8)
    expect_null(result$expired)
    expect_equal(result$timers, 0)
  })
  it("closes on Esc or the button, returns focus, and never reopens on mood changes", {
    skip_without_chrome()
    js <- local_host_page()
    result <- js(
      "(() => {
      const el=document.getElementById('a'), send=patch=>mascot.host.receive({id:'a',patch}),
        bubble={text:'Ready',html:false,closable:true,duration:null};
      send({bubble}); const button=el.querySelector('button'); button.focus(); button.click();
      const closed=mascot.host.state(el).bubble, focus=document.activeElement === el;
      send({mood:'happy'}); const afterMood=mascot.host.state(el).bubble;
      send({bubble:{...bubble,closable:false}}); const reopened=mascot.host.state(el).bubble;
      el.focus();
      el.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true}));
      return {closed,focus,afterMood,reopened,esc:mascot.host.state(el).bubble,
        lastFocus:document.activeElement === el};
    })()"
    )
    expect_null(result$closed)
    expect_true(result$focus)
    expect_null(result$afterMood)
    expect_identical(result$reopened$text, "Ready")
    expect_null(result$esc)
    expect_true(result$lastFocus)
  })
  it("keeps the bubble through moods and animated swaps, applying a gesture after the update", {
    skip_without_chrome()
    js <- local_host_page(reduced = FALSE)
    result <- js(
      "(() => {
      const el=document.getElementById('a'); mascot.host.unmount(el);
      const mount=mascot.mount, calls=[];
      mascot.mount=(...args)=>{
        const controller=mount(...args), update=controller.update, gesture=controller.gesture;
        controller.update=patch=>{calls.push('update'); return update(patch);};
        controller.gesture=name=>{calls.push(name); return gesture(name);};
        return controller;
      };
      mascot.host.mount(el); mascot.mount=mount;
      const send=patch=>mascot.host.receive({id:'a',patch});
      send({bubble:{text:'Kept',html:false,closable:true,duration:null}});
      send({mood:'happy',gesture:'nod'}); const mood=mascot.host.state(el);
      const blob=mascot.readCharacter('blob');
      send({character:{id:blob.id,name:blob.name,json:JSON.stringify(blob)},gesture:'wave'});
      return {mood,swap:mascot.host.state(el),calls,text:el.querySelector('.mascot-bubble-text').textContent};
    })()"
    )
    expect_identical(result$mood$bubble$text, "Kept")
    expect_identical(result$mood$current$mood, "happy")
    expect_identical(result$swap$bubble, result$mood$bubble)
    expect_true(result$swap$current$swapping)
    expect_identical(result$text, "Kept")
    expect_identical(unlist(result$calls), c("update", "nod", "update", "wave"))
  })
  it("rejects unknown gestures and malformed bubbles without committing any field", {
    skip_without_chrome()
    js <- local_host_page()
    result <- js(
      "(() => {
      const el=document.getElementById('a'), warnings=[], old=console.warn;
      console.warn=message=>warnings.push(message);
      const before=JSON.stringify({state:mascot.host.state(el),html:el.outerHTML}), outcomes=[];
      const bubble={text:'Wrong',html:false,closable:true,duration:null};
      for (const patch of [
        {mood:'happy',bubble,gesture:'jump'}, {mood:'happy',bubble,gesture:'toString'},
        {mood:'happy',bubble,gesture:null}, {mood:'happy',bubble:{...bubble,duration:0}},
        {mood:'happy',bubble:{...bubble,html:'yes'}}, {mood:'happy',bubble:{clear:true,text:'wrong'}},
        {mood:'missing',bubble}, {mood:'happy',bubble:{...bubble,typo:true}}
      ]) {
        mascot.host.receive({id:'a',patch});
        outcomes.push(before === JSON.stringify({state:mascot.host.state(el),html:el.outerHTML}));
      }
      console.warn=old; return {outcomes,warnings};
    })()"
    )
    expect_true(all(unlist(result$outcomes)))
    expect_length(result$warnings, 8)
    expect_match(result$warnings[[1]], "unknown gesture")
  })
  it("queues the latest bubble, starts its lifetime on appearance, and keeps gestures", {
    skip_without_chrome()
    js <- local_host_page()
    install_bubble_clock(js)
    result <- js(
      "(() => {
      const warnings=[], old=console.warn; console.warn=message=>warnings.push(message);
      const send=patch=>mascot.host.receive({id:'late',patch});
      send({bubble:{text:'Old',html:false,closable:true,duration:1},gesture:'nod'});
      send({bubble:{text:'Latest',html:false,closable:false,duration:5}});
      send({mood:'happy'}); bubbleClock.tick(10000);
      mascot.host.receive({id:'invalid-late',patch:{mood:'happy',gesture:'jump'}});
      const invalid=document.getElementById('a').cloneNode(true); invalid.id='invalid-late'; document.body.append(invalid); mascot.host.mount(invalid);
      const el=document.getElementById('a').cloneNode(true); el.id='late'; document.body.append(el); mascot.host.mount(el);
      console.warn=old; const initial=mascot.host.state(el), timers=bubbleClock.count();
      bubbleClock.tick(5000);
      mascot.host.receive({id:'clear-late',patch:{bubble:{text:'Old',html:false,closable:true,duration:5}}});
      mascot.host.receive({id:'clear-late',patch:{bubble:{clear:true}}});
      const cleared=document.getElementById('a').cloneNode(true); cleared.id='clear-late'; document.body.append(cleared); mascot.host.mount(cleared);
      return {initial,timers,warnings,invalid:mascot.host.state(invalid),expired:mascot.host.state(el).bubble,cleared:mascot.host.state(cleared).bubble};
    })()"
    )
    expect_identical(result$initial$bubble$text, "Latest")
    expect_equal(result$initial$bubble$remaining, 5)
    expect_identical(result$initial$current$mood, "happy")
    expect_equal(result$timers, 1)
    # Queued patches are validated when their mascot mounts, so the warnings follow mount order: compare as a set.
    warnings <- unlist(result$warnings)
    expect_length(warnings, 1)
    expect_true(any(grepl("unknown gesture", warnings)))
    expect_identical(result$invalid$current$mood, "idle")
    expect_null(result$expired)
    expect_null(result$cleared)
  })
  it("clears timers and element listeners on unmount", {
    skip_without_chrome()
    js <- local_host_page()
    install_bubble_clock(js)
    result <- js(
      "(() => {
      const el=document.getElementById('a');
      mascot.host.receive({id:'a',patch:{bubble:{text:'Ready',html:false,closable:true,duration:5}}});
      const active=bubbleClock.count(); mascot.host.unmount(el); const html=el.outerHTML;
      el.querySelector('.mascot-bubble-close').click();
      el.querySelector('canvas').focus();
      el.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true}));
      bubbleClock.tick(10000);
      return {active,timers:bubbleClock.count(),state:mascot.host.state(el),same:html === el.outerHTML};
    })()"
    )
    expect_equal(result$active, 1)
    expect_equal(result$timers, 0)
    expect_null(result$state)
    expect_true(result$same)
  })
})


describe("mascot.host bubble layout", {
  it("R4 reserves the same mascot and status positions through message changes in either theme", {
    skip_without_chrome()
    js <- local_host_page()
    result <- js(
      "(() => {
      const el=document.getElementById('a'), status=el.querySelector('.mascot-status'), canvas=el.querySelector('canvas');
      const rect=node=>{const {x,y,width,height}=node.getBoundingClientRect(); return {x,y,width,height};};
      const bounds=()=>({mascot:rect(el),status:rect(status)}), outcomes=[];
      for(const theme of ['light','dark']) {
        document.documentElement.setAttribute('data-bs-theme',theme); const before=bounds();
        mascot.host.receive({id:'a',patch:{bubble:{text:'Saved',html:false,closable:true,duration:null}}});
        const shown=bounds();
        mascot.host.receive({id:'a',patch:{bubble:{text:'A long message with details. '.repeat(50),html:false,closable:true,duration:null}}});
        const long=bounds(), bubble=el.querySelector('.mascot-bubble'), text=el.querySelector('.mascot-bubble-text'),
          box=bubble.getBoundingClientRect(), css=getComputedStyle(text);
        const readable={wrapped:text.scrollHeight > text.clientHeight,scrolls:css.overflowY === 'auto',
          inside:box.top >= el.getBoundingClientRect().top,above:box.bottom < canvas.getBoundingClientRect().top,
          width:box.width,max:parseFloat(getComputedStyle(bubble).maxWidth),
          buttonVisible:el.querySelector('button').getBoundingClientRect().bottom <= box.bottom};
        el.querySelector('button').click(); const closed=bounds();
        mascot.host.receive({id:'a',patch:{bubble:{text:'Again',html:false,closable:false,duration:null}}});
        const reopened=bounds(); mascot.host.receive({id:'a',patch:{bubble:{clear:true}}});
        outcomes.push({before,shown,long,closed,reopened,cleared:bounds(),readable,canvasTab:canvas.tabIndex});
      }
      return outcomes;
    })()"
    )
    for (outcome in result) {
      for (stage in c("shown", "long", "closed", "reopened", "cleared")) {
        expect_identical(outcome[[stage]], outcome$before, info = stage)
      }
      expect_true(outcome$readable$wrapped)
      expect_true(outcome$readable$scrolls)
      expect_true(outcome$readable$inside)
      expect_true(outcome$readable$above)
      expect_true(outcome$readable$buttonVisible)
      expect_lte(outcome$readable$width, outcome$readable$max)
      expect_equal(outcome$canvasTab, 0)
    }
  })
  it("wraps long text above the canvas and status in the page's light and dark colours", {
    skip_without_chrome()
    js <- local_host_page(bubble = mascot_bubble(paste(rep("long-message", 30), collapse = " "), Inf))
    result <- js(
      "(() => {
      const el=document.getElementById('a'), bubble=el.querySelector('.mascot-bubble');
      const bounds=bubble.getBoundingClientRect(), canvas=el.querySelector('canvas').getBoundingClientRect(),
        status=el.querySelector('.mascot-status').getBoundingClientRect(), light=getComputedStyle(bubble);
      const initial={background:light.backgroundColor,colour:light.color,border:light.borderTopColor,
        wraps:bounds.height > parseFloat(light.fontSize)*2,width:bounds.width,max:parseFloat(light.maxWidth),
        above:bounds.bottom < canvas.top,statusBelow:canvas.bottom < status.top};
      el.setAttribute('data-bs-theme','dark');
      el.style.setProperty('--bs-body-bg','#212529'); el.style.setProperty('--bs-body-color','#f8f9fa');
      el.style.setProperty('--bs-border-color','#495057');
      const dark=getComputedStyle(bubble);
      return {initial,dark:{background:dark.backgroundColor,colour:dark.color,border:dark.borderTopColor}};
    })()"
    )
    expect_identical(result$initial$background, "rgb(255, 255, 255)")
    expect_identical(result$initial$colour, "rgb(33, 37, 41)")
    expect_identical(result$initial$border, "rgb(222, 226, 230)")
    expect_true(result$initial$wraps)
    expect_lte(result$initial$width, result$initial$max)
    expect_true(result$initial$above)
    expect_true(result$initial$statusBelow)
    expect_identical(result$dark$background, "rgb(33, 37, 41)")
    expect_identical(result$dark$colour, "rgb(248, 249, 250)")
    expect_identical(result$dark$border, "rgb(73, 80, 87)")
  })
})

describe("host review regressions", {
  it("R1 validates against each target's mood set in either unrelated mount order", {
    skip_without_chrome()
    js <- local_host_page()
    result <- js(
      "(() => {
      const source=document.getElementById('a'), tessa=mascot.readCharacter('tessa'), warnings=[], old=console.warn;
      const trim=JSON.parse(JSON.stringify(tessa)); trim.id='idle-only'; trim.name='Idle only'; trim.moods={idle:trim.moods.idle};
      const add=(id,ch)=>{const el=source.cloneNode(true); el.id=id; el.dataset.character=ch.id; el.dataset.mood='idle';
        el.querySelectorAll('script').forEach(script=>script.remove());
        const script=document.createElement('script'); script.type='application/json'; script.dataset.mascotCharacter=ch.id;
        script.textContent=JSON.stringify(ch); el.append(script); document.body.append(el); mascot.host.mount(el); return el;};
      const send=(id,patch)=>mascot.host.receive({id,patch}), bubble=text=>({text,html:false,closable:true,duration:null});
      console.warn=message=>warnings.push(message);
      const outcomes=[];
      for(const [i,order] of [[tessa,trim],[trim,tessa]].entries()) {
        order.forEach((ch,j)=>add('unrelated-'+i+'-'+j,ch));
        send('good-'+i,{mood:'happy',bubble:bubble('Good')});
        send('bad-'+i,{bubble:bubble('Kept')});
        send('bad-'+i,{mood:'happy',bubble:bubble('Wrong')}); send('bad-'+i,{mood:'idle'});
        const good=add('good-'+i,tessa), bad=add('bad-'+i,trim);
        send('pending-'+i,{character:{id:trim.id,name:trim.name,json:JSON.stringify(trim)}});
        send('pending-'+i,{mood:'happy',bubble:bubble('Wrong')}); send('pending-'+i,{mood:'idle'});
        const pending=add('pending-'+i,tessa);
        const known=add('known-'+i,trim); mascot.host.unmount(known); known.remove();
        add('last-'+i,tessa); send('known-'+i,{mood:'happy',bubble:bubble('Wrong')});
        const remounted=add('known-'+i,trim);
        outcomes.push({good:mascot.host.state(good),bad:mascot.host.state(bad),
          pending:mascot.host.state(pending),known:mascot.host.state(remounted)});
      }
      console.warn=old; return {outcomes,warnings};
    })()"
    )
    expect_length(result$warnings, 6)
    expect_true(all(grepl("unknown mood", unlist(result$warnings), fixed = TRUE)))
    for (outcome in result$outcomes) {
      expect_identical(outcome$good$mood, "happy")
      expect_identical(outcome$good$bubble$text, "Good")
      expect_identical(outcome$bad$mood, "idle")
      expect_identical(outcome$bad$bubble$text, "Kept")
      expect_identical(outcome$pending$character, "idle-only")
      expect_null(outcome$pending$bubble)
      expect_identical(outcome$known$mood, "idle")
      expect_null(outcome$known$bubble)
    }
  })
  it("A1 consumes Escape only when it closes a bubble", {
    skip_without_chrome()
    js <- local_host_page(bubble = mascot_bubble("Ready", Inf))
    result <- js(
      "(() => {
      const el=document.getElementById('a'), container=document.createElement('div'), events=[];
      document.body.append(container); container.append(el);
      container.addEventListener('keydown', event=>{if(event.key === 'Escape') events.push(event.key);});
      el.querySelector('canvas').focus();
      const first=new KeyboardEvent('keydown',{key:'Escape',bubbles:true,cancelable:true});
      el.querySelector('canvas').dispatchEvent(first); const closed=mascot.host.state(el).bubble, seen=events.length;
      const second=new KeyboardEvent('keydown',{key:'Escape',bubbles:true,cancelable:true});
      el.querySelector('canvas').dispatchEvent(second);
      return {closed,seen,total:events.length,firstPrevented:first.defaultPrevented,secondPrevented:second.defaultPrevented};
    })()"
    )
    expect_null(result$closed)
    expect_equal(result$seen, 0)
    expect_equal(result$total, 1)
    expect_true(result$firstPrevented)
    expect_false(result$secondPrevented)
  })
  it("A2 drops each invalid queued patch whole before later updates can revive its bubble", {
    skip_without_chrome()
    js <- local_host_page()
    result <- js(
      "(() => {
      const source=document.getElementById('a'), warnings=[], old=console.warn;
      console.warn=message=>warnings.push(message);
      const bubble={text:'Wrong',html:false,closable:true,duration:null}, outcomes=[];
      const patches=[{mood:'missing',bubble},{status:{mode:'bad'},bubble},{typo:true,bubble},
        {character:{id:'bad',name:'Bad',json:'{'},bubble},
        {character:{id:'bad',name:'Bad',json:JSON.stringify({id:'bad'})},bubble}];
      for(const [i,patch] of patches.entries()) {
        const id='late-'+i;
        mascot.host.receive({id,patch}); mascot.host.receive({id,patch:{mood:'happy'}});
        const el=source.cloneNode(true); el.id=id; document.body.append(el); mascot.host.mount(el);
        outcomes.push({mood:mascot.host.state(el).mood,bubble:mascot.host.state(el).bubble});
      }
      mascot.host.receive({id:'kept',patch:{bubble:{...bubble,text:'Kept'}}});
      mascot.host.receive({id:'kept',patch:{mood:'missing',bubble}});
      mascot.host.receive({id:'kept',patch:{mood:'happy'}});
      const kept=source.cloneNode(true); kept.id='kept'; document.body.append(kept); mascot.host.mount(kept);
      console.warn=old;
      return {outcomes,warnings,kept:mascot.host.state(kept).bubble};
    })()"
    )
    expect_length(result$warnings, 6)
    expect_match(result$warnings[[1]], "unknown mood")
    for (outcome in result$outcomes) {
      expect_identical(outcome$mood, "happy")
      expect_null(outcome$bubble)
    }
    expect_identical(result$kept$text, "Kept")
  })
  it("A3 follows explicit dark and light themes without Bootstrap variables", {
    skip_without_chrome()
    js <- local_host_page(bubble = mascot_bubble("Ready", Inf))
    result <- js(
      "(() => {
      const el=document.getElementById('a'), bubble=el.querySelector('.mascot-bubble');
      const colours=()=>{const css=getComputedStyle(bubble),tail=getComputedStyle(bubble,'::after');
        return {background:css.backgroundColor,colour:css.color,border:css.borderTopColor,tail:tail.backgroundColor};};
      document.documentElement.setAttribute('data-bs-theme','dark'); const dark=colours();
      el.setAttribute('data-bs-theme','light'); const light=colours();
      return {dark,light};
    })()"
    )
    expect_identical(result$dark$background, "rgb(33, 37, 41)")
    expect_identical(result$dark$colour, "rgb(248, 249, 250)")
    expect_identical(result$dark$border, "rgb(73, 80, 87)")
    expect_identical(result$dark$tail, result$dark$background)
    expect_identical(result$light$background, "rgb(255, 255, 255)")
  })
  it("A3 colours the bubble from the page's signal, never from the system preference alone", {
    skip_without_chrome()
    js <- local_host_page(bubble = mascot_bubble("Ready", Inf), scheme = "dark")
    result <- js(
      "(() => {
      const bubble=document.querySelector('#a .mascot-bubble'), bg=()=>getComputedStyle(bubble).backgroundColor;
      const none=bg();
      document.body.setAttribute('data-bs-theme','dark'); const bootstrap=bg();
      document.body.removeAttribute('data-bs-theme'); document.body.classList.add('quarto-dark'); const quarto=bg();
      document.body.classList.remove('quarto-dark'); document.documentElement.setAttribute('data-bs-theme','light');
      return {none,bootstrap,quarto,rootLight:bg()};
    })()"
    )
    # A dark system setting alone keeps the light bubble, matching the drawing's "no signal means light".
    expect_identical(result$none, "rgb(255, 255, 255)")
    expect_identical(result$bootstrap, "rgb(33, 37, 41)")
    expect_identical(result$quarto, "rgb(33, 37, 41)")
    expect_identical(result$rootLight, "rgb(255, 255, 255)")
  })
  it("G3 skips static text in tab order and still pauses while the close button has focus", {
    skip_without_chrome()
    js <- local_host_page()
    install_bubble_clock(js)
    result <- js(
      "(() => {
      const el=document.getElementById('a');
      mascot.host.receive({id:'a',patch:{bubble:{text:'Ready',html:false,closable:true,duration:5}}});
      const text=el.querySelector('.mascot-bubble-text'), button=el.querySelector('button');
      bubbleClock.advance(2000); button.focus(); bubbleClock.tick(10000);
      return {textTab:text.hasAttribute('tabindex'),textIndex:text.tabIndex,buttonIndex:button.tabIndex,
        remaining:mascot.host.state(el).bubble.remaining,timers:bubbleClock.count()};
    })()"
    )
    expect_false(result$textTab)
    expect_equal(result$textIndex, -1)
    expect_equal(result$buttonIndex, 0)
    expect_equal(result$remaining, 3)
    expect_equal(result$timers, 0)
  })
  it("G4 focuses the mascot only when closing would remove the focused bubble content", {
    skip_without_chrome()
    js <- local_host_page()
    result <- js(
      "(() => {
      const el=document.getElementById('a'), outside=document.createElement('button'); document.body.append(outside);
      const send=bubble=>mascot.host.receive({id:'a',patch:{bubble}}),
        bubble={text:'Ready',html:false,closable:true,duration:null};
      send(bubble); el.querySelector('button').focus(); el.querySelector('button').click();
      const buttonFocus=document.activeElement === el, rootIndex=el.tabIndex;
      send(bubble); outside.focus(); send({clear:true}); const outsideFocus=document.activeElement === outside;
      send(bubble); el.querySelector('canvas').focus();
      el.querySelector('canvas').dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true}));
      const canvasFocus=document.activeElement === el.querySelector('canvas');
      send({...bubble,text:'<a href=\"#ready\">Ready</a>',html:true}); el.querySelector('a').focus();
      el.querySelector('a').dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true}));
      const linkFocus=document.activeElement === el;
      send(bubble); el.querySelector('button').focus(); send({...bubble,text:'New'});
      return {buttonFocus,rootIndex,outsideFocus,canvasFocus,linkFocus,replaceFocus:document.activeElement === el};
    })()"
    )
    expect_true(result$buttonFocus)
    expect_equal(result$rootIndex, -1)
    expect_true(result$outsideFocus)
    expect_true(result$canvasFocus)
    expect_true(result$linkFocus)
    expect_true(result$replaceFocus)
  })
  it("G5 keeps the close button at least 24 by 24 CSS pixels at a small font size", {
    skip_without_chrome()
    js <- local_host_page(bubble = mascot_bubble("Ready", Inf))
    result <- js(
      "(() => {
      const el=document.getElementById('a'); el.style.fontSize='8px';
      const initial=el.querySelector('.mascot-bubble-close').getBoundingClientRect();
      mascot.host.receive({id:'a',patch:{bubble:{text:'New',html:false,closable:true,duration:null}}});
      const replaced=el.querySelector('.mascot-bubble-close').getBoundingClientRect();
      return [initial,replaced].map(rect=>({width:rect.width,height:rect.height}));
    })()"
    )
    for (size in result) {
      expect_gte(size$width, 24)
      expect_gte(size$height, 24)
    }
  })
  it("puts the close button in the bubble's top-right corner, clear of the text", {
    skip_without_chrome()
    js <- local_host_page(bubble = mascot_bubble(paste(rep("A longer message that wraps.", 3), collapse = " "), Inf))
    result <- js(
      "(() => {
      const el=document.getElementById('a'), bubble=el.querySelector('.mascot-bubble').getBoundingClientRect();
      const button=el.querySelector('.mascot-bubble-close').getBoundingClientRect();
      const text=el.querySelector('.mascot-bubble-text').getBoundingClientRect();
      return {top:button.top-bubble.top, right:bubble.right-button.right, bottom:bubble.bottom-button.bottom,
        overlap:text.right > button.left && text.top < button.bottom};
    })()"
    )
    # Near the top and right edges, well away from the bottom (the text wraps over several lines).
    expect_lt(result$top, 12)
    expect_lt(result$right, 12)
    expect_gt(result$bottom, 24)
    expect_false(result$overlap)
  })
})


describe("mascot.host responsive size", {
  it("uses the parent's content width, follows resizing and floors percentages at 24 pixels", {
    skip_without_chrome()
    js <- local_host_page(size = "20%")
    js(
      "window.el = document.getElementById('a'); window.parentBox = document.createElement('div');
      parentBox.style.cssText = 'width:500px;padding:20px;border:2px solid;box-sizing:border-box';
      el.before(parentBox); parentBox.append(el);"
    )
    # The parent's content width is 500 - 40 padding - 4 border = 456.
    expect_equal(
      host_layout(js, "return el.querySelector('canvas').getBoundingClientRect().width;"),
      91.2,
      tolerance = 0.03
    )
    js("parentBox.style.width = '300px'")
    expect_equal(
      host_layout(js, "return el.querySelector('canvas').getBoundingClientRect().width;"),
      51.2,
      tolerance = 0.03
    )
    js("parentBox.style.width = '100px'")
    result <- host_layout(
      js,
      "return {css:el.querySelector('canvas').getBoundingClientRect().width,
      backing:el.querySelector('canvas').width};"
    )
    expect_equal(result$css, 24)
    expect_equal(result$backing, 24)
  })
  it("keeps a usable backing size while hidden and redraws at double density on return", {
    skip_without_chrome()
    js <- local_host_page(size = "20%", viewport = c(800, 800), density = 2)
    js(
      "window.el = document.getElementById('a'); window.box = document.createElement('div');
      box.style.width = '400px'; el.before(box); box.append(el);"
    )
    expect_equal(host_layout(js, "return el.querySelector('canvas').width;"), 160)
    js("box.style.display = 'none'; box.style.width = '600px'")
    expect_equal(host_layout(js, "return el.querySelector('canvas').width;"), 160)
    js("box.style.display = 'block'")
    result <- host_layout(
      js,
      "const c=el.querySelector('canvas'); return {css:c.getBoundingClientRect().width,
      backing:c.width, transform:c.getContext('2d').getTransform().a};"
    )
    expect_equal(result$css, 120)
    expect_equal(result$backing, 240)
    expect_equal(result$transform, 240 / 300, tolerance = 1e-6)
    # Also mount a fresh element inside an initially hidden container.
    js(
      "window.late = el.cloneNode(true); late.id='hidden'; box.style.display='none'; box.append(late);
      mascot.host.mount(late)"
    )
    expect_equal(host_layout(js, "return late.querySelector('canvas').width;"), 320)
    js("box.style.display='block'")
    expect_equal(host_layout(js, "return late.querySelector('canvas').width;"), 240)
  })
  it("uses the CSS narrow-screen breakpoint and preserves the controller when density changes", {
    skip_without_chrome()
    js <- local_host_page(size = mascot_size(120, 48), viewport = c(576, 800))
    expect_equal(host_layout(js, "return document.querySelector('canvas').getBoundingClientRect().width;"), 120)
    session <- attr(js, "session")
    session$Emulation$setDeviceMetricsOverride(width = 575L, height = 800L, deviceScaleFactor = 1, mobile = FALSE)
    expect_equal(host_layout(js, "return document.querySelector('canvas').getBoundingClientRect().width;"), 48)
    js(
      "window.mountCount=0; const originalMount=mascot.mount;
      mascot.mount=(...args)=>{mountCount++;return originalMount(...args);};
      mascot.host.receive({id:'a',patch:{mood:'happy'}})"
    )
    session$Emulation$setDeviceMetricsOverride(width = 800L, height = 800L, deviceScaleFactor = 2, mobile = FALSE)
    result <- host_layout(
      js,
      "return {width:document.querySelector('canvas').width, mounts:mountCount,
      mood:mascot.host.state(document.getElementById('a')).current.mood};"
    )
    expect_equal(result$width, 240)
    expect_equal(result$mounts, 0)
    expect_identical(result$mood, "happy")
  })
  it("draws the full character at every size, with no small-size pose", {
    skip_without_chrome()
    js <- local_host_page()
    js(
      "window.poses=[]; const draw=mascot.draw;
      mascot.draw=(ctx,ch,options)=>{poses.push(options.pose);return draw(ctx,ch,options);};
      window.resizeTo = size => mascot.host.receive({id:'a',patch:{size:{size,small_screen:null}}});"
    )
    # Each size changes the backing canvas, so each one redraws.
    for (size in c(48, 32, 24, 71, 160)) {
      js(sprintf("poses.length=0; resizeTo(%s)", size))
      result <- host_layout(
        js,
        "const el=document.getElementById('a');
        return {drawn:poses.length>0, detail:poses.some(p=>Object.hasOwn(p,'detail')),
        state:Object.hasOwn(mascot.host.state(el),'detail'),
        attribute:el.hasAttribute('data-simplify-when-small')};"
      )
      expect_true(result$drawn, info = paste(size, "px"))
      expect_false(result$detail, info = paste(size, "px"))
      expect_false(result$state, info = paste(size, "px"))
      expect_false(result$attribute, info = paste(size, "px"))
    }
  })
})


describe("mascot.host floating placement", {
  it("pins all four corners, sizes against the window and opens bubbles towards the centre in both themes", {
    skip_without_chrome()
    for (scheme in c("light", "dark")) {
      js <- local_host_page(
        size = "20%",
        placement = "bottom-right",
        viewport = c(800, 800),
        scheme = scheme,
        bubble = mascot_bubble("Ready", Inf)
      )
      # The page, not the system preference, makes the bubble dark.
      if (scheme == "dark") {
        js("document.documentElement.dataset.bsTheme='dark'")
      }
      for (corner in c("top-left", "top-right", "bottom-left", "bottom-right")) {
        js(sprintf(
          "mascot.host.receive({id:'a',patch:{placement:{floating:true,position:'%s',minimise:false,drag:false}}})",
          corner
        ))
        result <- host_layout(
          js,
          "const el=document.getElementById('a'), r=el.getBoundingClientRect(),
          b=el.querySelector('.mascot-bubble').getBoundingClientRect();
          return {x:r.x,y:r.y,right:innerWidth-r.right,bottom:innerHeight-r.bottom,
          size:el.querySelector('canvas').getBoundingClientRect().width,
          bubbleTop:b.top,bubbleBottom:b.bottom,mascotTop:r.top,mascotBottom:r.bottom,
          bubbleLeft:b.left,bubbleRight:b.right, bg:getComputedStyle(el.querySelector('.mascot-bubble')).backgroundColor};"
        )
        expect_equal(result$size, 160)
        if (grepl("left", corner)) {
          expect_equal(result$x, 16)
        } else {
          expect_equal(result$right, 16)
        }
        if (grepl("top", corner)) {
          expect_equal(result$y, 16)
          expect_gt(result$bubbleTop, result$mascotBottom)
        } else {
          expect_equal(result$bottom, 16)
          expect_lt(result$bubbleBottom, result$mascotTop)
        }
        expect_gte(result$bubbleLeft, 0)
        expect_lte(result$bubbleRight, 800)
        expect_identical(result$bg, if (scheme == "light") "rgb(255, 255, 255)" else "rgb(33, 37, 41)")
      }
    }
  })
  it("moves above a live Shiny notification panel, follows its height and returns when it clears", {
    skip_without_chrome()
    js <- local_host_page(placement = "bottom-right", viewport = c(800, 800))
    js(
      "window.panel=document.createElement('div');panel.id='shiny-notification-panel';
      panel.style.cssText='position:fixed;bottom:0;right:0;width:250px';
      panel.innerHTML='<div style=\"height:100px\">Notice</div>';document.body.append(panel)"
    )
    result <- host_layout(
      js,
      "return {bottom:document.getElementById('a').getBoundingClientRect().bottom,
      panel:panel.getBoundingClientRect().top};"
    )
    expect_equal(result$bottom, result$panel - 16)
    js("panel.firstChild.style.height='150px'")
    expect_equal(host_layout(js, "return document.getElementById('a').getBoundingClientRect().bottom;"), 634)
    js("panel.firstChild.hidden=true")
    expect_equal(host_layout(js, "return document.getElementById('a').getBoundingClientRect().bottom;"), 784)
    js("panel.remove()")
    expect_equal(host_layout(js, "return document.getElementById('a').getBoundingClientRect().bottom;"), 784)
  })
  it("minimises with a native control, retains updates and messages, and restores without remounting", {
    skip_without_chrome()
    js <- local_host_page(
      placement = mascot_placement("bottom-right", minimise = TRUE),
      bubble = mascot_bubble("Before", Inf)
    )
    js(
      "window.el=document.getElementById('a');window.mountCount=0;const mount=mascot.mount;
      mascot.mount=(...args)=>{mountCount++;return mount(...args);}; el.querySelector('.mascot-minimise').click();
      mascot.host.receive({id:'a',patch:{mood:'happy',size:{size:64,small_screen:null},
      bubble:{text:'While minimised',html:false,duration:0.01,closable:true}}})"
    )
    result <- host_layout(
      js,
      "const s=mascot.host.state(el), button=el.querySelector('.mascot-restore');
      return {minimised:s.minimised,bubble:s.bubble.text,remaining:s.bubble.remaining,
      current:s.current.mood,canvas:el.querySelector('canvas').hidden,focused:document.activeElement===button,
      label:button.getAttribute('aria-label'),colour:getComputedStyle(button).backgroundColor,
      status:el.querySelector('.mascot-status').textContent};"
    )
    expect_true(result$minimised)
    expect_true(result$canvas)
    expect_true(result$focused)
    expect_identical(result$bubble, "While minimised")
    expect_equal(result$remaining, 0.01)
    expect_identical(result$current, "happy")
    expect_match(result$label, "Tessa, happy", fixed = TRUE)
    expect_identical(result$status, "Happy")
    expect_identical(result$colour, "rgb(63, 138, 102)")
    js("el.querySelector('.mascot-restore').click()")
    result <- host_layout(
      js,
      "return {minimised:mascot.host.state(el).minimised,
      css:el.querySelector('canvas').getBoundingClientRect().width,
      focused:document.activeElement===el.querySelector('.mascot-minimise'),mounts:mountCount};"
    )
    expect_false(result$minimised)
    expect_true(result$focused)
    expect_equal(result$css, 64)
    expect_equal(result$mounts, 0)
    js(
      "el.querySelector('.mascot-minimise').click();mascot.host.receive({id:'a',patch:{placement:{
      floating:false,position:'bottom-right',minimise:false,drag:false}}})"
    )
    expect_false(host_layout(js, "return mascot.host.state(el).minimised;"))
    expect_identical(js("getComputedStyle(el).position"), "relative")
    expect_true(js("document.activeElement===el.querySelector('canvas')"))
  })
  it("rejects malformed layout patches atomically, including queued ones", {
    skip_without_chrome()
    js <- local_host_page()
    result <- js(
      "(() => {const el=document.getElementById('a'), before=JSON.stringify(mascot.host.state(el));
      const warnings=[]; console.warn=x=>warnings.push(x);
      for(const bad of [{size:23,small_screen:null}, {size:'0%',small_screen:null},
        {size:48,small_screen:null,simplify_when_small:true}])
        mascot.host.receive({id:'a',patch:{size:bad,mood:'happy'}});
      mascot.host.receive({id:'a',patch:{placement:{floating:false,position:'top-left',minimise:false,drag:false},mood:'happy'}});
      mascot.host.receive({id:'late-layout',patch:{size:{size:1,small_screen:null},mood:'happy'}});
      mascot.host.receive({id:'late-layout',patch:{size:{size:48,small_screen:null},
        placement:{floating:true,position:'top-left',minimise:false,drag:false}}});
      const next=el.cloneNode(true);next.id='late-layout';document.body.append(next);mascot.host.mount(next);
      return {same:before===JSON.stringify(mascot.host.state(el)), warnings:warnings.length,
        mood:mascot.host.state(next).mood,size:mascot.host.state(next).size.size,
        corner:mascot.host.state(next).placement.position};})()"
    )
    expect_true(result$same)
    expect_equal(result$warnings, 5)
    expect_identical(result$mood, "idle")
    expect_equal(result$size, 48)
    expect_identical(result$corner, "top-left")
  })
  it("observes notification size only while a bottom-right floating mascot needs it", {
    skip_without_chrome()
    js <- local_host_page()
    result <- js(
      "(() => {const el=document.getElementById('a');mascot.host.unmount(el);
      const panel=document.createElement('div');panel.id='shiny-notification-panel';
      panel.append(document.createElement('div'));document.body.append(panel);
      const Native=ResizeObserver,watched=new Map();
      window.ResizeObserver=class extends Native{
        constructor(fn){super(fn);watched.set(this,new Set());}
        observe(target){watched.get(this).add(target);super.observe(target);}
        disconnect(){watched.get(this).clear();super.disconnect();}};
      const count=()=>[...watched.values()].filter(targets=>targets.has(panel)).length;
      mascot.host.mount(el);const inline=count();
      const placement=(floating,position='bottom-right')=>
        mascot.host.receive({id:'a',patch:{placement:{floating,position,minimise:false,drag:false}}});
      placement(true);const bottom=count();placement(true,'top-right');const top=count();
      placement(true);const again=count();placement(false);const restored=count();
      const state=mascot.host.state(el);mascot.host.unmount(el);
      return {inline,bottom,top,again,restored,gone:count(),state};})()"
    )
    expect_equal(result$inline, 0)
    expect_equal(result$bottom, 1)
    expect_equal(result$top, 0)
    expect_equal(result$again, 1)
    expect_equal(result$restored, 0)
    expect_equal(result$gone, 0)
    expect_false(result$state$placement$floating)
  })
  it("disconnects every observer and shared listener on final unmount, including a failed mount", {
    skip_without_chrome()
    js <- local_host_page()
    result <- js(
      "(() => {const el=document.getElementById('a');mascot.host.unmount(el);
      const NativeResize=ResizeObserver,NativeMutation=MutationObserver;
      const observers=new Set();window.ResizeObserver=class extends NativeResize{
        constructor(fn){super(fn);observers.add(this);}disconnect(){super.disconnect();observers.delete(this);}};
      window.MutationObserver=class extends NativeMutation{
        constructor(fn){super(fn);observers.add(this);}disconnect(){super.disconnect();observers.delete(this);}};
      let mediaListeners=0;const match=window.matchMedia;
      window.matchMedia=(...args)=>{const media=match(...args),add=media.addEventListener.bind(media),
        remove=media.removeEventListener.bind(media);
        media.addEventListener=(...values)=>{mediaListeners++;return add(...values);};
        media.removeEventListener=(...values)=>{mediaListeners--;return remove(...values);};return media;};
      let listener=0;const add=window.addEventListener,remove=window.removeEventListener;
      window.addEventListener=function(name,fn,...rest){if(name==='resize')listener++;return add.call(this,name,fn,...rest);};
      window.removeEventListener=function(name,fn,...rest){if(name==='resize')listener--;return remove.call(this,name,fn,...rest);};
      el.dataset.floating='true';el.dataset.minimise='true';mascot.host.mount(el);
      const active=observers.size;const second=el.cloneNode(true);second.id='second';document.body.append(second);
      mascot.host.mount(second);const shared=listener;mascot.host.unmount(el);const kept=listener;
      mascot.host.unmount(second);const gone=observers.size;
      const observe=ResizeObserver.prototype.observe;ResizeObserver.prototype.observe=function(){throw new Error('observer failed');};
      let failed=false;try{mascot.host.mount(el);}catch(e){failed=e.message==='observer failed';}
      ResizeObserver.prototype.observe=observe;
      return {active,shared,kept,gone,afterFailure:observers.size,listener,mediaListeners,failed,
        state:mascot.host.state(el),buttons:el.querySelectorAll('.mascot-minimise,.mascot-restore').length};})()"
    )
    expect_gte(result$active, 3)
    expect_equal(result$shared, 1)
    expect_equal(result$kept, 1)
    expect_equal(result$gone, 0)
    expect_equal(result$afterFailure, 0)
    expect_equal(result$listener, 0)
    expect_equal(result$mediaListeners, 0)
    expect_true(result$failed)
    expect_null(result$state)
    expect_equal(result$buttons, 0)
  })
})


describe("mascot.host restore feedback", {
  it("glows and grows on keyboard focus, with glow only under reduced motion", {
    skip_without_chrome()
    for (reduced in c(FALSE, TRUE)) {
      js <- local_host_page(reduced = reduced, placement = mascot_placement("bottom-right", minimise = TRUE))
      js(
        "const el=document.getElementById('a');el.querySelector('.mascot-minimise').click();
        window.restore=el.querySelector('.mascot-restore');restore.focus();"
      )
      # Finish the CSS transition without waiting for elapsed wall time.
      result <- host_layout(
        js,
        "restore.getAnimations().forEach(animation=>animation.finish());
        const style=getComputedStyle(restore);return {transform:style.transform,shadow:style.boxShadow,
        focus:restore.matches(':focus-visible'),diameter:restore.offsetWidth};"
      )
      expect_true(result$focus)
      expect_equal(result$diameter, 48)
      expect_false(identical(result$shadow, "none"))
      expect_identical(result$transform, if (reduced) "none" else "matrix(1.08, 0, 0, 1.08, 0, 0)")
    }
  })
})


describe("size and placement review regressions", {
  it("keeps an inline bubble inside a container that clips overflow, such as a bslib card", {
    skip_without_chrome()
    js <- local_host_page(size = 96, viewport = c(1000, 800), bubble = mascot_bubble("All checks finished.", Inf))
    js(
      "window.el=document.getElementById('a');window.card=document.createElement('div');
      card.style.cssText='overflow:hidden;width:320px;margin-left:300px;padding:0';el.before(card);card.append(el);
      dispatchEvent(new Event('resize'))"
    )
    result <- host_layout(
      js,
      "const b=el.querySelector('.mascot-bubble').getBoundingClientRect(),c=card.getBoundingClientRect();
      return {left:b.left,right:b.right,cardLeft:c.left,cardRight:c.right};"
    )
    # Without the container bound the bubble starts left of the card and its first words are clipped.
    expect_gte(result$left, result$cardLeft + 7.99)
    expect_lte(result$right, result$cardRight - 7.99)
  })
  it("S3-R1 keeps small inline bubbles inside either viewport edge and preserves reserved space", {
    skip_without_chrome()
    for (size in list(48, mascot_size(120, 48))) {
      js <- local_host_page(size = size, viewport = c(575, 800), bubble = mascot_bubble("Read this message", Inf))
      js(
        "window.el=document.getElementById('a');window.edge=document.createElement('div');
        edge.style.cssText='position:absolute;left:0;top:0';el.before(edge);edge.append(el)"
      )
      for (side in c("left", "right")) {
        js(sprintf(
          "edge.style.left='%s';edge.style.right='%s'",
          if (side == "left") "0" else "auto",
          if (side == "right") "0" else "auto"
        ))
        result <- host_layout(
          js,
          "const b=el.querySelector('.mascot-bubble').getBoundingClientRect();
          return {left:b.left,right:b.right,width:el.querySelector('canvas').getBoundingClientRect().width,
          canvasY:el.querySelector('canvas').getBoundingClientRect().top,statusY:el.querySelector('.mascot-status').getBoundingClientRect().top};"
        )
        expect_gte(result$left, 15.99)
        expect_lte(result$right, 559.01)
        expect_equal(result$width, 48)
      }
      js("mascot.host.receive({id:'a',patch:{bubble:{clear:true}}})")
      after <- host_layout(
        js,
        "return {canvasY:el.querySelector('canvas').getBoundingClientRect().top,
        statusY:el.querySelector('.mascot-status').getBoundingClientRect().top};"
      )
      expect_equal(after$canvasY, result$canvasY)
      expect_equal(after$statusY, result$statusY)
    }
  })
  it("S3-R2 moves focus before hiding a placement control without stealing focus elsewhere", {
    skip_without_chrome()
    js <- local_host_page(placement = mascot_placement("bottom-right", minimise = TRUE))
    for (floating in c(TRUE, FALSE)) {
      js(
        "window.el=document.getElementById('a');mascot.host.receive({id:'a',patch:{placement:{
        floating:true,position:'bottom-right',minimise:true,drag:false}}});el.querySelector('.mascot-minimise').focus()"
      )
      js(sprintf(
        "mascot.host.receive({id:'a',patch:{placement:{floating:%s,position:'bottom-right',minimise:false,drag:false}}})",
        tolower(as.character(floating))
      ))
      expect_true(host_layout(js, "return document.activeElement===el.querySelector('canvas');"))
    }
    js(
      "window.other=document.createElement('button');other.textContent='Elsewhere';document.body.append(other);
      other.focus();mascot.host.receive({id:'a',patch:{placement:{floating:true,position:'top-left',minimise:false,drag:false}}})"
    )
    expect_true(host_layout(js, "return document.activeElement===other;"))
  })
  it("S3-R3 escapes transformed parents, follows their visibility and theme, and returns inline to its source", {
    skip_without_chrome()
    js <- local_host_page(viewport = c(800, 800), bubble = mascot_bubble("Ready", Inf))
    js(
      "window.el=document.getElementById('a');window.box=document.createElement('div');
      box.style.cssText='transform:translateZ(0);position:relative;width:400px;height:400px;margin:100px';
      box.dataset.bsTheme='dark';el.before(box);box.append(el);
      mascot.host.receive({id:'a',patch:{placement:{floating:true,position:'bottom-right',minimise:true,drag:false}}})"
    )
    result <- host_layout(
      js,
      "const r=el.getBoundingClientRect();return {right:r.right,bottom:r.bottom,
      parent:el.parentElement.tagName,bg:getComputedStyle(el.querySelector('.mascot-bubble')).backgroundColor};"
    )
    expect_equal(result$right, 784)
    expect_equal(result$bottom, 784)
    expect_identical(result$parent, "BODY")
    expect_identical(result$bg, "rgb(33, 37, 41)")
    js("box.hidden=true")
    expect_equal(host_layout(js, "return el.querySelector('canvas').getBoundingClientRect().width;"), 0)
    js("box.hidden=false")
    expect_equal(host_layout(js, "return el.querySelector('canvas').getBoundingClientRect().width;"), 160)
    js("box.dataset.bsTheme='light'")
    expect_identical(
      host_layout(js, "return getComputedStyle(el.querySelector('.mascot-bubble')).backgroundColor;"),
      "rgb(255, 255, 255)"
    )
    js("box.removeAttribute('data-bs-theme');document.documentElement.dataset.bsTheme='dark'")
    expect_identical(
      host_layout(js, "return getComputedStyle(el.querySelector('.mascot-bubble')).backgroundColor;"),
      "rgb(33, 37, 41)"
    )
    js(
      "mascot.host.receive({id:'a',patch:{placement:{floating:false,position:'bottom-right',minimise:false,drag:false}}})"
    )
    expect_true(host_layout(js, "return el.parentElement===box;"))
    expect_equal(js("document.querySelectorAll('.mascot-source').length"), 0)
    expect_false(js("el.hasAttribute('data-shiny-no-bind-input')"))
  })
})

describe("mascot.host themes", {
  it("T4 draws original colours by default and replaces and clears overrides", {
    skip_without_chrome()
    js <- local_host_page(record_colours = TRUE)
    result <- js(
      "(() => {
      const el=document.getElementById('a'), own=themeDraws.at(-1).colours;
      const send=theme=>mascot.host.receive({id:'a',patch:{theme}});
      const theme={light:{body:'#1f6feb',rim:'#ffa500'},dark:null,mode:'light',css:null,brand:null};
      send(theme); const branded=themeDraws.at(-1);
      send({...theme,light:{body:'#9ec5fe'}}); const replaced=themeDraws.at(-1);
      send({...theme,light:null}); const reset=themeDraws.at(-1);
      return {own,branded,replaced,reset,state:mascot.host.state(el)};
    })()"
    )
    expect_identical(result$own$body, "#3f8a66")
    expect_identical(result$branded$colours$body, "#1f6feb")
    expect_identical(result$branded$colours$rim, "#ffa500")
    expect_identical(result$replaced$colours$rim, "#d9b35c")
    expect_null(result$replaced$overrides$rim)
    expect_identical(result$reset$colours$body, "#3f8a66")
    expect_length(result$reset$overrides, 0)
    expect_identical(result$state$current$mood, "idle")
  })
  it("T213 fills followers per mode, preserves supplied roles and reapplies rules after swaps", {
    skip_without_chrome()
    js <- local_host_page(record_colours = TRUE)
    result <- js(
      "(() => {const el=document.getElementById('a'),tessa=mascot.readCharacter('tessa'),blob=mascot.readCharacter('blob');
      const send=patch=>mascot.host.receive({id:'a',patch});
      const theme={light:{body:'#c2185b'},dark:{body:'#f2a6cf'},mode:'auto',css:null,brand:null};
      send({theme});const pink=themeDraws.at(-1).colours;
      send({theme:{...theme,light:{body:'#c2185b',sleeve:'#123456',rim:'#966600'}}});const supplied=themeDraws.at(-1).colours;
      send({character:{id:blob.id,name:blob.name,json:JSON.stringify(blob)}});
      send({character:{id:tessa.id,name:tessa.name,json:JSON.stringify(tessa)}});const swapped=themeDraws.at(-1).colours;
      document.documentElement.dataset.bsTheme='dark';return {pink,supplied,swapped};})()"
    )
    expect_identical(result$pink$sleeve, "#c2185b")
    expect_identical(result$pink$eyelid, "#c2185b")
    expect_identical(result$pink$limb, "#c2185b")
    expect_gt(mean(grDevices::col2rgb(result$pink$bodyHighlight)), mean(grDevices::col2rgb("#c2185b")))
    expect_identical(result$pink$outline, "#26312b")
    expect_identical(result$pink$accessory, "#d9b35c")
    expect_identical(result$supplied$sleeve, "#123456")
    expect_identical(result$supplied$limb, "#966600")
    expect_identical(result$supplied$accessory, "#966600")
    expect_identical(result$swapped$sleeve, "#123456")
    expect_identical(result$swapped$limb, "#966600")
    dark <- host_layout(js, "return themeDraws.at(-1).colours;")
    expect_identical(dark$sleeve, "#f2a6cf")
    expect_identical(dark$limb, "#f2a6cf")
  })
  it("T213 reproduces Tessa's original derived colours within three RGB units", {
    skip_without_chrome()
    description <- character_colour_data("tessa")
    js <- suppressWarnings(local_host_page(
      theme = list(
        body = description$colours$body,
        rim = description$colours$rim,
        accessory = description$colours$accessory
      ),
      record_colours = TRUE
    ))
    drawn <- js("themeDraws.at(-1).colours")
    for (role in names(description$colours)) {
      difference <- abs(grDevices::col2rgb(drawn[[role]]) - grDevices::col2rgb(description$colours[[role]]))
      expect_true(max(difference) <= 3, info = role)
    }
  })
  it("T4 follows Bootstrap and Quarto, ignores system preference and honours explicit modes", {
    skip_without_chrome()
    theme <- mascot_theme(light = list(body = "#1f6feb"), dark = list(body = "#9ec5fe"), mode = "auto")
    js <- local_host_page(theme = theme, record_colours = TRUE)
    colour <- function(code = "") {
      if (nzchar(code)) {
        js(paste0("(() => {", code, "})()"))
      }
      host_layout(js, "return themeDraws.at(-1).colours.body;")
    }
    expect_identical(colour(), "#1F6FEB")
    expect_identical(colour("document.documentElement.dataset.bsTheme='dark'"), "#9EC5FE")
    expect_identical(colour("document.body.dataset.bsTheme='light'"), "#1F6FEB")
    expect_identical(
      colour(
        "document.body.removeAttribute('data-bs-theme');document.documentElement.removeAttribute('data-bs-theme');document.body.className='quarto-dark'"
      ),
      "#9EC5FE"
    )
    expect_identical(colour("document.body.className='quarto-light'"), "#1F6FEB")
    attr(js, "session")$Emulation$setEmulatedMedia(features = list(list(name = "prefers-color-scheme", value = "dark")))
    expect_identical(colour(), "#1F6FEB")
    expect_identical(colour("document.body.className=''"), "#1F6FEB")
    expect_identical(colour("document.documentElement.dataset.bsTheme='invalid'"), "#1F6FEB")
    expect_identical(
      colour(
        "const theme=mascot.host.state(document.getElementById('a')).theme;theme.mode='light';mascot.host.receive({id:'a',patch:{theme}})"
      ),
      "#1F6FEB"
    )
    expect_identical(colour("document.documentElement.dataset.bsTheme='dark'"), "#1F6FEB")
    attr(js, "session")$Emulation$setEmulatedMedia(
      features = list(list(name = "prefers-color-scheme", value = "light"))
    )
    expect_identical(colour(), "#1F6FEB")
  })
  it("T4 defaults pages without a signal to light despite a dark system preference", {
    skip_without_chrome()
    implicit <- local_host_page(
      theme = mascot_theme(light = list(body = "#1f6feb"), dark = list(body = "#9ec5fe")),
      scheme = "dark",
      record_colours = TRUE
    )
    expect_identical(implicit("themeDraws.at(-1).colours.body"), "#1F6FEB")
    explicit <- local_host_page(
      theme = mascot_theme(light = list(body = "#1f6feb"), dark = list(body = "#9ec5fe"), mode = "light"),
      scheme = "dark",
      record_colours = TRUE
    )
    expect_identical(explicit("themeDraws.at(-1).colours.body"), "#1F6FEB")
  })
  it("T4 keeps palettes across swaps and drops only roles absent from the incoming drawing", {
    skip_without_chrome()
    js <- local_host_page(record_colours = TRUE)
    result <- js(
      "(() => {
      const blob=mascot.readCharacter('blob'),tessa=mascot.readCharacter('tessa');
      const swap=ch=>mascot.host.receive({id:'a',patch:{character:{id:ch.id,name:ch.name,json:JSON.stringify(ch)}}});
      mascot.host.receive({id:'a',patch:{theme:{light:{body:'#1f6feb',rim:'#ffa500'},dark:null,mode:'light',css:null,brand:null}}});
      swap(blob);const incoming=themeDraws.at(-1);swap(tessa);const returning=themeDraws.at(-1);
      return {incoming,returning};
    })()"
    )
    expect_identical(result$incoming$character, "blob")
    expect_identical(result$incoming$colours$body, "#1f6feb")
    expect_false("rim" %in% names(result$incoming$overrides))
    expect_identical(result$returning$colours$rim, "#ffa500")
  })
  it("T4 resolves brand leaders afresh and keeps themes when queued before mounting", {
    skip_without_chrome()
    skip_if_not_installed("bslib")
    js <- suppressWarnings(local_host_page(
      theme = bslib::bs_theme(primary = "#1f6feb", secondary = "orange"),
      record_colours = TRUE
    ))
    result <- js(
      "(() => {
      const initial=themeDraws.at(-1),blob={...mascot.readCharacter('blob'),brand:{primary:'outline',secondary:'body'}};
      mascot.host.receive({id:'a',patch:{character:{id:blob.id,name:blob.name,json:JSON.stringify(blob)}}});
      const remapped=themeDraws.at(-1),source=document.getElementById('a');
      mascot.host.receive({id:'late',patch:{theme:{light:{body:'#abcdef',rim:'#ffa500'},dark:null,mode:'light',css:null,brand:null}}});
      mascot.host.receive({id:'late',patch:{character:{id:blob.id,name:blob.name,json:JSON.stringify(blob)}}});
      const late=source.cloneNode(true);late.id='late';late.dataset.character='tessa';late.dataset.mood='idle';
      document.body.append(late);mascot.host.mount(late);
      return {initial,remapped,queued:themeDraws.at(-1),state:mascot.host.state(late)};
    })()"
    )
    expect_identical(result$initial$colours$body, "#1F6FEB")
    expect_identical(result$initial$colours$accessory, "#FFA500")
    expect_identical(result$initial$colours$limb, "#FFA500")
    expect_identical(result$initial$colours$sleeve, "#1F6FEB")
    expect_identical(result$remapped$colours$outline, "#1F6FEB")
    expect_identical(result$remapped$colours$body, "#FFA500")
    expect_identical(result$queued$character, "blob")
    expect_identical(result$queued$colours$body, "#abcdef")
    expect_false("rim" %in% names(result$queued$overrides))
  })
  it("T4 reads CSS sources, falls back to original colours and warns once without rejecting low contrast", {
    skip_without_chrome()
    js <- local_host_page(record_colours = TRUE)
    result <- js(
      "(() => {
      const el=document.getElementById('a');window.cssWarnings=[];console.warn=message=>cssWarnings.push(message);
      el.style.setProperty('--team-blue','orange');
      mascot.host.receive({id:'a',patch:{theme:{light:{body:'#1f6feb',rim:'#abcdef'},dark:null,mode:'light',
        css:{body:'--team-blue',rim:'--missing'},brand:null}}});
      return {draw:themeDraws.at(-1),warnings:[...cssWarnings]};
    })()"
    )
    expect_identical(result$draw$colours$body, "#ffa500")
    expect_identical(result$draw$colours$rim, "#d9b35c")
    expect_true(any(grepl("--missing", unlist(result$warnings), fixed = TRUE)))
    expect_true(any(grepl("below 3:1", unlist(result$warnings), fixed = TRUE)))
    css_colour <- function(value) {
      js(sprintf("document.getElementById('a').style.setProperty('--team-blue','%s')", value))
      host_layout(js, "return themeDraws.at(-1).colours.body;")
    }
    expect_identical(css_colour("#1f6feb"), "#1f6feb")
    expect_identical(css_colour("not-a-colour"), "#3f8a66")
    expect_identical(css_colour("initial"), "#3f8a66")
    expect_true(js("cssWarnings.filter(x=>x.includes('--missing')).length === 1"))
  })
  it("T4 preserves source CSS and mode when floating and themes restore controls without recolouring the bubble", {
    skip_without_chrome()
    js <- local_host_page(bubble = mascot_bubble("Ready", Inf), record_colours = TRUE)
    js(
      "window.el=document.getElementById('a');window.box=document.createElement('div');
      box.style.cssText='--team-blue:#1f6feb';box.dataset.bsTheme='dark';el.before(box);box.append(el);
      mascot.host.receive({id:'a',patch:{placement:{floating:true,position:'bottom-right',minimise:true,drag:false},
        theme:{light:null,dark:null,mode:'auto',css:{body:'--team-blue'},brand:null}}});"
    )
    result <- host_layout(
      js,
      "el.querySelector('.mascot-minimise').click();return {body:themeDraws.at(-1).colours.body,
      button:getComputedStyle(el.querySelector('.mascot-restore')).backgroundColor,
      bubble:getComputedStyle(el.querySelector('.mascot-bubble')).backgroundColor,mode:mascot.host.state(el).mode};"
    )
    expect_identical(result$body, "#1f6feb")
    expect_identical(result$button, "rgb(31, 111, 235)")
    expect_identical(result$bubble, "rgb(33, 37, 41)")
    expect_identical(result$mode, "dark")
    js("box.style.setProperty('--team-blue','#9ec5fe');box.dataset.bsTheme='light'")
    result <- host_layout(
      js,
      "return {
      button:getComputedStyle(el.querySelector('.mascot-restore')).backgroundColor,
      bubble:getComputedStyle(el.querySelector('.mascot-bubble')).backgroundColor,mode:mascot.host.state(el).mode};"
    )
    expect_identical(result$button, "rgb(158, 197, 254)")
    expect_identical(result$bubble, "rgb(255, 255, 255)")
    expect_identical(result$mode, "light")
  })
  it("T4 rejects an entire bad theme patch before changing drawings, host state or markup", {
    skip_without_chrome()
    js <- local_host_page(theme = mascot_theme(mode = "light"), record_colours = TRUE)
    result <- js(
      "(() => {
      const el=document.getElementById('a'),snapshot=()=>JSON.stringify({state:mascot.host.state(el),html:el.outerHTML,draw:themeDraws.at(-1)});
      const before=snapshot(),theme={light:null,dark:null,mode:'light',css:null,brand:null};
      const bad=[null,[],{...theme,extra:true},{...theme,mode:'bad'},{...theme,light:[]},
        {...theme,light:{body:'bad'}},{...theme,dark:{bdoy:'#abc'}},{...theme,css:{body:'wrong'}},
        {...theme,css:{default:'--team-blue'}},{...theme,brand:{primary:'#abc'}}];
      const warnings=[];console.warn=x=>warnings.push(x);const same=[];
      for(const value of bad) {mascot.host.receive({id:'a',patch:{mood:'happy',status:{mode:'custom',text:'Wrong'},theme:value}});same.push(snapshot()===before);}
      return {same,warnings};
    })()"
    )
    expect_true(all(unlist(result$same)))
    expect_length(result$warnings, 10)
  })
  it("T4 shares and removes mode observers and retains the media listener only for auto or floating bubbles", {
    skip_without_chrome()
    js <- local_host_page(theme = mascot_theme(mode = "light"))
    result <- js(
      "(() => {
      const el=document.getElementById('a'),media=window.matchMedia.bind(window),Observer=MutationObserver;
      const listeners=new Set(),observers=[];window.matchMedia=q=>{const m=media(q),add=m.addEventListener.bind(m),remove=m.removeEventListener.bind(m);
        m.addEventListener=(name,fn)=>{if(q==='(prefers-color-scheme: dark)')listeners.add(fn);add(name,fn);};
        m.removeEventListener=(name,fn)=>{if(q==='(prefers-color-scheme: dark)')listeners.delete(fn);remove(name,fn);};return m;};
      window.MutationObserver=class {constructor(fn){this.inner=new Observer(fn);this.active=false;observers.push(this);}
        observe(...args){this.active=true;this.inner.observe(...args);}disconnect(){this.active=false;this.inner.disconnect();}};
      const theme=mode=>({light:null,dark:null,mode,css:null,brand:null}),counts=()=>({listeners:listeners.size,observers:observers.filter(x=>x.active).length});
      mascot.host.receive({id:'a',patch:{theme:theme('auto')}});const first=counts();
      const b=el.cloneNode(true);b.id='b';document.body.append(b);mascot.host.mount(b);mascot.host.receive({id:'b',patch:{theme:theme('auto')}});const two=counts();
      mascot.host.unmount(el);const one=counts();mascot.host.receive({id:'b',patch:{theme:theme('light')}});const none=counts();
      mascot.host.receive({id:'b',patch:{placement:{floating:true,position:'bottom-right',minimise:true,drag:false}}});const bubble=counts();
      mascot.host.unmount(b);const gone=counts();return {first,two,one,none,bubble,gone};
    })()"
    )
    expect_identical(result$first, list(listeners = 1L, observers = 1L))
    expect_identical(result$two, result$first)
    expect_identical(result$one, result$first)
    expect_identical(result$none, list(listeners = 0L, observers = 0L))
    expect_identical(result$bubble, list(listeners = 1L, observers = 0L))
    expect_identical(result$gone, list(listeners = 0L, observers = 0L))
  })
})

describe("mascot.host motion", {
  it("M5 makes faces instant with motion off and schedules no motion frames", {
    skip_without_chrome()
    js <- local_host_page(reduced = FALSE, motion = FALSE)
    r <- js(host_motion_js(
      "send({mood:'happy'});const count=calls.length;fire(0);fire(500);

      return {mood:state().current.mood,queue:queued.size,draws:calls.length-count,

        reduced:state().motion.reduced};"
    ))
    expect_identical(r$mood, "happy")
    expect_true(r$reduced)
    expect_equal(r$queue, 0)
    expect_equal(r$draws, 0)
  })
  it("M5 honours the real visitor preference when motion is TRUE", {
    skip_without_chrome()
    js <- local_host_page(reduced = TRUE, motion = TRUE)
    r <- js(host_motion_js(
      "send({mood:'thinking'});send({gesture:'wave'});const count=calls.length;fire(0);fire(500);

      return {mood:state().current.mood,reduced:state().motion.reduced,queue:queued.size,draws:calls.length-count};"
    ))
    expect_identical(r$mood, "thinking")
    expect_null(r$reduced)
    expect_equal(r$queue, 0)
    expect_equal(r$draws, 0)
  })
  it("M5 swaps instantly with swap off, retains the theme and still animates moods", {
    skip_without_chrome()
    js <- local_host_page(reduced = FALSE, motion = mascot_motion(swap = FALSE), theme = list(body = "#1f6feb"))
    r <- js(host_motion_js(
      "const blob=mascot.readCharacter('blob');

      send({character:{id:blob.id,name:blob.name,json:JSON.stringify(blob)}});const swapped=state(),colour=calls.at(-1).colours.body;

      const tessa=mascot.readCharacter('tessa');send({character:{id:tessa.id,name:tessa.name,json:JSON.stringify(tessa)}});

      send({mood:'happy'});const before=state().current.mood;fire(0);fire(400);

      return {swapped,colour,before,after:state().current.mood,frames:calls.map(x=>x.frame),players:players.length};"
    ))
    expect_identical(r$swapped$current$character, "blob")
    expect_false(r$swapped$current$swapping)
    expect_identical(r$colour, "#1F6FEB")
    expect_identical(r$before, "idle")
    expect_identical(r$after, "happy")
    expect_true(any(unlist(r$frames) > 0))
    expect_equal(r$players, 1)
  })
  it("M5 stops a running swap on the live controller and rejects whole bad updates", {
    skip_without_chrome()
    js <- local_host_page(reduced = FALSE)
    r <- js(host_motion_js(
      "const blob=mascot.readCharacter('blob');send({character:{id:blob.id,name:blob.name,json:JSON.stringify(blob)}});

      const running=state().current.swapping;send({motion:{reduced:true,swap:true}});const stopped=state(),queue=queued.size;

      const snapshot=()=>JSON.stringify({state:state(),html:el.outerHTML,draws:calls.length}),before=snapshot(),warnings=[],old=console.warn;

      console.warn=x=>warnings.push(x);const invalid=[null,[],{}, {reduced:false,swap:true},{reduced:null,swap:1},

        {reduced:null,swap:true,seed:1}];

      const unchanged=invalid.map(motion=>{send({motion,mood:'happy',bubble:{text:'Wrong',html:false,closable:true,duration:5}});return snapshot()===before;});

      console.warn=old;send({motion:{reduced:null,swap:false}});

      mascot.host.receive({id:'late-motion',patch:{motion:{reduced:true,swap:false}}});

      const late=el.cloneNode(true);late.id='late-motion';late.dataset.character='tessa';late.dataset.mood='idle';document.body.append(late);mascot.host.mount(late);

      const queuedMotion=mascot.host.state(late).motion;mascot.host.unmount(late);

      return {running,stopped,queue,unchanged,warnings,players:players.length,queuedMotion,motion:state().motion};"
    ))
    expect_true(r$running)
    expect_false(r$stopped$current$swapping)
    expect_identical(r$stopped$current$character, "blob")
    expect_equal(r$queue, 0)
    expect_true(all(unlist(r$unchanged)))
    expect_length(r$warnings, 6)
    # One original controller and one separately mounted late mascot.
    expect_equal(r$players, 2)
    expect_identical(r$queuedMotion, list(reduced = TRUE, swap = FALSE))
    expect_identical(r$motion, list(reduced = NULL, swap = FALSE))
  })
  it("M5 removes restore growth and bubble animation while retaining the focus glow", {
    skip_without_chrome()
    js <- local_host_page(
      reduced = FALSE,
      motion = FALSE,
      placement = mascot_placement("bottom-right", minimise = TRUE),
      bubble = mascot_bubble("Ready", Inf)
    )
    r <- js(
      "(() => {const el=document.getElementById('a');el.querySelector('.mascot-minimise').click();

      const button=el.querySelector('.mascot-restore');button.focus();

      const read=()=>({transform:getComputedStyle(button).transform,transition:getComputedStyle(button).transitionDuration,

        glow:getComputedStyle(button).boxShadow,animation:getComputedStyle(el.querySelector('.mascot-bubble')).animationName});

      const off=read();mascot.host.receive({id:'a',patch:{motion:{reduced:null,swap:true}}});

      return {off,on:read()};})()"
    )
    expect_identical(r$off$transform, "none")
    expect_identical(r$off$transition, "0s")
    expect_identical(r$off$animation, "none")
    expect_false(identical(r$off$glow, "none"))
    expect_false(identical(r$on$transition, "0s"))
    expect_identical(r$on$animation, "mascot-bubble-appear")
  })
})

# Synthetic pointer events on the canvas, as a mouse or finger would send them (pointer id 1, primary button).
drag_js <- paste(
  "window.press=(target,type,x,y)=>target.dispatchEvent(new PointerEvent(type,",
  "{bubbles:true,cancelable:true,pointerId:1,button:0,isPrimary:true,clientX:x,clientY:y}));",
  "window.dragBy=(target,dx,dy)=>{const r=target.getBoundingClientRect(),x=r.left+r.width/2,y=r.top+r.height/2;",
  "press(target,'pointerdown',x,y);press(target,'pointermove',x+dx/2,y+dy/2);press(target,'pointermove',x+dx,y+dy);",
  "press(target,'pointerup',x+dx,y+dy);};"
)

describe("mascot.host popup menu", {
  it("P6 toggles by pointer, sends repeated event choices, holds the pose and clears it without motion", {
    skip_without_chrome()
    js <- local_host_page(
      popup_menu = mascot_popup_menu(c(about = "<b>About</b>", help = "Help")),
      shiny_menu = TRUE,
      motion = FALSE,
      reduced = FALSE,
      size = 24,
      viewport = c(320, 800)
    )
    r <- js(host_motion_js(
      "const button=el.querySelector('.mascot-menu-toggle'),menu=el.querySelector('[role=menu]');
      const initial=menu.hidden;button.click();const rect=menu.getBoundingClientRect(),edges=rect.left>=15&&rect.right<=305;const pose=calls.at(-1).pose.lookY;
      const label=menu.firstChild.textContent,escaped=menu.querySelector('b')===null;
      menu.firstChild.click();button.click();menu.firstChild.click();
      const cleared=calls.at(-1).pose.lookY===undefined;
      button.click();document.body.dispatchEvent(new PointerEvent('pointerdown',{bubbles:true}));
      const outside=menu.hidden;button.click();button.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true}));
      return {initial,edges,pose,label,escaped,cleared,outside,escape:menu.hidden,focus:document.activeElement===button,
        expanded:button.getAttribute('aria-expanded'),events:menuEvents,queue:queued.size,role:button.tagName};"
    ))
    expect_true(r$initial)
    expect_true(r$edges)
    expect_equal(r$pose, -1)
    expect_true(r$escaped)
    expect_identical(r$label, "<b>About</b>")
    expect_true(r$cleared)
    expect_true(r$outside)
    expect_true(r$escape)
    expect_true(r$focus)
    expect_identical(r$expanded, "false")
    expect_identical(r$role, "BUTTON")
    expect_equal(r$queue, 0)
    expect_equal(length(r$events), 2)
    for (event in r$events) {
      expect_identical(event, list("a_menu", "about", list(priority = "event")))
    }
  })
  it("opens eight pixels from the painted character, including inline reserved bubble space", {
    skip_without_chrome()
    for (position in c("inline", "top-left", "top-right", "bottom-left", "bottom-right")) {
      js <- local_host_page(
        popup_menu = c(about = "About"),
        shiny_menu = TRUE,
        motion = FALSE,
        placement = position,
        viewport = c(800, 900),
        size = 120
      )
      result <- js(
        "(() => {
        const el = document.getElementById('a'), canvas = el.querySelector('canvas');
        // Opened from the keyboard, so focus moves to the first item; a mouse click leaves focus where it was.
        const toggle = el.querySelector('.mascot-menu-toggle');
        toggle.focus(); toggle.dispatchEvent(new KeyboardEvent('keydown', {key: 'Enter', bubbles: true}));
        const box = canvas.getBoundingClientRect(), menu = el.querySelector('.mascot-menu').getBoundingClientRect();
        const pixels = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height).data;
        const rows = [];
        for (let y = 0; y < canvas.height; y++) {
          for (let x = 0; x < canvas.width; x++) {
            if (pixels[(y * canvas.width + x) * 4 + 3] > 0) { rows.push(y); break; }
          }
        }
        const top = box.top + rows[0] / canvas.height * box.height;
        const bottom = box.top + (rows.at(-1) + 1) / canvas.height * box.height;
        return {gap: el.dataset.position.startsWith('top') && el.dataset.floating === 'true'
          ? menu.top - bottom : top - menu.bottom, top: menu.top, bottom: menu.bottom,
          focus: document.activeElement === el.querySelector('[role=menuitem]')};
      })()"
      )
      expect_equal(result$gap, 8, tolerance = 1)
      expect_gte(result$top, 16)
      expect_lte(result$bottom, 884)
      expect_true(result$focus)
    }
  })
  it("a new bubble closes the menu and returns focus only from its items", {
    skip_without_chrome()
    js <- local_host_page(popup_menu = c(about = "About"), shiny_menu = TRUE, motion = FALSE)
    result <- js(
      "(() => {
      const el = document.getElementById('a'), toggle = el.querySelector('.mascot-menu-toggle');
      const send = text => mascot.host.receive({id: 'a', patch: {bubble: {text, html: false, closable: true, duration: null}}});
      const openByKeyboard = () => { toggle.focus(); toggle.dispatchEvent(new KeyboardEvent('keydown', {key: 'Enter', bubbles: true})); };
      openByKeyboard(); send('First');
      const closed = !mascot.host.state(el).menuOpen && el.querySelector('.mascot-menu').hidden;
      const returned = document.activeElement === toggle;
      const visible = !el.querySelector('.mascot-bubble').hidden;
      toggle.click(); toggle.focus(); send('Second');
      const toggleKept = document.activeElement === toggle;
      toggle.click();
      // A page control focused without emitting focusout keeps the menu open, isolating the focus rule.
      const outside = document.createElement('button'); document.body.append(outside);
      const stop = event => event.stopImmediatePropagation(); el.addEventListener('focusout', stop, true);
      outside.focus(); el.removeEventListener('focusout', stop, true);
      const outsideWasOpen = mascot.host.state(el).menuOpen;
      send('Third'); const outsideKept = document.activeElement === outside; outside.remove();
      return {closed, returned, visible, toggleKept, outsideWasOpen, outsideKept, open: mascot.host.state(el).menuOpen};
    })()"
    )
    expect_true(result$closed)
    expect_true(result$returned)
    expect_true(result$visible)
    expect_true(result$toggleKept)
    expect_true(result$outsideWasOpen)
    expect_true(result$outsideKept)
    expect_false(result$open)
  })
  it("keeps an inline menu inside its scrolling card", {
    skip_without_chrome()
    js <- local_host_page(popup_menu = c(about = "About", help = "Help"), shiny_menu = TRUE, motion = FALSE, size = 120)
    result <- js(
      "(() => {
      const el = document.getElementById('a'), card = document.createElement('div');
      Object.assign(card.style, {height: '360px', width: '400px', overflow: 'auto', marginTop: '120px'});
      el.parentElement.insertBefore(card, el); card.append(el);
      el.querySelector('.mascot-menu-toggle').click();
      const menu = el.querySelector('.mascot-menu').getBoundingClientRect(), bounds = card.getBoundingClientRect();
      return {top: menu.top - bounds.top, bottom: bounds.bottom - menu.bottom,
        left: menu.left - bounds.left, right: bounds.right - menu.right};
    })()"
    )
    expect_gte(result$top, 7)
    expect_gte(result$bottom, 7)
    expect_gte(result$left, 7)
    expect_gte(result$right, 7)
  })
  it("P6 Enter and Space always operate the toggle and navigation stays in its menu", {
    skip_without_chrome()
    js <- local_host_page(popup_menu = c(about = "About", help = "Help", more = "More"), shiny_menu = TRUE)
    r <- js(
      "(() => {const el=document.getElementById('a'),send=patch=>mascot.host.receive({id:'a',patch});
      let button=el.querySelector('.mascot-menu-toggle');
      const key=(target,key)=>target.dispatchEvent(new KeyboardEvent('keydown',{key,bubbles:true,cancelable:true}));
      button.focus();key(button,'Enter');const opened=mascot.host.state(el).menuOpen;key(button,'Enter');const closed=!mascot.host.state(el).menuOpen;
      send({popup_menu:{items:{about:'About',help:'Help',more:'More'}}});
      button=el.querySelector('.mascot-menu-toggle');key(document.body,'Enter');const global=!mascot.host.state(el).menuOpen;
      button.focus();key(button,' ');button.focus();key(button,' ');const spaceClosed=!mascot.host.state(el).menuOpen;
      key(button,' ');const first=document.activeElement.dataset.itemId;
      key(document.activeElement,'End');const end=document.activeElement.dataset.itemId;
      key(document.activeElement,'ArrowDown');const wrap=document.activeElement.dataset.itemId;
      key(document.activeElement,'ArrowUp');const up=document.activeElement.dataset.itemId;
      key(document.activeElement,'Home');const home=document.activeElement.dataset.itemId;
      key(document.activeElement,'Escape');return {opened,closed,spaceClosed,global,first,end,wrap,up,home,focus:document.activeElement===button};})()"
    )
    expect_true(r$opened)
    expect_true(r$closed)
    expect_true(r$spaceClosed)
    expect_true(r$global)
    expect_identical(r$first, "about")
    expect_identical(r$end, "more")
    expect_identical(r$wrap, "about")
    expect_identical(r$up, "more")
    expect_identical(r$home, "about")
    expect_true(r$focus)
  })
  it("P6 clears bubbles on opening, rejects whole bad patches and removes menu controls safely", {
    skip_without_chrome()
    js <- local_host_page(popup_menu = c(about = "About"), shiny_menu = TRUE, bubble = mascot_bubble("Ready", 5))
    r <- js(
      "(async()=>{const el=document.getElementById('a'),state=()=>mascot.host.state(el),send=patch=>mascot.host.receive({id:'a',patch});
      el.querySelector('.mascot-menu-toggle').click();const cleared=state().bubble===null&&el.querySelector('.mascot-bubble').hidden;
      send({mood:'happy',popup_menu:{items:{bad:''}}});const atomic=state().mood==='idle'&&state().menuOpen;
      el.querySelector('[role=menuitem]').focus();send({popup_menu:{items:{replacement:'Replacement'}}});
      const replacementFocus=document.activeElement===el.querySelector('.mascot-menu-toggle');
      el.querySelector('.mascot-menu-toggle').click();el.querySelector('[role=menuitem]').focus();send({popup_menu:{items:null}});
      return {cleared,atomic,replacementFocus,open:state().menuOpen,button:!!el.querySelector('.mascot-menu-toggle'),
        image:el.querySelector('canvas').getAttribute('role'),focus:document.activeElement===el.querySelector('canvas')};})()"
    )
    expect_true(r$cleared)
    expect_true(r$atomic)
    expect_true(r$replacementFocus)
    expect_false(r$open)
    expect_false(r$button)
    expect_identical(r$image, "img")
    expect_true(r$focus)
  })
  it("P6 keeps multiple mascots independent, preserves menus across swaps and cleans up outside listeners", {
    skip_without_chrome()
    js <- local_host_page(popup_menu = c(about = "About"), shiny_menu = TRUE, motion = FALSE)
    r <- js(
      "(() => {const a=document.getElementById('a');mascot.host.unmount(a);const b=a.cloneNode(true);b.id='module-helper';
      let added=0,removed=0;
      const add=document.addEventListener.bind(document),remove=document.removeEventListener.bind(document);
      document.addEventListener=(type,...args)=>{if(type==='pointerdown')added++;return add(type,...args);};
      document.removeEventListener=(type,...args)=>{if(type==='pointerdown')removed++;return remove(type,...args);};
      try{document.body.append(b);mascot.host.mount(a);mascot.host.mount(b);
        a.querySelector('.mascot-menu-toggle').click();b.querySelector('.mascot-menu-toggle').click();
        const independent=!mascot.host.state(a).menuOpen&&mascot.host.state(b).menuOpen;
        mascot.host.receive({id:b.id,patch:{character:{id:'blob',name:'Blob',json:document.querySelector('[data-mascot-character=blob]').textContent}}});
        const retained=mascot.host.state(b).menuOpen&&b.querySelector('.mascot-menu-toggle').getAttribute('aria-label').startsWith('Blob');
        b.querySelector('[role=menuitem]').click();b.querySelector('.mascot-menu-toggle').click();
        mascot.host.unmount(b);mascot.host.unmount(a);
        return {independent,retained,added,removed,event:menuEvents.at(-1),plain:!b.querySelector('.mascot-menu-toggle')};
      }finally{document.addEventListener=add;document.removeEventListener=remove;b.remove();}})()"
    )
    expect_true(r$independent)
    expect_true(r$retained)
    expect_true(r$plain)
    expect_equal(r$added, r$removed)
    expect_identical(r$event, list("module-helper_menu", "about", list(priority = "event")))
  })
  it("P6 hides static menus and keeps restore clicks separate from menus in a top floating corner", {
    skip_without_chrome()
    static <- local_host_page(popup_menu = c(about = "About"))
    expect_false(static("!!document.querySelector('.mascot-menu-toggle')"))
    js <- local_host_page(
      popup_menu = c(about = "About"),
      shiny_menu = TRUE,
      placement = mascot_placement("top-right", TRUE)
    )
    r <- js(
      "(() => {const el=document.getElementById('a');el.querySelector('.mascot-menu-toggle').click();
      const menu=el.querySelector('.mascot-menu'),below=menu.getBoundingClientRect().top>=el.querySelector('canvas').getBoundingClientRect().top;
      el.querySelector('.mascot-menu-toggle').click();
      el.querySelector('.mascot-minimise').click();const closed=!mascot.host.state(el).menuOpen;
      mascot.host.receive({id:'a',patch:{popup_menu:{items:{new:'New'}}}});
      const hiddenWhileMinimised=el.querySelector('.mascot-menu-toggle').hidden;
      el.querySelector('.mascot-restore').click();return {below,closed,hiddenWhileMinimised,open:mascot.host.state(el).menuOpen,
        hidden:el.querySelector('.mascot-menu-toggle').hidden};})()"
    )
    expect_true(r$below)
    expect_true(r$closed)
    expect_true(r$hiddenWhileMinimised)
    expect_false(r$open)
    expect_false(r$hidden)
  })
  it("places the popup menu in each requested direction with an eight-pixel gap from the canvas", {
    skip_without_chrome()
    for (dir in c("top", "bottom", "left", "right")) {
      js <- local_host_page(
        popup_menu = mascot_popup_menu(c(about = "About"), direction = dir),
        shiny_menu = TRUE,
        placement = mascot_placement("top-left", drag = "free"),
        size = 120,
        viewport = c(800, 800)
      )
      js(drag_js)
      js("dragBy(document.querySelector('#a canvas'), 300, 300)")
      res <- js(
        "(() => {
        const el = document.getElementById('a'), canvas = el.querySelector('canvas');
        el.querySelector('.mascot-menu-toggle').click();
        const menu = el.querySelector('.mascot-menu').getBoundingClientRect();
        const box = canvas.getBoundingClientRect();
        const pixels = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height).data;
        let minX = canvas.width, maxX = -1, minY = canvas.height, maxY = -1;
        for (let y = 0; y < canvas.height; y++) {
          for (let x = 0; x < canvas.width; x++) {
            if (pixels[(y * canvas.width + x) * 4 + 3] > 0) {
              if (x < minX) minX = x;
              if (x > maxX) maxX = x;
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
            }
          }
        }
        const inkLeft = box.left + (minX / canvas.width) * box.width;
        const inkRight = box.left + ((maxX + 1) / canvas.width) * box.width;
        const inkTop = box.top + (minY / canvas.height) * box.height;
        const inkBottom = box.top + ((maxY + 1) / canvas.height) * box.height;
        return {
          gapTop: inkTop - menu.bottom,
          gapBottom: menu.top - inkBottom,
          gapLeft: inkLeft - menu.right,
          gapRight: menu.left - inkRight,
          menuTop: menu.top,
          menuBottom: menu.bottom,
          menuLeft: menu.left,
          menuRight: menu.right,
          inkMidY: (inkTop + inkBottom) / 2,
          menuMidY: (menu.top + menu.bottom) / 2
        };
      })()"
      )
      if (dir == "top") {
        expect_equal(res$gapTop, 8, tolerance = 1)
        expect_gte(res$menuTop, 16)
      } else if (dir == "bottom") {
        expect_equal(res$gapBottom, 8, tolerance = 1)
        expect_lte(res$menuBottom, 784)
      } else if (dir == "left") {
        expect_equal(res$gapLeft, 8, tolerance = 1)
        expect_gte(res$menuLeft, 16)
        expect_equal(res$menuMidY, res$inkMidY, tolerance = 2)
      } else if (dir == "right") {
        expect_equal(res$gapRight, 8, tolerance = 1)
        expect_lte(res$menuRight, 784)
        expect_equal(res$menuMidY, res$inkMidY, tolerance = 2)
      }
    }
  })
  it("falls back to the opposite side then auto when the requested direction has no room", {
    skip_without_chrome()
    js_top <- local_host_page(
      popup_menu = mascot_popup_menu(c(about = "About"), direction = "top"),
      shiny_menu = TRUE,
      placement = mascot_placement("top-left", FALSE),
      viewport = c(800, 600)
    )
    res_top <- js_top(
      "(() => {
      const el = document.getElementById('a'), canvas = el.querySelector('canvas');
      el.querySelector('.mascot-menu-toggle').click();
      const menu = el.querySelector('.mascot-menu').getBoundingClientRect();
      const box = canvas.getBoundingClientRect();
      const pixels = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height).data;
      let maxY = -1;
      for (let y = 0; y < canvas.height; y++) {
        for (let x = 0; x < canvas.width; x++) {
          if (pixels[(y * canvas.width + x) * 4 + 3] > 0) maxY = Math.max(maxY, y);
        }
      }
      const inkBottom = box.top + ((maxY + 1) / canvas.height) * box.height;
      return { gap: menu.top - inkBottom };
    })()"
    )
    expect_equal(res_top$gap, 8, tolerance = 1)

    js_bottom <- local_host_page(
      popup_menu = mascot_popup_menu(c(about = "About"), direction = "bottom"),
      shiny_menu = TRUE,
      placement = mascot_placement("bottom-left", FALSE),
      viewport = c(800, 600)
    )
    res_bottom <- js_bottom(
      "(() => {
      const el = document.getElementById('a'), canvas = el.querySelector('canvas');
      el.querySelector('.mascot-menu-toggle').click();
      const menu = el.querySelector('.mascot-menu').getBoundingClientRect();
      const box = canvas.getBoundingClientRect();
      const pixels = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height).data;
      let minY = canvas.height;
      for (let y = 0; y < canvas.height; y++) {
        for (let x = 0; x < canvas.width; x++) {
          if (pixels[(y * canvas.width + x) * 4 + 3] > 0) { minY = Math.min(minY, y); break; }
        }
      }
      const inkTop = box.top + (minY / canvas.height) * box.height;
      return { gap: inkTop - menu.bottom };
    })()"
    )
    expect_equal(res_bottom$gap, 8, tolerance = 1)

    js_left <- local_host_page(
      popup_menu = mascot_popup_menu(c(about = "About"), direction = "left"),
      shiny_menu = TRUE,
      placement = mascot_placement("top-left", FALSE),
      viewport = c(800, 600)
    )
    res_left <- js_left(
      "(() => {
      const el = document.getElementById('a'), canvas = el.querySelector('canvas');
      el.querySelector('.mascot-menu-toggle').click();
      const menu = el.querySelector('.mascot-menu').getBoundingClientRect();
      const box = canvas.getBoundingClientRect();
      const pixels = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height).data;
      let maxX = -1;
      for (let y = 0; y < canvas.height; y++) {
        for (let x = 0; x < canvas.width; x++) {
          if (pixels[(y * canvas.width + x) * 4 + 3] > 0) maxX = Math.max(maxX, x);
        }
      }
      const inkRight = box.left + ((maxX + 1) / canvas.width) * box.width;
      return { gap: menu.left - inkRight };
    })()"
    )
    expect_equal(res_left$gap, 8, tolerance = 1)

    js_right <- local_host_page(
      popup_menu = mascot_popup_menu(c(about = "About"), direction = "right"),
      shiny_menu = TRUE,
      placement = mascot_placement("top-right", FALSE),
      viewport = c(800, 600)
    )
    res_right <- js_right(
      "(() => {
      const el = document.getElementById('a'), canvas = el.querySelector('canvas');
      el.querySelector('.mascot-menu-toggle').click();
      const menu = el.querySelector('.mascot-menu').getBoundingClientRect();
      const box = canvas.getBoundingClientRect();
      const pixels = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height).data;
      let minX = canvas.width;
      for (let y = 0; y < canvas.height; y++) {
        for (let x = 0; x < canvas.width; x++) {
          if (pixels[(y * canvas.width + x) * 4 + 3] > 0) minX = Math.min(minX, x);
        }
      }
      const inkLeft = box.left + (minX / canvas.width) * box.width;
      return { gap: inkLeft - menu.right };
    })()"
    )
    expect_equal(res_right$gap, 8, tolerance = 1)

    js_auto <- local_host_page(
      popup_menu = mascot_popup_menu(c(about = "About"), direction = "left"),
      shiny_menu = TRUE,
      size = 100,
      viewport = c(800, 600)
    )
    res_auto <- js_auto(
      "(() => {
      const el = document.getElementById('a');
      const card = document.createElement('div');
      Object.assign(card.style, { width: '130px', height: '400px', overflow: 'hidden' });
      el.parentElement.insertBefore(card, el);
      card.append(el);
      el.querySelector('.mascot-menu-toggle').click();
      const menu = el.querySelector('.mascot-menu').getBoundingClientRect();
      const box = el.querySelector('canvas').getBoundingClientRect();
      return { openedAbove: menu.bottom <= box.top + 20 };
    })()"
    )
    expect_true(res_auto$openedAbove)
  })
  it("anchors the popup menu to a free-dragged mascot rather than a corner", {
    skip_without_chrome()
    js <- local_host_page(
      placement = mascot_placement("bottom-right", drag = "free"),
      popup_menu = mascot_popup_menu(c(about = "About"), direction = "top"),
      shiny_menu = TRUE,
      size = 100,
      viewport = c(800, 600)
    )
    js(drag_js)
    js("dragBy(document.querySelector('#a canvas'), -350, -250)")
    result <- js(
      "(() => {
      const el = document.getElementById('a'), canvas = el.querySelector('canvas');
      el.querySelector('.mascot-menu-toggle').click();
      const menu = el.querySelector('.mascot-menu').getBoundingClientRect();
      const box = canvas.getBoundingClientRect();
      const pixels = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height).data;
      let minY = canvas.height;
      for (let y = 0; y < canvas.height; y++) {
        for (let x = 0; x < canvas.width; x++) {
          if (pixels[(y * canvas.width + x) * 4 + 3] > 0) { minY = Math.min(minY, y); break; }
        }
      }
      const inkTop = box.top + (minY / canvas.height) * box.height;
      return {
        gap: inkTop - menu.bottom,
        menuLeft: menu.left,
        canvasLeft: box.left,
        cornerLeft: 600
      };
    })()"
    )
    expect_equal(result$gap, 8, tolerance = 1)
    expect_lt(result$menuLeft, result$cornerLeft)
    expect_gt(result$menuLeft, 200)
  })
})


describe("mascot.host review corrections", {
  it("A1 keeps short-screen menu choices reachable in every corner and inline", {
    skip_without_chrome()
    for (position in c("top-left", "top-right", "bottom-left", "bottom-right", "inline")) {
      js <- local_host_page(
        popup_menu = mascot_popup_menu(
          c(about = "About", help = "Help", contact = "Contact", settings = "Settings")
        ),
        shiny_menu = TRUE,
        placement = if (position == "inline") "inline" else mascot_placement(position, TRUE),
        viewport = c(640, 320)
      )
      result <- host_layout(
        js,
        "const el=document.getElementById('a'),menu=el.querySelector('.mascot-menu');
        el.querySelector('.mascot-menu-toggle').click();const rect=menu.getBoundingClientRect();
        const first=menu.firstElementChild;first.focus();const firstRect=first.getBoundingClientRect();
        const last=menu.lastElementChild;last.focus();const lastRect=last.getBoundingClientRect();
        return {top:rect.top,bottom:rect.bottom,first:firstRect.top,last:lastRect.bottom,
          scrollable:menu.scrollHeight>menu.clientHeight};"
      )
      expect_gte(result$top, 15)
      expect_lte(result$bottom, 305)
      expect_gte(result$first, 15)
      expect_lte(result$last, 305)
    }
  })
  it("A2 returns focus to the visible menu after either placement fallback", {
    skip_without_chrome()
    js <- local_host_page(
      popup_menu = mascot_popup_menu(c(about = "About")),
      shiny_menu = TRUE,
      placement = mascot_placement("bottom-right", minimise = TRUE)
    )
    result <- js(
      "(() => {const el=document.getElementById('a'),send=patch=>mascot.host.receive({id:'a',patch});
      const button=el.querySelector('.mascot-menu-toggle'),outcomes=[];
      for(const minimised of [false,true]) {
        send({placement:{floating:true,position:'bottom-right',minimise:true,drag:false}});
        if(minimised) el.querySelector('.mascot-minimise').click();else el.querySelector('.mascot-minimise').focus();
        send({placement:{floating:false,position:'bottom-right',minimise:false,drag:false}});
        outcomes.push(document.activeElement===button);
        button.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',bubbles:true,cancelable:true}));
        outcomes.push(mascot.host.state(el).menuOpen);
        button.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true}));
      }
      send({placement:{floating:true,position:'bottom-right',minimise:true,drag:false}});
      el.querySelector('.mascot-minimise').focus();send({placement:{floating:true,position:'bottom-right',minimise:false,drag:false}});
      outcomes.push(document.activeElement===button);
      const outside=document.createElement('button');document.body.append(outside);outside.focus();
      send({placement:{floating:false,position:'bottom-right',minimise:false,drag:false}});
      return {outcomes,outside:document.activeElement===outside};})()"
    )
    expect_true(all(unlist(result$outcomes)))
    expect_true(result$outside)
  })
  it("C3 uses neutral action controls and hides them completely while the menu is open", {
    skip_without_chrome()
    js <- local_host_page(
      popup_menu = mascot_popup_menu(c(about = "About")),
      shiny_menu = TRUE,
      placement = mascot_placement("bottom-right", minimise = TRUE)
    )
    result <- js(
      "(() => {const el=document.getElementById('a'),button=el.querySelector('.mascot-menu-toggle'),
      action=el.querySelector('.mascot-minimise');
      const css=getComputedStyle(action),neutral=css.backgroundColor==='rgba(0, 0, 0, 0)';
      button.focus();const keyboard=getComputedStyle(action).opacity==='1'&&action.getClientRects().length>0;
      button.click();const hidden=action.getClientRects().length===0;
      button.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true}));
      const returned=document.activeElement===button&&action.getClientRects().length>0;
      action.click();const restore=el.querySelector('.mascot-restore');
      return {neutral,keyboard,hidden,returned,restore:restore.getClientRects().length>0,diameter:restore.offsetWidth};})()"
    )
    expect_true(result$neutral)
    expect_true(result$keyboard)
    expect_true(result$hidden)
    expect_true(result$returned)
    expect_true(result$restore)
    expect_equal(result$diameter, 48)
    session <- attr(js, "session")
    js("document.querySelector('.mascot-restore').click();document.activeElement.blur()")
    session$Emulation$setTouchEmulationEnabled(enabled = FALSE)
    session$Input$dispatchMouseEvent(type = "mouseMoved", x = 1, y = 1)
    resting <- host_layout(
      js,
      "const strip=document.querySelector('.mascot-actions'),css=getComputedStyle(strip);
      return {fine:matchMedia('(hover:hover) and (pointer:fine)').matches,opacity:css.opacity,
        pointer:css.pointerEvents,hover:strip.parentElement.matches(':hover'),focus:strip.parentElement.matches(':focus-within')};"
    )
    expect_identical(resting$opacity, if (resting$fine) "0" else "1", info = jsonlite::toJSON(resting))
    expect_identical(resting$pointer, if (resting$fine) "none" else "auto", info = jsonlite::toJSON(resting))
    point <- js(
      "(() => {const r=document.querySelector('.mascot-canvas').getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2};})()"
    )
    session$Input$dispatchMouseEvent(type = "mouseMoved", x = point$x, y = point$y)
    expect_true(host_layout(js, "return getComputedStyle(document.querySelector('.mascot-actions')).opacity==='1';"))
    session$Input$dispatchMouseEvent(type = "mouseMoved", x = 1, y = 1)
    session$Emulation$setTouchEmulationEnabled(enabled = TRUE)
    expect_true(host_layout(
      js,
      "return matchMedia('(pointer:coarse)').matches &&
      getComputedStyle(document.querySelector('.mascot-actions')).opacity==='1';"
    ))
    session$Emulation$setTouchEmulationEnabled(enabled = FALSE)
  })
  it("A1 follows notifications and inline scrolling and releases the shared scroll listener", {
    skip_without_chrome()
    js <- local_host_page(
      popup_menu = c(about = "About this app", help = "Help with a longer label", contact = "Contact", more = "More"),
      shiny_menu = TRUE,
      placement = mascot_placement("bottom-right", minimise = TRUE),
      viewport = c(640, 320)
    )
    js(
      "window.el=document.getElementById('a');window.scrollAdds=0;window.scrollRemoves=0;
      window.originalAdd=window.addEventListener.bind(window);window.originalRemove=window.removeEventListener.bind(window);
      window.addEventListener=(type,...args)=>{if(type==='scroll')scrollAdds++;return originalAdd(type,...args)};
      window.removeEventListener=(type,...args)=>{if(type==='scroll')scrollRemoves++;return originalRemove(type,...args)};
      el.querySelector('.mascot-menu-toggle').click();
      const panel=document.createElement('div');panel.id='shiny-notification-panel';
      Object.assign(panel.style,{position:'fixed',bottom:'0',right:'0',height:'72px',width:'200px'});
      panel.append(document.createElement('div'));panel.firstChild.textContent='Saved';document.body.append(panel);"
    )
    r <- host_layout(
      js,
      "const menu=el.querySelector('.mascot-menu').getBoundingClientRect(),panel=document.getElementById('shiny-notification-panel').getBoundingClientRect();
      return {top:menu.top,bottom:menu.bottom,limit:panel.top,mascot:el.getBoundingClientRect().bottom};"
    )
    expect_gte(r$top, 15)
    expect_lte(r$bottom, r$limit - 15)
    expect_lte(r$mascot, r$limit - 15)
    js(
      "document.getElementById('shiny-notification-panel').remove();document.body.style.minHeight='1400px';
      mascot.host.receive({id:'a',patch:{placement:{floating:false,position:'bottom-right',minimise:false,drag:false}}});window.scrollTo(0,200)"
    )
    r <- host_layout(
      js,
      "const rect=el.querySelector('.mascot-menu').getBoundingClientRect();
      mascot.host.unmount(el);const result={top:rect.top,bottom:rect.bottom,adds:scrollAdds,removes:scrollRemoves};
      window.addEventListener=originalAdd;window.removeEventListener=originalRemove;return result;"
    )
    expect_gte(r$top, 15)
    expect_lte(r$bottom, 305)
    expect_equal(r$adds, 1)
    expect_equal(r$removes, 1)
  })
})

describe("early gesture replay", {
  it("applies the queued character and mood before the latest gesture and does not replay it on replacement", {
    skip_without_chrome()
    js <- local_host_page(reduced = FALSE)
    result <- js(
      "(() => {
        const source=document.getElementById('a'),blob=mascot.readCharacter('blob'),calls=[],mount=mascot.mount;
        mascot.mount=(...args)=>{const p=mount(...args),gesture=p.gesture;
          p.gesture=name=>{calls.push({name,character:p.current().character,mood:p.current().mood});return gesture(name);};return p;};
        const patch={character:{id:blob.id,name:blob.name,json:JSON.stringify(blob)},mood:Object.keys(blob.moods)[0],gesture:'wave'};
        mascot.host.receive({id:'late',patch:{gesture:'nod'},revision:1,gestureRevision:1});
        mascot.host.receive({id:'late',patch,revision:2,gestureRevision:2});
        const add=()=>{const el=source.cloneNode(true);el.id='late';document.body.append(el);mascot.host.mount(el);return el;};
        const el=add(),first=mascot.host.state(el);
        mascot.host.receive({id:'late',patch,revision:2,gestureRevision:2,replay:true});
        mascot.host.unmount(el);el.remove();const replacement=add();
        mascot.host.receive({id:'late',patch,revision:2,gestureRevision:2,replay:true});
        mascot.mount=mount;
        return {calls,first,replacement:mascot.host.state(replacement),mood:Object.keys(blob.moods)[0]};
      })()"
    )
    expect_length(result$calls, 1)
    expect_identical(result$calls[[1]], list(name = "wave", character = "blob", mood = result$mood))
    expect_identical(result$first$current$character, "blob")
    expect_false(result$first$current$swapping)
    expect_identical(result$replacement$current$character, "blob")
  })
  it("pauses a bubble under a display-none parent and resumes with the exact remaining time", {
    skip_without_chrome()
    js <- local_host_page()
    install_bubble_clock(js)
    js(
      "const el=document.getElementById('a');window.wrapper=document.createElement('div');el.before(wrapper);wrapper.append(el);
      mascot.host.receive({id:'a',patch:{bubble:{text:'Timed',html:false,closable:true,duration:5}}});bubbleClock.advance(1000);
      wrapper.style.display='none';"
    )
    hidden <- host_layout(js, "return mascot.host.state(document.getElementById('a'));")
    expect_true(hidden$hidden)
    expect_equal(hidden$bubble$remaining, 4)
    js("bubbleClock.tick(10000);wrapper.style.display='';")
    shown <- host_layout(js, "return mascot.host.state(document.getElementById('a'));")
    expect_false(shown$hidden)
    expect_equal(shown$bubble$remaining, 4)
    expect_false(js(
      "(() => {bubbleClock.tick(3999);return mascot.host.state(document.getElementById('a')).bubble===null;})()"
    ))
    expect_true(js(
      "(() => {bubbleClock.tick(1);return mascot.host.state(document.getElementById('a')).bubble===null;})()"
    ))
  })
})

describe("mount replies racing live updates", {
  it("fills missing fields without restarting a live bubble, and keeps problem overlays", {
    skip_without_chrome()
    js <- local_host_page()
    install_bubble_clock(js)
    result <- js(
      "(() => {
      const el=document.getElementById('a'),bubble={text:'Live',html:false,closable:true,duration:5};
      mascot.host.receive({id:'a',patch:{bubble},revision:2,fields:{bubble:2}});bubbleClock.advance(1000);
      mascot.host.receive({id:'a',patch:{mood:'happy',bubble},revision:2,fields:{mood:1,bubble:2},replay:true});
      const filled=mascot.host.state(el);
      mascot.host.receive({id:'a',patch:{problem:'mascot: bad mood'},revision:3,fields:{problem:3}});
      mascot.host.receive({id:'a',patch:{status:{mode:'custom',text:'Kept'},problem:'mascot: bad mood'},
        revision:3,fields:{status:1,problem:3},replay:true});
      const covered=mascot.host.state(el);
      mascot.host.receive({id:'a',patch:{mood:'thinking'},revision:4,fields:{mood:4,problem:4}});
      mascot.host.receive({id:'a',patch:{problem:'mascot: bad mood'},revision:3,fields:{problem:3},replay:true});
      return {filled,covered,recovered:mascot.host.state(el)};
    })()"
    )
    expect_identical(result$filled$current$mood, "happy")
    expect_equal(result$filled$bubble$remaining, 4)
    expect_identical(result$covered$problem, "mascot: bad mood")
    expect_identical(result$covered$status$text, "Kept")
    expect_identical(result$covered$current$mood, "worried")
    expect_null(result$recovered$problem)
    expect_identical(result$recovered$current$mood, "thinking")
  })
})

describe("mascot.host dragging", {
  it("D1 snaps to the nearest corner, reports it, opens bubbles inwards and keeps a click for the menu", {
    skip_without_chrome()
    js <- local_host_page(
      placement = mascot_placement("bottom-right", drag = "snap"),
      bubble = mascot_bubble("Hello", Inf),
      popup_menu = c(about = "About"),
      shiny_menu = TRUE,
      size = 100,
      viewport = c(800, 600)
    )
    js(drag_js)
    result <- host_layout(
      js,
      "const el=document.getElementById('a'),c=el.querySelector('canvas'),r=c.getBoundingClientRect();
      const x=r.left+50,y=r.top+50;
      press(c,'pointerdown',x,y);press(c,'pointermove',x+2,y+1);const small=el.dataset.dragging;
      press(c,'pointerup',x+2,y+1);c.click();const menuOpen=mascot.host.state(el).menuOpen;c.click();
      const start=el.getBoundingClientRect();
      press(c,'pointerdown',x,y);press(c,'pointermove',x-300,y-200);
      const moving=el.getBoundingClientRect(),dragging=mascot.host.state(el).dragging,placed=el.dataset.placed;
      press(c,'pointermove',x-600,y-450);press(c,'pointerup',x-600,y-450);c.click();
      return {small:small===undefined,menuOpen,dx:moving.left-start.left,dy:moving.top-start.top,dragging,placed,
        afterClick:mascot.host.state(el).menuOpen,events:menuEvents};"
    )
    expect_true(result$small)
    expect_true(result$menuOpen)
    expect_equal(result$dx, -300)
    expect_equal(result$dy, -200)
    expect_true(result$dragging)
    expect_identical(result$placed, "true")
    expect_false(result$afterClick)
    expect_identical(result$events, list(list("a_position", "top-left", list(priority = "event"))))
    result <- host_layout(
      js,
      "mascot.host.receive({id:'a',patch:{bubble:{text:'Hello again',html:false,closable:true,duration:null}}});
      const el=document.getElementById('a'),r=el.getBoundingClientRect(),
      b=el.querySelector('.mascot-bubble').getBoundingClientRect(),s=mascot.host.state(el);
      return {x:r.x,y:r.y,position:el.dataset.position,state:s.placement.position,drag:s.placement.drag,
        placed:el.dataset.placed===undefined,dragging:s.dragging,dropped:s.dropped,below:b.top>r.bottom,
        animations:el.getAnimations().length};"
    )
    expect_equal(result$x, 16)
    expect_equal(result$y, 16)
    expect_identical(result$position, "top-left")
    expect_identical(result$state, "top-left")
    expect_identical(result$drag, "snap")
    expect_true(result$placed)
    expect_false(result$dragging)
    expect_null(result$dropped)
    expect_true(result$below)
    # Reduced motion: the move to the corner is instant.
    expect_equal(result$animations, 0)
    # Each corner is reached from its own quarter of the window.
    for (move in list(c(500, 0, "top-right"), c(0, 300, "bottom-right"), c(-500, 0, "bottom-left"))) {
      js(sprintf("dragBy(document.querySelector('#a canvas'),%s,%s)", move[[1]], move[[2]]))
      expect_identical(js("document.getElementById('a').dataset.position"), move[[3]])
      expect_identical(js("menuEvents.at(-1)[1]"), move[[3]])
    }
    expect_equal(host_layout(js, "return innerHeight-document.getElementById('a').getBoundingClientRect().bottom;"), 16)
  })
  it("D2 keeps a free drop inside the window, after resizes, until a placement update replaces it", {
    skip_without_chrome()
    js <- local_host_page(
      placement = mascot_placement("top-left", drag = "free"),
      shiny_menu = TRUE,
      size = 100,
      viewport = c(800, 600)
    )
    js(drag_js)
    result <- host_layout(
      js,
      "const el=document.getElementById('a'),c=el.querySelector('canvas'),start=el.getBoundingClientRect();
      dragBy(c,400.4,150);const r=el.getBoundingClientRect(),s=mascot.host.state(el);
      return {dx:r.left-start.left,dy:r.top-start.top,dropped:s.dropped,position:el.dataset.position,
        events:menuEvents,width:r.width,height:r.height};"
    )
    expect_equal(result$dx, 400)
    expect_equal(result$dy, 150)
    expect_identical(result$dropped, list(x = 416L, y = 166L))
    # The nearest corner only orients the bubble and menu.
    expect_identical(result$position, "top-right")
    expect_identical(result$events, list(list("a_position", list(x = 416L, y = 166L), list(priority = "event"))))
    result <- host_layout(
      js,
      "const el=document.getElementById('a');dragBy(el.querySelector('canvas'),5000,5000);
      const r=el.getBoundingClientRect();return {right:innerWidth-r.right,bottom:innerHeight-r.bottom,
        event:menuEvents.at(-1)[1],x:r.x,y:r.y,position:el.dataset.position};"
    )
    expect_equal(result$right, 16)
    expect_equal(result$bottom, 16)
    expect_equal(result$event$x, round(result$x))
    expect_equal(result$event$y, round(result$y))
    expect_identical(result$position, "bottom-right")
    result <- host_layout(
      js,
      "const el=document.getElementById('a');dragBy(el.querySelector('canvas'),-5000,-5000);
      const r=el.getBoundingClientRect();return {x:r.x,y:r.y};"
    )
    expect_equal(result$x, 16)
    expect_equal(result$y, 16)
    js("dragBy(document.querySelector('#a canvas'),600,400)")
    attr(js, "session")$Emulation$setDeviceMetricsOverride(
      width = 400,
      height = 300,
      deviceScaleFactor = 1,
      mobile = FALSE
    )
    result <- host_layout(
      js,
      "const r=document.getElementById('a').getBoundingClientRect();
      return {right:innerWidth-r.right,bottom:innerHeight-r.bottom,dropped:mascot.host.state(document.getElementById('a')).dropped};"
    )
    expect_equal(result$right, 16)
    expect_equal(result$bottom, 16)
    # The visitor's drop point is kept; only what is shown is clamped.
    expect_identical(result$dropped$x, 616L)
    js(
      "mascot.host.receive({id:'a',patch:{placement:{floating:true,position:'bottom-left',minimise:false,drag:'free'}}})"
    )
    result <- host_layout(
      js,
      "const el=document.getElementById('a'),r=el.getBoundingClientRect();
      return {x:r.x,bottom:innerHeight-r.bottom,placed:el.dataset.placed===undefined,dropped:mascot.host.state(el).dropped};"
    )
    expect_equal(result$x, 16)
    expect_equal(result$bottom, 16)
    expect_true(result$placed)
    expect_null(result$dropped)
  })
  it("D3 starts only from the canvas of a floating, draggable, unminimised mascot", {
    skip_without_chrome()
    js <- local_host_page(
      placement = mascot_placement("bottom-right", minimise = TRUE, drag = "snap"),
      bubble = mascot_bubble(htmltools::HTML("Read <a href='#more'>more</a>"), Inf),
      shiny_menu = TRUE,
      viewport = c(800, 600)
    )
    js(drag_js)
    result <- js(
      "(() => {const el=document.getElementById('a'),start=JSON.stringify(el.getBoundingClientRect());
      const same=()=>JSON.stringify(el.getBoundingClientRect())===start&&el.dataset.position==='bottom-right';
      const out=[];
      for (const selector of ['.mascot-minimise','.mascot-bubble-close','.mascot-bubble a','.mascot-status']) {
        const target=el.querySelector(selector);target.hidden=false;dragBy(target,-500,-400);out.push(same());}
      el.querySelector('.mascot-minimise').click();dragBy(el.querySelector('.mascot-restore'),-500,-400);
      out.push(el.dataset.position==='bottom-right');el.querySelector('.mascot-restore').click();
      const c=el.querySelector('canvas');
      press(c,'pointerdown',700,500);press(c,'pointermove',650,450);
      mascot.host.receive({id:'a',patch:{placement:{floating:true,position:'bottom-right',minimise:true,drag:false}}});
      const replaced=mascot.host.state(el).dragging===false&&el.dataset.placed===undefined;
      press(c,'pointermove',100,100);press(c,'pointerup',100,100);
      dragBy(c,-500,-400);
      return {out,replaced,still:el.dataset.position,events:menuEvents.length,drag:el.dataset.drag};})()"
    )
    expect_true(all(unlist(result$out)))
    expect_true(result$replaced)
    expect_identical(result$still, "bottom-right")
    expect_identical(result$events, 0L)
    expect_identical(result$drag, "false")
    inline <- local_host_page(shiny_menu = TRUE)
    inline(drag_js)
    expect_identical(
      inline(
        "(() => {const el=document.getElementById('a');dragBy(el.querySelector('canvas'),100,100);
        return [el.dataset.placed===undefined,mascot.host.state(el).dragging,menuEvents.length];})()"
      ),
      list(TRUE, FALSE, 0L)
    )
  })
  it("D4 animates a snap unless motion is reduced or off, and removes its listeners on unmount", {
    skip_without_chrome()
    for (case in list(list(reduced = FALSE, motion = TRUE, n = 1L), list(reduced = FALSE, motion = FALSE, n = 0L))) {
      js <- local_host_page(
        placement = mascot_placement("bottom-right", drag = "snap"),
        reduced = case$reduced,
        motion = case$motion,
        viewport = c(800, 600)
      )
      js(drag_js)
      expect_identical(
        js(
          "(() => {const el=document.getElementById('a');dragBy(el.querySelector('canvas'),-500,-400);
          return el.getAnimations().length;})()"
        ),
        case$n
      )
    }
    result <- js(
      "(() => {const el=document.getElementById('a'),c=el.querySelector('canvas');mascot.host.unmount(el);
      press(c,'pointerdown',700,500);press(c,'pointermove',100,100);
      return [el.dataset.placed===undefined,el.dataset.dragging===undefined,el.dataset.drag];})()"
    )
    expect_identical(result, list(TRUE, TRUE, "snap"))
  })
})
