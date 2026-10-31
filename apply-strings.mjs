// 两遍替换:
//  pass1: molten-zh-map.json  -> 裸带引号字面量(仅限多词短语 key,安全)
//  pass2: prop-zh-map.json    -> 仅当值出现在展示型属性名后时替换(单词级 key 也安全)
// 用法: node apply-strings.mjs <phraseDict> <propDict> <file-or-dir> [...]
import fs from 'fs';
import path from 'path';

const [phrasePath, propPath, ...targets] = process.argv.slice(2);
const phrase = JSON.parse(fs.readFileSync(phrasePath, 'utf8'));
const prop = JSON.parse(fs.readFileSync(propPath, 'utf8'));

const esc = s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const pk = Object.keys(phrase).filter(k => !/["'`\\]/.test(k));
const rePhrase = pk.length ? new RegExp('(["\'`])(' + pk.map(esc).join('|') + ')\\1', 'g') : null;

// 展示型属性名 + Cursor 设置导航 id 键
const PROPS = [
  'label', 'title', 'description', 'placeholder', 'tooltip', 'header', 'caption', 'subtitle',
  'pageTitle', 'emptyLabel', 'emptyText', 'ariaLabel', 'accessibleLabel', 'containerAriaLabel',
  'columnHeader', 'allLabel', 'nameColumn', 'typeColumn', 'headerLabel', 'navLabel', 'tabLabel',
  'buttonText', 'confirmText', 'cancelText', 'badgeText', 'ctaText', 'summary', 'hint',
  'aria-label', 'text', 'children',
  'heading', 'subheading', 'hintText', 'helperText', 'tooltipText', 'placeholderText',
  'settings', 'collectionLabel', 'projectAgentsSectionLabel', 'sectionLabel', 'groupLabel',
  'actionLabel', 'itemLabel', 'optionLabel', 'sublabel', 'menuLabel', 'buttonLabel',
  'linkLabel', 'statusText', 'notice', 'bannerText', 'emptyStateTitle', 'emptyStateText',
  'footerText', 'accessibleName', 'repositoriesColumn', 'appsColumn', 'scopeColumn',
  'columnLabel', 'textLabel',
  // 设置导航对象键(如 {general:"General",chat:"Agents"})
  'general', 'appearance', 'plan-usage', 'chat', 'browser', 'git-prs', 'models', 'voice',
  'indexing', 'mcp', 'hooks', 'beta', 'network', 'background-composer', 'rules', 'plugins',
  'customize', 'docs', 'contact', 'back', 'fun', 'files', 'projects', 'repositories',
  'automations', 'marketplace',
];
const qk = Object.keys(prop).filter(k => !/["'`\\]/.test(k));
const reProp = qk.length
  ? new RegExp('(["\']?(?:' + PROPS.map(esc).join('|') + ')["\']?\\s*:\\s*)(["\'`])(' + qk.map(esc).join('|') + ')\\2', 'g')
  : null;

function* walk(p) {
  const st = fs.statSync(p);
  if (st.isDirectory()) { for (const e of fs.readdirSync(p)) yield* walk(path.join(p, e)); }
  else if (/\.(js|cjs)$/.test(p)) yield p;
}

let patched = 0, restored = 0, scanned = 0;
for (const t of targets) {
  if (!fs.existsSync(t)) continue;
  for (const f of walk(t)) {
    scanned++;
    const bak = f + '.zhorig';
    if (fs.existsSync(bak)) { fs.copyFileSync(bak, f); restored++; }
    let s = fs.readFileSync(f, 'utf8');
    const orig = s;
    if (rePhrase) s = s.replace(rePhrase, (m, q, k) => q + phrase[k] + q);
    if (reProp) s = s.replace(reProp, (m, pre, q, k) => pre + q + prop[k] + q);
    if (s !== orig) {
      if (!fs.existsSync(bak)) fs.copyFileSync(f, bak);
      fs.writeFileSync(f, s, 'utf8');
      patched++;
    }
  }
}
console.log(`scanned=${scanned} patched=${patched} replayed=${restored}`);
