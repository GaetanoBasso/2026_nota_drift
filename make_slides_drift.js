// Builds slides_drift.pptx (2 slides) from the graphs written by an_lp_energy_ea.do.
// Run from the repository root: node make_slides_drift.js  (needs the npm package pptxgenjs)
// Missing graphs are replaced by a placeholder box; rerun after master.do to insert them.
const fs = require("fs");
const path = require("path");
const pptxgen = require("pptxgenjs");

const GPH = path.join(__dirname, "graphs");
const INK = "1F2937";     // text
const MUTED = "5B6472";   // footnotes
const FILL = "F1F3F5";    // placeholder fill
const FONT = "Arial";

// Sample period written by Stata (graphs/smp_*.tex), or a placeholder
function sample(name) {
  const f = path.join(GPH, `smp_${name}.tex`);
  if (!fs.existsSync(f)) return "[sample period: available after running master.do]";
  return fs.readFileSync(f, "utf8").trim().replace(/--/g, "–");
}

// Graph if it exists, otherwise a placeholder box of the same size
function graph(slide, file, x, y, w, h) {
  const f = path.join(GPH, file);
  if (fs.existsSync(f)) {
    slide.addImage({ path: f, x, y, w, h, altText: file, objectName: file });
  } else {
    slide.addText(`Graph to be inserted: graphs/${file}\n(produced by the Stata run of master.do)`, {
      x, y, w, h, isTextBox: true, align: "center", valign: "middle",
      fontFace: FONT, fontSize: 14, color: MUTED,
      fill: { color: FILL }, line: { color: "D0D4DA", width: 0.75 },
      objectName: `placeholder ${file}`,
    });
  }
}

function label(slide, text, x, y, w) {
  slide.addText(text, {
    x, y, w, h: 0.4, isTextBox: true, margin: 0, align: "center",
    fontFace: FONT, fontSize: 16, bold: true, color: INK,
  });
}

// Commento sui risultati (segnaposto finché i risultati IV non sono stati letti)
function takeaway(slide, text) {
  slide.addText([
    { text: "Takeaway: ", options: { bold: true, color: INK } },
    { text, options: { color: "C00000" } },
  ], { x: 0.5, y: 1.0, w: 12.33, h: 0.4, isTextBox: true, margin: 0, valign: "middle",
    fontFace: FONT, fontSize: 14 });
}

function footnote(slide, text, y) {
  slide.addText(text, {
    x: 0.5, y, w: 12.33, h: 0.75, isTextBox: true, margin: 0, valign: "top",
    fontFace: FONT, fontSize: 10, color: MUTED,
  });
}

const pres = new pptxgen();
pres.layout = "LAYOUT_WIDE"; // 13.33 x 7.5 in
pres.title = "Energy price shocks and euro-area wages";
pres.theme = { headFontFace: FONT, bodyFontFace: FONT };

pres.defineSlideMaster({
  title: "TITLE_ONLY",
  background: { color: "FFFFFF" },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.5, y: 0.3, w: 12.33, h: 0.7,
        fontFace: FONT, fontSize: 28, bold: true, color: INK, align: "left", valign: "middle", margin: 0 },
      text: "" } },
  ],
  slideNumber: { x: 12.4, y: 7.0, w: 0.5, h: 0.3, fontFace: FONT, fontSize: 10, color: MUTED },
});

const RESP = "Response (percentage points) of year-on-year wage growth to a 10% " +
  "increase in the oil and natural gas prices; 90% confidence bands. " +
  "Smooth 2SLS local projections (Barnichon\u2013Brownlees; bands by undersmoothing): the oil price is instrumented with the Mori\u2013Peersman oil supply news shocks, " +
  "the gas price with the Alessandri\u2013Gazzani gas supply shocks (quarterly average of the monthly shocks).";

pres.addSection({ title: "Results" });

// Slide 1: euro area, negotiated wages and hourly wages (Stata default 5.5 x 4 format)
let s = pres.addSlide({ masterName: "TITLE_ONLY", sectionTitle: "Results" });
s.addText("Euro area: wage response to oil and gas supply shocks (IV)", { placeholder: "title" });
takeaway(s, "[TO BE COMPLETED: response of euro-area negotiated and hourly wages to oil and gas price increases driven by supply shocks]");
label(s, "Negotiated wages", 0.5, 1.5, 6.0);
label(s, "Gross wages per hour worked", 6.83, 1.5, 6.0);
graph(s, "lp_iv_og_EA_contr.png", 0.5, 1.95, 6.0, 4.36);
graph(s, "lp_iv_og_EA_wageH.png", 6.83, 1.95, 6.0, 4.36);
footnote(s, `${RESP} Euro-area time series, Newey\u2013West standard errors. Sample (shock dates): ` +
  `negotiated wages, ${sample("lp_iv_og_EA_contr")}; hourly wages, ${sample("lp_iv_og_EA_wageH")}.`, 6.45);

// Slide 2: euro area and countries (square versions)
s = pres.addSlide({ masterName: "TITLE_ONLY", sectionTitle: "Results" });
s.addText("Countries: wage response to oil and gas supply shocks (IV)", { placeholder: "title" });
takeaway(s, "[TO BE COMPLETED: cross-country differences in the IV responses and oil versus gas]");
label(s, "Negotiated wages", 0.5, 1.5, 6.0);
label(s, "Gross wages per hour worked", 6.83, 1.5, 6.0);
graph(s, "lp_iv_og_ctry_contr_sq.png", 1.3, 1.95, 4.4, 4.4);
graph(s, "lp_iv_og_ctry_wageH_sq.png", 7.63, 1.95, 4.4, 4.4);
footnote(s, `${RESP} Time series for the euro area and each country, Newey\u2013West standard errors; ` +
  "same vertical scale in all panels unless the widths of the confidence bands differ by more than 1.6 pp " +
  "(then each panel has its own scale, with the same spacing between labels); the sample period (shock dates) of each panel is shown under its name.", 6.45);

pres.writeFile({ fileName: path.join(__dirname, "slides_drift.pptx") })
  .then((f) => console.log(`written ${f}`));
