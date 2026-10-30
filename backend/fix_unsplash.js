const fs = require('fs');
let content = fs.readFileSync('./frontend/pages/user/dashboard.html', 'utf8');

const oldImageFunc = /function fieldImage\(field\) \{[\s\S]*?return '\/assets\/images\/saha-1\.jpeg';\n    \}/;

const newImageFunc = `function fieldImage(field) {
      const text = field.name.toLowerCase();
      if (text.includes('inter')) return 'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?auto=format&fit=crop&w=900&q=80';
      if (text.includes('hal')) return 'https://images.unsplash.com/photo-1518605368461-1ee125232d30?auto=format&fit=crop&w=900&q=80';
      if (text.includes('teni')) return 'https://images.unsplash.com/photo-1622279457486-62dcc4a431d6?auto=format&fit=crop&w=900&q=80';
      if (text.includes('voley')) return 'https://images.unsplash.com/photo-1592656094267-764a45160876?auto=format&fit=crop&w=900&q=80';
      if (text.includes('basket')) return 'https://images.unsplash.com/photo-1546519638-68e109498ffc?auto=format&fit=crop&w=900&q=80';
      if (text.includes('dans')) return 'https://images.unsplash.com/photo-1504609774776-654db5ed5556?auto=format&fit=crop&w=900&q=80';
      if (text.includes('sanat')) return 'https://images.unsplash.com/photo-1460661419201-fd4cecdf8a8b?auto=format&fit=crop&w=900&q=80';
      if (text.includes('z') && text.includes('m')) return 'https://images.unsplash.com/photo-1511379938547-c1f69419868d?auto=format&fit=crop&w=900&q=80';
      if (text.includes('padel')) return 'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?auto=format&fit=crop&w=900&q=80';
      if (text.includes('havuz')) return 'https://images.unsplash.com/photo-1576610616656-d3aa5d1f4534?auto=format&fit=crop&w=900&q=80';
      return 'https://images.unsplash.com/photo-1518605368461-1ee125232d30?auto=format&fit=crop&w=900&q=80';
    }`;

if(content.match(oldImageFunc)) {
    content = content.replace(oldImageFunc, newImageFunc);
    fs.writeFileSync('./frontend/pages/user/dashboard.html', content, 'utf8');
    console.log('Images updated with high-quality Unsplash URLs!');
} else {
    console.log('Regex failed to match');
}
