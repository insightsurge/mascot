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
      send('gesture',{gesture:'wave'}); const gesture=add('gesture'); console.warn=original;
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
        buttons=el.querySelectorAll('button').length, timers=bubbleClock.count();
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
  it("queues the latest bubble, starts its lifetime on appearance, and drops gestures", {
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
    expect_length(warnings, 2)
    expect_true(any(grepl('gesture "nod".*was dropped', warnings)))
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
  it("A3 follows system dark mode but honours an explicit light theme", {
    skip_without_chrome()
    js <- local_host_page(bubble = mascot_bubble("Ready", Inf), scheme = "dark")
    result <- js(
      "(() => {
      const bubble=document.querySelector('#a .mascot-bubble');
      const dark=getComputedStyle(bubble).backgroundColor;
      document.body.setAttribute('data-bs-theme','light'); const light=getComputedStyle(bubble).backgroundColor;
      document.documentElement.setAttribute('data-bs-theme','light');
      return {dark,light,rootLight:getComputedStyle(bubble).backgroundColor};
    })()"
    )
    expect_identical(result$dark, "rgb(33, 37, 41)")
    expect_identical(result$light, "rgb(255, 255, 255)")
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
})
