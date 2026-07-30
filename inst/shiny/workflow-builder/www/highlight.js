// Tiny, dependency-free syntax highlighter for the generated .qmd preview.
// Colours a handful of tokens (chunk fences, cell options, headings, comments,
// strings, function calls) that appear in the workflow the builder emits -- it
// is not a general R/Quarto parser, just enough to make the preview readable.
// Re-runs on every Shiny output update; the copy button still reads innerText,
// so highlighting does not affect the copied code.
(function () {
  function esc(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  // Highlight one line of R code: stash strings and trailing comments behind
  // "@@n@@" placeholders (that sequence never appears in the emitted workflow),
  // so the function-call pass cannot reach inside them; then restore the spans.
  function hlCode(line) {
    var stash = [];
    function keep(html) {
      stash.push(html);
      return "@@" + (stash.length - 1) + "@@";
    }
    var e = esc(line);
    e = e.replace(/"[^"]*"/g, function (m) {
      return keep('<span class="tok-str">' + m + "</span>");
    });
    e = e.replace(/#.*/g, function (m) {
      return keep('<span class="tok-com">' + m + "</span>");
    });
    e = e.replace(/([A-Za-z_][A-Za-z0-9_.]*)(?=\()/g, '<span class="tok-fn">$1</span>');
    e = e.replace(/@@(\d+)@@/g, function (_, i) {
      return stash[+i];
    });
    return e;
  }

  function highlight(text) {
    return text
      .split("\n")
      .map(function (line) {
        if (/^```/.test(line) || /^---\s*$/.test(line)) {
          return '<span class="tok-fence">' + esc(line) + "</span>";
        }
        if (/^#\|/.test(line)) {
          return '<span class="tok-opt">' + esc(line) + "</span>";
        }
        // Markdown headings in the emitted qmd are always "##"+; a single "#"
        // is an R comment, handled (green) inside hlCode().
        if (/^\s*#{2,6}\s/.test(line)) {
          return '<span class="tok-head">' + esc(line) + "</span>";
        }
        return hlCode(line);
      })
      .join("\n");
  }

  document.addEventListener("DOMContentLoaded", function () {
    // Shiny re-sets the <pre> text on every update; re-highlight just after.
    $(document).on("shiny:value", function (e) {
      if (e.name !== "qmd_preview") return;
      setTimeout(function () {
        var el = document.getElementById("qmd_preview");
        if (el) el.innerHTML = highlight(el.textContent);
      }, 0);
    });
  });
})();
