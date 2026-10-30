const fs = require('fs');
let content = fs.readFileSync('./frontend/pages/user/dashboard.html', 'utf8');

const oldImageFunc = /function fieldImage\(field\) \{[\s\S]*?return '\/assets\/images\/saha-1\.jpeg';\n      \}/;
const newImageFunc = `function fieldImage(field) {
        const text = field.name.toLowerCase();
        if (text.includes('inter')) return '/assets/images/saha-7.jpeg';
        if (text.includes('hal')) return '/assets/images/saha-14.jpeg';
        if (text.includes('teni')) return '/assets/images/saha-25.jpeg';
        if (text.includes('voley')) return '/assets/images/saha-5.jpeg';
        if (text.includes('basket')) return '/assets/images/saha-6.jpeg';
        if (text.includes('dans')) return '/assets/images/saha-24.jpeg';
        if (text.includes('sanat')) return '/assets/images/saha-23.jpeg';
        if (text.includes('z') && text.includes('m')) return '/assets/images/saha-26.jpeg'; // müzik
        if (text.includes('padel')) return '/assets/images/saha-11.jpeg';
        if (text.includes('havuz')) return '/assets/images/saha-15.jpeg';
        return '/assets/images/saha-1.jpeg';
      }`;

if(content.match(oldImageFunc)) {
    content = content.replace(oldImageFunc, newImageFunc);
    fs.writeFileSync('./frontend/pages/user/dashboard.html', content, 'utf8');
    console.log('Image matching improved!');
} else {
    console.log('Regex did not match');
}
