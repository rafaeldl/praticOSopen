module.exports = function(eleventyConfig) {
  // Passthrough copy for static assets
  eleventyConfig.addPassthroughCopy("src/css");
  eleventyConfig.addPassthroughCopy("src/js");
  eleventyConfig.addPassthroughCopy("src/assets");
  eleventyConfig.addPassthroughCopy("src/style.css");
  eleventyConfig.addPassthroughCopy("src/robots.txt");

  // Watch for changes
  eleventyConfig.addWatchTarget("src/css/");
  eleventyConfig.addWatchTarget("src/js/");
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

  // Resolve a relative href (from langSwitch) against the current page's permalink directory
  // Returns a clean path without leading slash (e.g. "segmentos/automotivo.html")
  eleventyConfig.addFilter("resolveUrl", function(href, permalink) {
    if (!href) return (permalink || "").replace(/^\/+/, "");
    // If href is already absolute, return as-is
    if (href.startsWith("http")) return href;
    // Normalize permalink: strip leading slash
    var cleanPermalink = (permalink || "").replace(/^\/+/, "");
    // Get the directory from the current page's permalink
    var dir = "";
    if (cleanPermalink && cleanPermalink.includes("/")) {
      dir = cleanPermalink.substring(0, cleanPermalink.lastIndexOf("/") + 1);
    }
    // Resolve relative href against directory
    if (href.startsWith("../")) {
      return href.replace("../", "");
    }
    return dir + href;
  });

  // Strip leading slash from a path for building absolute URLs
  eleventyConfig.addFilter("stripLeadingSlash", function(path) {
    return (path || "").replace(/^\/+/, "");
  });

  // Strip index.html from URLs for prettier/canonical URLs
  eleventyConfig.addFilter("prettyUrl", function(url) {
    if (!url) return "/";
    let pretty = url.replace(/index\.html$/, "");
    if (pretty === "") return "./";
    if (pretty !== "/" && pretty.endsWith("/")) {
      // already pretty or directory
    }
    return pretty;
  });

  // Generate absolute URL with base URL
  eleventyConfig.addFilter("siteUrl", function(path, baseUrl) {
    let cleanPath = (path || "").replace(/^\/+/, "");
    // If baseUrl already ends with slash, remove it to be consistent
    let base = (baseUrl || "").replace(/\/+$/, "");
    return base + "/" + cleanPath;
  });

  // Format a date as YYYY-MM-DD for sitemap <lastmod>
  eleventyConfig.addFilter("dateToISO", function(date) {
    return date.toISOString().split('T')[0];
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
