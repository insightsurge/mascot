describe("complete-state browser delivery", {
  protocol_page <- function(env = parent.frame(), motion = TRUE) {
    skip_without_chrome()
    testthat::skip_if_not_installed("shinytest2")
    js <- local_host_page(env = env, reduced = FALSE, motion = motion)
    js(
      "window.el=document.getElementById('a');window.read=()=>mascot.host.state(el);
      window.base={character:{id:'tessa',name:'Tessa',json:el.querySelector('[data-mascot-character]').textContent},
        mood:'idle',status:{mode:'mood'},bubble:{clear:true},size:read().size,placement:read().placement,
        theme:read().theme,motion:read().motion,click:read().click};
      window.envelope=(revision=1,changes={},extra={})=>({version:1,id:'a',generation:read().snapshot.generation,
        revision,state:{...base,...changes},gesture:null,gesture_watermark:0,bubble_revision:1,restore:false,...extra});
      window.send=value=>mascot.host.receive(value);window.clone=x=>JSON.parse(JSON.stringify(x));true"
    )
    js
  }

  it("ignores other generations, equal revisions and whole-state invariant failures", {
    js <- protocol_page()
    r <- js(
      "(() => {
      send(envelope(1,{mood:'thinking',status:{mode:'custom',text:'Scanning'}}));
      const initial=read(),warnings=[],warn=console.warn;console.warn=e=>warnings.push(String(e));
      send(envelope(2,{status:{mode:'custom',text:'Wrong version'}},{version:99}));
      const wrong=envelope(2,{status:{mode:'custom',text:'Wrong'}},{generation:initial.snapshot.generation+1});send(wrong);
      send(envelope(1,{mood:'happy'}));send(envelope(0,{mood:'happy'}));
      const before=JSON.stringify(read());
      for(const next of [envelope(2,{mood:'missing',status:{mode:'custom',text:'Wrong'}}),
        envelope(2,{unknown:true}),envelope(2,{}, {bubble_revision:-1}),envelope(2,{}, {gesture:{name:'nod',revision:3}})]) send(next);
      const after=read();console.warn=warn;
      send(envelope(2,{mood:'happy',status:{mode:'custom',text:'Latest'}},{future_metadata:'ignored'}));
      return {initial,after,same:before===JSON.stringify(after),warnings,latest:read()};})()"
    )
    expect_identical(r$initial$status$text, "Scanning")
    # Lifecycle records a development error, while every displayed value and
    # authoritative revision remain intact after a failed complete preflight.
    expect_identical(r$after$status$text, "Scanning")
    expect_identical(r$after$snapshot$applied_revision, 1L)
    expect_identical(r$after$snapshot$lifecycle, "error")
    expect_length(r$warnings, 4)
    expect_true(all(grepl("invariant failure", unlist(r$warnings), fixed = TRUE)))
    expect_identical(r$latest$status$text, "Latest")
    expect_identical(r$latest$snapshot$applied_revision, 2L)
  })

  it("consumes once through a lost acknowledgement, remount and terminated generation", {
    js <- protocol_page(motion = FALSE)
    r <- js(
      "(() => {
      const mount=mascot.mount,gestures=[];mascot.host.unmount(el);
      mascot.mount=(...args)=>{const c=mount(...args),g=c.gesture;c.gesture=name=>{gestures.push(name);return g(name);};return c;};
      mascot.host.mount(el);const first=envelope(2,{status:{mode:'custom',text:'Kept'}},
        {gesture:{name:'nod',revision:2}});send(first);send(first);
      const consumed=read().snapshot;mascot.host.unmount(el);
      // A terminated generation cannot consume a newer action.
      send({...first,revision:3,gesture:{name:'wave',revision:3}});
      mascot.host.mount(el);const generation=read().snapshot.generation;
      send({...first,revision:3,gesture:{name:'wave',revision:3}}); // stale generation while the new one is live
      send({...first,generation,restore:true});const restored=read();
      send(envelope(3,{motion:{...base.motion,gestures:true},status:{mode:'custom',text:'New'}},
        {gesture:{name:'wave',revision:3}}));const latest=read();
      mascot.mount=mount;return {gestures,consumed,restored,latest};})()"
    )
    expect_identical(r$consumed$gesture_watermark, 2L)
    expect_identical(r$restored$snapshot$gesture_watermark, 2L)
    expect_identical(r$restored$status$text, "Kept")
    expect_identical(unlist(r$gestures), "wave")
    expect_identical(r$latest$snapshot$gesture_watermark, 3L)
    expect_identical(r$latest$status$text, "New")
  })

  it("never schedules a played gesture twice when its acknowledgement is lost", {
    js <- protocol_page()
    r <- js(
      "(() => {
      const mount=mascot.mount,calls=[];mascot.host.unmount(el);
      mascot.mount=(...args)=>{const c=mount(...args),g=c.gesture;c.gesture=name=>{calls.push(name);return g(name);};return c;};
      mascot.host.mount(el);send(envelope(1,{}, {gesture:{name:'nod',revision:1}}));
      const before=read().snapshot;mascot.host.unmount(el);mascot.host.mount(el);
      send(envelope(1,{}, {gesture:{name:'nod',revision:1},restore:true}));
      const after=read().snapshot;mascot.mount=mount;return {calls,before,after};})()"
    )
    expect_identical(unlist(r$calls), "nod")
    expect_identical(r$after$gesture_watermark, r$before$gesture_watermark)
  })

  it("consumes swap and reduced-motion discards without losing coupled fields", {
    js <- protocol_page()
    r <- js(
      "(() => {
      send(envelope(1));const blob=mascot.readCharacter('blob');
      const incoming={character:{id:blob.id,name:blob.name,json:JSON.stringify(blob)},mood:'happy',status:{mode:'custom',text:'Kept'}};
      send(envelope(2,incoming,{gesture:{name:'wave',revision:2}}));const swapping=read();
      send(envelope(3,{...incoming,motion:{...base.motion,reduced:true}},{gesture:{name:'nod',revision:3}}));
      const reduced=read();mascot.host.unmount(el);mascot.host.mount(el);
      send(envelope(3,{...incoming,motion:{...base.motion,reduced:true}},{gesture:{name:'nod',revision:3},restore:true}));
      return {swapping,reduced,restored:read()};})()"
    )
    expect_true(r$swapping$current$swapping)
    expect_identical(r$swapping$snapshot$gesture_watermark, 2L)
    expect_false(r$reduced$current$swapping)
    expect_identical(r$reduced$snapshot$gesture_watermark, 3L)
    expect_identical(r$reduced$status$text, "Kept")
    expect_identical(r$restored$snapshot$gesture_watermark, 3L)
    expect_identical(r$restored$character, "blob")
  })

  it("terminates before synchronous unmount notification listeners can deliver an action", {
    js <- protocol_page()
    r <- js(
      "(() => {
      send(envelope(1));window.Shiny={setInputValue:(name,value)=>{
        if(value.lifecycle==='unmounted') send(envelope(2,{}, {gesture:{name:'wave',revision:2}}));
      }};
      mascot.host.unmount(el);mascot.host.mount(el);const before=read().snapshot;
      send(envelope(2,{}, {gesture:{name:'wave',revision:2}}));
      delete window.Shiny;return {before,after:read().snapshot};})()"
    )
    expect_identical(r$before$gesture_watermark, 0L)
    expect_identical(r$after$gesture_watermark, 2L)
  })

  it("retains bubble dismissal and remaining lifetime while explicit new revisions reopen", {
    js <- protocol_page()
    install_bubble_clock(js)
    r <- js(
      "(() => {
      const bubble={text:'Same',html:false,closable:true,duration:5};
      send(envelope(1,{bubble}));bubbleClock.advance(1000);
      send(envelope(2,{bubble,status:{mode:'custom',text:'Status'}}));const remaining=read().bubble.remaining;
      mascot.host.unmount(el);mascot.host.mount(el);send(envelope(2,{bubble},{restore:true}));
      const restored=read().bubble.remaining;
      el.querySelector('.mascot-bubble-close').click();const dismissed=read().snapshot.dismissed_bubble_revision;
      send(envelope(3,{bubble,mood:'happy'}));const stayedClosed=read().bubble===null;
      mascot.host.unmount(el);mascot.host.mount(el);send(envelope(3,{bubble},{restore:true}));
      const remountClosed=read().bubble===null;
      send(envelope(4,{bubble},{bubble_revision:2}));const reopened=read().bubble;
      return {remaining,restored,dismissed,stayedClosed,remountClosed,reopened};})()"
    )
    expect_equal(r$remaining, 4)
    expect_equal(r$restored, 4)
    expect_equal(r$dismissed, 1)
    expect_true(r$stayedClosed)
    expect_true(r$remountClosed)
    expect_identical(r$reopened$text, "Same")
    expect_equal(r$reopened$remaining, 5)
  })

  it("starts the counters again when a reconnect binds the page to a new server session", {
    js <- protocol_page()
    r <- js(
      "(() => {
      const inputs=[],calls=[],mount=mascot.mount,connect=id=>{window.Shiny.shinyapp.config.sessionId=id;
        document.dispatchEvent(new Event('shiny:sessioninitialized'));};
      mascot.host.unmount(el);
      mascot.mount=(...args)=>{const c=mount(...args),g=c.gesture;c.gesture=name=>{calls.push(name);return g(name);};return c;};
      mascot.host.mount(el);
      window.Shiny={shinyapp:{config:{sessionId:null}},setInputValue:(name,value)=>inputs.push({name,value})};
      connect('one');const first=inputs.length;
      send(envelope(5,{bubble:{text:'Old',html:false,closable:true,duration:null},status:{mode:'custom',text:'Old'}},
        {gesture:{name:'nod',revision:5},bubble_revision:4}));
      const before=read(),sent=inputs.length;connect('one');const sameSession=inputs.length-sent;
      const generation=before.snapshot.generation,token=before.snapshot.mount_token;
      connect('two');const resumed=inputs.slice(sent).map(x=>x.value),afterResume=read();
      // A server session that has not seen this page's template asks for it; the answer is a resume too.
      send({version:1,kind:'template-needed',id:'a',generation,revision:0,mount_token:token,problem:'Template needed.'});
      const recovery=inputs.slice(-1)[0].value;
      // Old numbers would make the page ignore the new session's first states.
      send(envelope(1,{status:{mode:'custom',text:'New'}},{gesture:{name:'wave',revision:1},bubble_revision:0,restore:true}));
      const adopted=read();
      send(envelope(2,{status:{mode:'custom',text:'Next'}},{bubble_revision:1}));
      const later=read();
      delete window.Shiny;mascot.mount=mount;
      return {first,sameSession,resumed,afterResume,adopted,recovery,generation,token,calls,later};})()"
    )
    expect_identical(r$first, 0L)
    expect_identical(r$sameSession, 0L)
    expect_length(r$resumed, 1)
    resumed <- r$resumed[[1]]
    expect_identical(resumed$lifecycle, "resume")
    expect_identical(resumed$generation, r$generation)
    expect_identical(resumed$mount_token, r$token)
    for (counter in c("applied_revision", "gesture_watermark", "bubble_watermark", "dismissed_bubble_revision")) {
      expect_identical(resumed[[counter]], 0L)
    }
    # Until the new session sends a state the page keeps what it shows, bubble included.
    expect_identical(r$afterResume$status$text, "Old")
    expect_identical(r$afterResume$bubble$text, "Old")
    expect_identical(r$adopted$status$text, "New")
    expect_identical(r$adopted$snapshot$applied_revision, 1L)
    expect_identical(r$adopted$snapshot$gesture_watermark, 1L)
    # The new session's state wins: the old session's bubble is gone, and nothing reopens it.
    expect_null(r$adopted$bubble)
    expect_identical(r$adopted$snapshot$bubble_watermark, 0L)
    expect_identical(unlist(r$calls), c("nod", "wave"))
    expect_identical(r$recovery$lifecycle, "resume")
    expect_identical(r$recovery$applied_revision, 0L)
    expect_false(is.null(r$recovery$baseline))
    expect_identical(r$later$status$text, "Next")
    expect_identical(r$later$snapshot$applied_revision, 2L)
    expect_identical(r$later$snapshot$bubble_watermark, 1L)
  })

  it("restores all state together, uses shown status for ARIA and rejects duplicate live ids", {
    js <- protocol_page()
    r <- js(
      "(() => {
      const blob=mascot.readCharacter('blob');blob.moods.processing={...blob.moods.idle,status:'Scanning',fallback:'idle'};
      send(envelope(1,{character:{id:blob.id,name:'Blob',json:JSON.stringify(blob)},mood:'processing',
        status:{mode:'mood'},size:{size:96,small_screen:null},placement:{...base.placement,floating:false,minimise:false,drag:false},
        motion:{...base.motion,reduced:true}},{restore:true}));
      const aria=el.querySelector('canvas').getAttribute('aria-label'),text=el.querySelector('.mascot-status').textContent;
      const duplicate=el.cloneNode(true),warnings=[],warn=console.warn;duplicate.id=el.id;document.body.append(duplicate);
      console.warn=e=>warnings.push(String(e));const accepted=mascot.host.mount(duplicate);console.warn=warn;
      const original=read();duplicate.remove();return {aria,text,accepted,warnings,original,duplicate:mascot.host.state(duplicate)};})()"
    )
    expect_identical(r$aria, "Blob, Scanning")
    expect_identical(r$text, "Scanning")
    expect_false(r$accepted)
    expect_null(r$duplicate)
    expect_match(r$warnings[[1]], "duplicate live")
    expect_identical(r$original$character, "blob")
    expect_identical(r$original$mood, "processing")
    expect_identical(r$original$size$size, 96L)
  })
})
