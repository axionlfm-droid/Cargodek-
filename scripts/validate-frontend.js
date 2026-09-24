const fs = require('fs');
const vm = require('vm');

const html = fs.readFileSync('index.html', 'utf8');
const scripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)]
  .map((match, index) => ({ index: index + 1, source: match[1] }))
  .filter(script => script.source.trim());

if (!scripts.length) {
  throw new Error('CargoDek validation failed: no JavaScript blocks found in index.html');
}

for (const script of scripts) {
  try {
    new vm.Script(script.source, { filename: `cargodek-inline-${script.index}.js` });
  } catch (error) {
    console.error(`CargoDek frontend JavaScript syntax validation failed in script block ${script.index}.`);
    console.error(error.stack || error.message || error);
    process.exit(1);
  }

  if (/\basync\s+async\s+function\b/.test(script.source)) {
    throw new Error(`CargoDek validation failed in script block ${script.index}: duplicate async function modifier detected.`);
  }
}

console.log(`CargoDek frontend syntax OK. Validated ${scripts.length} JavaScript block(s) independently.`);
