// 按 molten-zh-map.json 对目标 JS 文件做带引号字符串字面量替换。
// 用法: node apply-strings.mjs <dict.json> <file-or-dir> [file-or-dir ...]
// 规则: 若存在 .zhorig 备份,先还原再重放(幂等); 无备份则先备份再替换。
import fs from 'fs';
import path from 'path';

const [dictPath, ...targets] = process.argv.slice(2);
const dict = JSON.parse(fs.readFileSync(dictPath, 'utf8'));
const keys = Object.keys(dict).filter(k => !/["'`\\]/.test(k));
const esc = s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const re = new RegExp('(["\'`])(' + keys.map(esc).join('|') + ')\\1', 'g');

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
    const s = fs.readFileSync(f, 'utf8');
    const out = s.replace(re, (m, q, k) => q + dict[k] + q);
    if (out !== s) {
      if (!fs.existsSync(bak)) fs.copyFileSync(f, bak);
      fs.writeFileSync(f, out, 'utf8');
      patched++;
    }
  }
}
console.log(`scanned=${scanned} patched=${patched} replayed=${restored}`);
