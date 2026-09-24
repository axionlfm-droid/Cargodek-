const fs = require('fs');
const vm = require('vm');

const html = fs.readFileSync('index.html', 'utf8');
const scripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)]
  .map(match => match[1])
  .filter(Boolean);

if (!scripts.length) {
  throw new Error('CargoDek validation failed: no JavaScript blocks found in index.html');
}

const source = scripts.join('\n;\n');

try {
  new vm.Script(source, { filename: 'cargodek-inline.js' });
} catch (error) {
  console.error('CargoDek frontend JavaScript syntax validation failed.');
  console.error(error.stack || error.message || error);
  process.exit(1);
}

if (/\basync\s+async\s+function\b/.test(source)) {
  throw new Error('CargoDek validation failed: duplicate async function modifier detected.');
}

console.log(`CargoDek frontend syntax OK. Validated ${scripts.length} JavaScript block(s).`);
