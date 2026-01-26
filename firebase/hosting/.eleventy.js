module.exports = function(eleventyConfig) {
  // Passthrough copy for CSS from src/
  eleventyConfig.addPassthroughCopy("src/css");

  // Watch CSS for changes
  eleventyConfig.addWatchTarget("src/css/");

  // Note: Static assets (style.css, assets/, components/) are already in public/
  // No passthrough copy needed since output dir is also public/

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
