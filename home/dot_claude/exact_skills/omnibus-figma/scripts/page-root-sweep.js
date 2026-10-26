// Pass as figma_execute `code`. Lists page-root nodes that don't belong there; deletes nothing.
await figma.loadAllPagesAsync();
const belongs = n => n.type === 'SECTION' || /Header$/.test(n.name) || n.name === 'Cover' || n.name === 'About';
return figma.root.children.flatMap(page =>
  page.children.filter(n => !belongs(n)).map(n => ({
    page: page.name, id: n.id, type: n.type, name: n.name.slice(0, 60),
    x: Math.round(n.x), y: Math.round(n.y), visible: n.visible,
  })),
);
