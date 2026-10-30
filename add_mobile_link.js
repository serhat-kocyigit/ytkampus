const fs = require('fs');
let c = fs.readFileSync('frontend/index.html', 'utf8');

// The mobile menu in my earlier updates used `.mobile-nav` or `<nav class="landing-nav" id="mobile-nav">`.
// I will just look for `#hakkimizda` and insert it.
c = c.replace(/<a href="#hakkimizda">/g, '<a href="/mac-izle.html" style="color:#d97706; font-weight:700;">🎥 Maç Videoları</a>\n        <a href="#hakkimizda">');

fs.writeFileSync('frontend/index.html', c);
console.log('done');
