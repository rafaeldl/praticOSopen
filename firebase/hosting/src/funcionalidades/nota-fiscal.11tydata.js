// The service invoice page exists only in Portuguese (the NFS-e is Brazil-only)
// and only while site.flags.nfsePage is on: with the flag off it is not built.
const site = require("../_data/site.json");

module.exports = {
  permalink: site.flags.nfsePage ? "funcionalidades/nota-fiscal.html" : false,
  eleventyExcludeFromCollections: !site.flags.nfsePage,
};
