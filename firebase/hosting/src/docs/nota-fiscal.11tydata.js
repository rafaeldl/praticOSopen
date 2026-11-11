// Brazil-only help article: built only while site.flags.nfsePage is on.
const site = require("../_data/site.json");

module.exports = {
  permalink: site.flags.nfsePage ? "/docs/nota-fiscal.html" : false,
  eleventyExcludeFromCollections: !site.flags.nfsePage,
};
