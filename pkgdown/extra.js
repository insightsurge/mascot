// Search results that open on the site being read (#457). pkgdown writes each page's full address into
// search.json, built from `url:` in _pkgdown.yml, and its search opens that address as it is. In a local preview
// or on any other host, that address is a different site, so results would leave the site being read. pkgdown
// loads the index with fetch(), so this rewrites the addresses in it to the folder that holds search.json.
(() => {
  const fetchIndex = window.fetch;
  window.fetch = async (resource, ...rest) => {
    const response = await fetchIndex(resource, ...rest);
    const address = typeof resource === 'string' ? resource : resource.url;
    if (!/(^|\/)search\.json$/.test(address) || !response.ok) {
      return response;
    }
    const entries = await response.clone().json();
    const paths = entries.map((entry) => entry.path).filter((path) => typeof path === 'string');
    // The home page has the shortest address that ends in index.html; the site's address is that minus the file.
    const home = paths.filter((path) => path.endsWith('/index.html')).sort((a, b) => a.length - b.length)[0];
    if (!home) {
      return response;
    }
    const written = home.slice(0, -'index.html'.length);
    const served = new URL('./', new URL(address, window.location.href)).href;
    for (const entry of entries) {
      if (typeof entry.path === 'string' && entry.path.startsWith(written)) {
        entry.path = served + entry.path.slice(written.length);
      }
    }
    return new Response(JSON.stringify(entries), { headers: { 'Content-Type': 'application/json' } });
  };
})();
