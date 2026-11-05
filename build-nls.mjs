// 运行时 NLS 生成器:按当前安装的 nls.keys.json 顺序生成对齐的中文消息数组。
// 用法: node build-nls.mjs <outDir> <nls-zh-map.json> <nls-en-zh-dict.json> <输出文件>
// 翻译来源优先级: 官方 zh-hans 语言包(mod+key) > 英文->中文大字典 > 保留英文
import fs from 'node:fs';
import path from 'node:path';

const [outDir, mapFile, dictFile, outFile] = process.argv.slice(2);
if (!outDir || !mapFile || !dictFile || !outFile) {
  console.error('usage: node build-nls.mjs <outDir> <mapFile> <dictFile> <outFile>');
  process.exit(1);
}

const keys = JSON.parse(fs.readFileSync(path.join(outDir, 'nls.keys.json'), 'utf8'));
const msgs = JSON.parse(fs.readFileSync(path.join(outDir, 'nls.messages.json'), 'utf8'));
const pack = JSON.parse(fs.readFileSync(mapFile, 'utf8'));
const dict = JSON.parse(fs.readFileSync(dictFile, 'utf8'));

const flat = [];
for (const [mod, ks] of keys) {
  for (const k of ks) flat.push([mod, typeof k === 'string' ? k : k.key]);
}
if (flat.length !== msgs.length) {
  console.error(`length mismatch: keys ${flat.length} vs msgs ${msgs.length}`);
  process.exit(1);
}

const contents = pack.contents || {};
let packHit = 0, dictHit = 0, en = 0;
const out = msgs.slice();
for (let i = 0; i < flat.length; i++) {
  const [mod, k] = flat[i];
  const tr = contents?.[mod]?.[k];
  if (tr !== undefined && /[一-鿿]/.test(tr)) { out[i] = tr; packHit++; continue; }
  const enStr = msgs[i];
  if (typeof enStr === 'string' && dict[enStr] !== undefined) { out[i] = dict[enStr]; dictHit++; continue; }
  en++;
}
fs.writeFileSync(outFile, JSON.stringify(out));
console.log(`total=${flat.length} pack=${packHit} dict=${dictHit} english=${en} -> ${outFile}`);
