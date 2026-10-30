const fs = require('fs');
const path = require('path');

function updateFaviconToPng(dir) {
    const files = fs.readdirSync(dir);
    for (const file of files) {
        const fullPath = path.join(dir, file);
        if (fs.statSync(fullPath).isDirectory()) {
            updateFaviconToPng(fullPath);
        } else if (fullPath.endsWith('.html')) {
            let content = fs.readFileSync(fullPath, 'utf8');
            let changed = false;
            
            if (content.includes('favicon.jpeg')) {
                content = content.replace(/favicon\.jpeg/g, 'favicon.png');
                changed = true;
            }
            if (content.includes('type="image/jpeg"')) {
                content = content.replace(/type="image\/jpeg"/g, 'type="image/png"');
                changed = true;
            }
            
            if (changed) {
                fs.writeFileSync(fullPath, content);
                console.log('Updated to transparent PNG in', fullPath);
            }
        }
    }
}

updateFaviconToPng('frontend');
