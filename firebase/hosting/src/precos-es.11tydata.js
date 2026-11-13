// Pricing page: built only while site.flags.pricingPage is on. Keep it off until
// the new plan limits are in the app on both stores (epic #721).
const site = require("./_data/site.json");

module.exports = {
  permalink: site.flags.pricingPage ? "/precos-es.html" : false,
  eleventyExcludeFromCollections: !site.flags.pricingPage,
};
