const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const b = await chromium.launch({executablePath: '/opt/pw-browsers/chromium'}).catch(async()=>await chromium.launch());
  const p = await b.newPage({viewport:{width:1800,height:1700}});
  const dir = process.argv[2];
  for (const f of fs.readdirSync(dir).filter(x=>x.endsWith('.dc.html'))) {
    let s = fs.readFileSync(dir+'/'+f,'utf8');
    const dark = s.includes('"default": true');
    s = s.replace(/\{\{theme\}\}/g, dark?'dark':'light').replace('<script src="./support.js"></script>','');
    s = s.replace(/<sc-if[^>]*>/g,'').replace(/<\/sc-if>/g,'');
    await p.setContent(s, {waitUntil:'load'}); await p.waitForTimeout(300);
    const el = await p.$('x-dc > div');
    await el.screenshot({path: (process.argv[3]||'f26shots')+'/'+f.replace('.dc.html','.png')});
  }
  await b.close();
})();
