#!/usr/bin/env node
// The service invoice (NFS-e) exists only in Brazil, so it is sold only on the
// Portuguese pages. Fails the build if an English or Spanish page mentions it.
//
// Legal texts are the exception: the privacy policy and the certificate terms
// must describe the same processing in every language.
const fs = require("fs");
const path = require("path");

const PUBLIC_DIR = path.join(__dirname, "..", "public");
const TERMS = /nota fiscal|NFS-e|Emissor Nacional/i;
const LEGAL = new Set(["privacy-en.html", "privacy-es.html", "termo-certificado-en.html", "termo-certificado-es.html"]);

function htmlFiles(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return htmlFiles(full);
    return entry.name.endsWith(".html") ? [full] : [];
  });
}

function findViolations(publicDir = PUBLIC_DIR) {
  return htmlFiles(publicDir)
    .filter((file) => /-(en|es)\.html$/.test(file))
    .filter((file) => !LEGAL.has(path.relative(publicDir, file)))
    .flatMap((file) => {
      const match = fs.readFileSync(file, "utf8").match(TERMS);
      return match ? [`${path.relative(publicDir, file)}: "${match[0]}"`] : [];
    });
}

if (require.main === module) {
  if (!fs.existsSync(PUBLIC_DIR)) {
    console.error("check-br-only: public/ not found, run the build first");
    process.exit(1);
  }
  const violations = findViolations();
  if (violations.length) {
    console.error("A nota fiscal só aparece nas páginas em português. Encontrada em:");
    violations.forEach((v) => console.error(`  ${v}`));
    process.exit(1);
  }
  console.log("check-br-only: no service invoice mention on -en/-es pages");
}

module.exports = { findViolations };
