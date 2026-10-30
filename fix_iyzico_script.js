const fs = require('fs');
let c = fs.readFileSync('frontend/pages/user/dashboard.html', 'utf8');

const target = "container.innerHTML = data.checkoutFormContent + '<div id=\"iyzipay-checkout-form\" class=\"responsive\"></div>';";
const replacement = `
            container.innerHTML = '<div id="iyzipay-checkout-form" class="responsive"></div>';
            // Extract the script from the response and run it manually
            const temp = document.createElement('div');
            temp.innerHTML = data.checkoutFormContent;
            const scripts = temp.getElementsByTagName('script');
            for (let i = 0; i < scripts.length; i++) {
                const s = document.createElement('script');
                s.type = 'text/javascript';
                if (scripts[i].src) {
                    s.src = scripts[i].src;
                } else {
                    s.text = scripts[i].innerText;
                }
                document.body.appendChild(s);
            }
`;

if (c.includes(target)) {
    c = c.replace(target, replacement);
    fs.writeFileSync('frontend/pages/user/dashboard.html', c);
    console.log('Fixed script execution');
} else {
    console.log('Could not find target line');
}
