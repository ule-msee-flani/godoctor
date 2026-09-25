// Reads an MP4's header and prints duration, size and codecs, so a splash
// video can be sanity-checked without ffmpeg.   node tool/probe_mp4.js <file>
const fs = require('fs');
const buf = fs.readFileSync(process.argv[2]);

function* boxes(start, end) {
  let o = start;
  while (o + 8 <= end) {
    let size = buf.readUInt32BE(o);
    const type = buf.toString('latin1', o + 4, o + 8);
    let header = 8;
    if (size === 1) { size = Number(buf.readBigUInt64BE(o + 8)); header = 16; }
    if (size === 0) size = end - o;
    if (size < header) return;
    yield { type, start: o + header, end: o + size };
    o += size;
  }
}
const find = (s, e, path) => {
  const [head, ...rest] = path;
  for (const b of boxes(s, e)) if (b.type === head) return rest.length ? find(b.start, b.end, rest) : b;
  return null;
};

const moov = find(0, buf.length, ['moov']);
if (!moov) { console.log('No moov box: not a normal MP4 (or moov is missing).'); process.exit(1); }
const mvhd = find(moov.start, moov.end, ['mvhd']);
const ver = buf[mvhd.start];
const timescale = buf.readUInt32BE(mvhd.start + (ver === 1 ? 20 : 12));
const duration = ver === 1 ? Number(buf.readBigUInt64BE(mvhd.start + 24)) : buf.readUInt32BE(mvhd.start + 16);
console.log(`file size : ${(buf.length / 1024).toFixed(0)} KB`);
console.log(`duration  : ${(duration / timescale).toFixed(2)} s`);

let n = 0;
for (const trak of boxes(moov.start, moov.end)) {
  if (trak.type !== 'trak') continue;
  n++;
  const tkhd = find(trak.start, trak.end, ['tkhd']);
  const tv = buf[tkhd.start];
  const wOff = tkhd.start + (tv === 1 ? 88 : 76);
  const w = buf.readUInt32BE(wOff) / 65536, h = buf.readUInt32BE(wOff + 4) / 65536;
  const hdlr = find(trak.start, trak.end, ['mdia', 'hdlr']);
  const kind = buf.toString('latin1', hdlr.start + 8, hdlr.start + 12);
  const stsd = find(trak.start, trak.end, ['mdia', 'minf', 'stbl', 'stsd']);
  const codec = buf.toString('latin1', stsd.start + 12, stsd.start + 16);
  console.log(`track ${n}   : ${kind === 'vide' ? 'video' : kind === 'soun' ? 'audio' : kind}  codec=${codec}${kind === 'vide' ? `  ${w}x${h}` : ''}`);
}
const moovFirst = [...boxes(0, buf.length)].findIndex((b) => b.type === 'moov') < [...boxes(0, buf.length)].findIndex((b) => b.type === 'mdat');
console.log(`streamable: ${moovFirst ? 'yes (moov before mdat)' : 'no (moov after mdat, slower start on web)'}`);
