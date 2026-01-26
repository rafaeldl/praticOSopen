module.exports = function(eleventyConfig) {
  // Passthrough copy for static assets
  eleventyConfig.addPassthroughCopy("src/css");
  eleventyConfig.addPassthroughCopy("src/assets");
  eleventyConfig.addPassthroughCopy("src/style.css");

  // Watch for changes
  eleventyConfig.addWatchTarget("src/css/");
  eleventyConfig.addWatchTarget("src/assets/");

  // Custom filter to get localized data
  eleventyConfig.addFilter("localize", function(obj, lang) {
    if (obj && obj[lang]) {
      return obj[lang];
    }
    return obj;
  });

  // Custom filter to get relative path prefix based on depth
  eleventyConfig.addFilter("relPath", function(url) {
    const depth = (url.match(/\//g) || []).length - 1;
    if (depth <= 0) return "./";
    return "../".repeat(depth);
  });

  return {
    dir: {
      input: "src",
      output: "public",
      includes: "_includes",
      data: "_data"
    },
    templateFormats: ["njk", "html", "md"],
    htmlTemplateEngine: "njk",
    markdownTemplateEngine: "njk"
  };
};
