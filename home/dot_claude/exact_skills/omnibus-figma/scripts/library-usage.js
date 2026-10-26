// Pass as figma_execute `code`. Fill KEYS with a library's published component keys
// (figma_get_library_components); leave it empty to list every main component in use.
const KEYS = new Set([]);
await figma.loadAllPagesAsync();
const used = new Map();
for (const page of figma.root.children) {
  for (const inst of page.findAllWithCriteria({ types: ['INSTANCE'] })) {
    const main = await inst.getMainComponentAsync();
    if (!main) continue;
    // A variant's key differs from its set's key, so match either.
    const top = main.parent && main.parent.type === 'COMPONENT_SET' ? main.parent : main;
    if (KEYS.size && !KEYS.has(top.key) && !KEYS.has(main.key)) continue;
    const row = used.get(top.key) ?? { name: top.name, remote: top.remote, count: 0, pages: new Set() };
    row.count++;
    row.pages.add(page.name);
    used.set(top.key, row);
  }
}
return {
  file: figma.root.name,
  matches: [...used].map(([key, r]) => ({ key, name: r.name, remote: r.remote, count: r.count, pages: [...r.pages] })),
};
