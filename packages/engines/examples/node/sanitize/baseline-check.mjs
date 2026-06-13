// Sharp-free baseline validation: confirms the prebuilt wasm + engine work in Node
// on this machine, before any C++ change. Run: node baseline-check.mjs
import { readFile } from 'fs/promises';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

import { init } from '@embedpdf/pdfium';
import { PdfiumNative, PdfEngine } from '@embedpdf/engines/pdfium';
import { ConsoleLogger } from '@embedpdf/models';

const __dirname = dirname(fileURLToPath(import.meta.url));

const logger = new ConsoleLogger();
const pdfiumModule = await init();
const native = new PdfiumNative(pdfiumModule, { logger });
// No imageConverter: sanitize/metadata/save ops never render, so it is unused here.
const engine = new PdfEngine(native, { logger });

const pdfBuffer = await readFile(join(__dirname, '..', 'sample.pdf'));
const doc = await engine
  .openDocumentBuffer({ id: 'baseline', content: pdfBuffer })
  .toPromise();

const meta = await engine.getMetadata(doc).toPromise();
console.log('metadata:', meta);

const attachments = await engine.getAttachments(doc).toPromise();
console.log('attachments:', attachments.length);

const out = await engine.saveAsCopy(doc).toPromise();
console.log('saveAsCopy bytes:', out.byteLength, 'header:', Buffer.from(out.slice(0, 5)).toString());

await engine.closeDocument(doc).toPromise();
console.log('BASELINE OK');
process.exit(0);
