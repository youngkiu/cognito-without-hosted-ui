import puppeteer from 'puppeteer';
import url from 'url';

// https://stackoverflow.com/questions/2090551/parse-query-string-in-javascript
function parseQuery(queryString) {
    const query = {};
    const pairs = (queryString[0] === '?' ? queryString.substring(1) : queryString).split('&');
    for (let i = 0; i < pairs.length; i++) {
        const pair = pairs[i].split('=');
        query[decodeURIComponent(pair[0])] = decodeURIComponent(pair[1] || '');
    }
    return query;
}

async function getCode(domainName, clientId, redirectUri, username, password) {
    const RESPONSE_TYPE = 'code';
    const autorizeUri = `https://${domainName}/oauth2/authorize?response_type=${RESPONSE_TYPE}&client_id=${clientId}&redirect_uri=${redirectUri}`;

    const browser = await puppeteer.launch();
    const page = await browser.newPage();

    let callbackUrlWithCode = null;

    // https://stackoverflow.com/questions/46886832/how-to-stop-puppeteer-follow-redirects
    await page.setRequestInterception(true);
    page.on('request', request => {
        if (callbackUrlWithCode) {
            request.abort();
            console.log(callbackUrlWithCode);
        } else {
            request.continue();
        }
    });

    // https://stackoverflow.com/questions/48986851/puppeteer-get-request-redirects
    page.on('response', response => {
        const status = response.status()
        if ((status >= 300) && (status <= 399)) {
            console.log(status, 'Redirect from', response.url(), 'to', response.headers()['location'])
            if (response.headers()['location'].startsWith(redirectUri)) {
                callbackUrlWithCode = response.headers()['location'];
            }
        }
    })

    await page.goto(autorizeUri, {waitUntil: 'networkidle0'});

    await page.waitForSelector('input[name="username"]');
    await page.type('input[name="username"]', username);
    await page.type('input[name="password"]', password);
    // await Promise.all([
    //     page.click('input[type="submit"]'),
    //     page.waitForNavigation({ waitUntil: 'networkidle0' }),
    // ]);
    await page.click('input[type="submit"]');
    await page.waitForNavigation({ waitUntil: 'networkidle0' });

    await browser.close();

    const parsedCallbackUri = url.parse(callbackUrlWithCode);
    const parsedQuery = parseQuery(parsedCallbackUri.query);
    return parsedQuery.code;
}

async function main(domainName, clientId, clientSecret, redirectUri, username, password) {
    const code = await getCode(domainName, clientId, redirectUri, username, password);
    console.log(code);
}

const AUTH_DOMAIN = process.env.AUTH_DOMAIN;
const CLIENT_ID = process.env.CLIENT_ID;
const CLIENT_SECRET = process.env.CLIENT_SECRET;
const REDIRECT_URI = process.env.REDIRECT_URI;
const USERNAME = process.env.USERNAME;
const PASSWORD = process.env.PASSWORD;

main(AUTH_DOMAIN, CLIENT_ID, CLIENT_SECRET, REDIRECT_URI, USERNAME, PASSWORD);
