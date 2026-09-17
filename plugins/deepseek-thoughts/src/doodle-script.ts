/**
 * The doodle engine for /deepseek-thoughts.
 *
 * Everything a visitor sees on top of the photographs is drawn here, in the
 * browser, with the Canvas 2D API: hand-trembled strokes, bubbles, boats,
 * kites, and little handwritten labels. Marks are generated from a seed with
 * a small mulberry32 PRNG, so every picture has a stable default doodle and
 * "doodle again" is just a new seed.
 */
export const DOODLE_SCRIPT = `
function setupDeepSeekThoughts() {
  var root = document.querySelector("[data-ds-lab]")
  if (!(root instanceof HTMLElement) || root.getAttribute("data-ds-ready") === "true") return
  var pieces = Array.prototype.slice.call(root.querySelectorAll("[data-ds-piece]"))
  if (pieces.length === 0) return
  root.setAttribute("data-ds-ready", "true")

  var motionQuery = window.matchMedia("(prefers-reduced-motion: reduce)")
  var HAND_FONT = '"Playwrite GB J Guides", "Segoe Print", cursive'
  var states = []
  var byPiece = new Map()
  var byStage = new Map()

  // ---------- colours, randomness, small maths ----------

  function readColour(name, fallback) {
    var value = getComputedStyle(document.documentElement).getPropertyValue(name).trim()
    return value || fallback
  }

  function palette() {
    return {
      ink: readColour("--garden-ink", "#172b4d"),
      rust: readColour("--garden-rust", "#a4432d"),
      leaf: readColour("--garden-leaf", "#536d59"),
      sky: readColour("--garden-sky", "#90a9c5"),
      paper: readColour("--garden-paper", "#f5efe1"),
      navy: "#172b4d",
    }
  }

  function makeRng(seed) {
    var state = (seed >>> 0) || 1
    return function () {
      state += 0x6d2b79f5
      var t = state
      t = Math.imul(t ^ (t >>> 15), t | 1)
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296
    }
  }

  function clamp01(value) {
    return value < 0 ? 0 : value > 1 ? 1 : value
  }

  // ---------- point generators (normalised 0..1 space) ----------

  function qbez(p0, p1, p2, steps, rng, wobble) {
    var pts = []
    for (var i = 0; i <= steps; i++) {
      var t = i / steps
      var mt = 1 - t
      var x = mt * mt * p0[0] + 2 * mt * t * p1[0] + t * t * p2[0]
      var y = mt * mt * p0[1] + 2 * mt * t * p1[1] + t * t * p2[1]
      if (wobble && rng) {
        x += (rng() - 0.5) * wobble
        y += (rng() - 0.5) * wobble
      }
      pts.push([x, y])
    }
    return pts
  }

  function squiggle(from, to, rng, amp, cycles, steps) {
    var amount = amp == null ? 0.01 : amp
    var dx = to[0] - from[0]
    var dy = to[1] - from[1]
    var len = Math.hypot(dx, dy) || 0.0001
    var nx = -dy / len
    var ny = dx / len
    var phase = rng() * Math.PI * 2
    var count = steps || 16
    var pts = []
    for (var i = 0; i <= count; i++) {
      var t = i / count
      var taper = Math.sin(t * Math.PI)
      var offset = Math.sin(t * Math.PI * 2 * (cycles || 2) + phase) * amount * taper
      offset += (rng() - 0.5) * amount * 0.45
      pts.push([from[0] + dx * t + nx * offset, from[1] + dy * t + ny * offset])
    }
    return pts
  }

  function ellipsePts(cx, cy, rx, ry, rng, options) {
    var opts = options || {}
    var start = opts.start == null ? 0 : opts.start
    var end = opts.end == null ? Math.PI * 2 + 0.3 : opts.end
    var wobble = opts.wobble == null ? 0.035 : opts.wobble
    var steps = opts.steps || Math.max(22, Math.round((90 * Math.max(rx, ry)) / 0.08))
    var phase = rng() * Math.PI * 2
    var pts = []
    for (var i = 0; i <= steps; i++) {
      var t = i / steps
      var a = start + (end - start) * t
      var r = 1 + Math.sin(a * 2.4 + phase) * wobble * 0.5 + (rng() - 0.5) * wobble
      pts.push([cx + Math.cos(a) * rx * r, cy + Math.sin(a) * ry * r])
    }
    return pts
  }

  function spiralPts(cx, cy, r0, r1, turns, rng) {
    var steps = Math.max(24, Math.round(turns * 34))
    var phase = rng() * Math.PI * 2
    var pts = []
    for (var i = 0; i <= steps; i++) {
      var t = i / steps
      var a = turns * Math.PI * 2 * t + phase
      var r = r0 + (r1 - r0) * t
      pts.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r])
    }
    return pts
  }

  function heartPts(cx, cy, r, rng) {
    var pts = []
    var steps = 64
    for (var i = 0; i <= steps; i++) {
      var t = (i / steps) * Math.PI * 2
      var x = 16 * Math.pow(Math.sin(t), 3)
      var y = 13 * Math.cos(t) - 5 * Math.cos(2 * t) - 2 * Math.cos(3 * t) - Math.cos(4 * t)
      pts.push([
        cx + (x / 17) * r + (rng() - 0.5) * r * 0.05,
        cy - (y / 17) * r + (rng() - 0.5) * r * 0.05,
      ])
    }
    return pts
  }

  function birdPts(cx, cy, s, rng) {
    var left = qbez([cx - s, cy], [cx - s * 0.5, cy - s * 0.9], [cx, cy], 10, rng, s * 0.06)
    var right = qbez([cx, cy], [cx + s * 0.5, cy - s * 0.9], [cx + s, cy], 10, rng, s * 0.06)
    return left.concat(right.slice(1))
  }

  function wavePts(y, x0, x1, amp, cycles) {
    var steps = 42
    var pts = []
    for (var i = 0; i <= steps; i++) {
      var t = i / steps
      pts.push([x0 + (x1 - x0) * t, y + Math.sin(t * Math.PI * 2 * cycles) * amp])
    }
    return pts
  }

  /** Break a polyline into dash/gap sub-polylines (normalised units). */
  function dashPath(pts, dash, gap) {
    var segments = []
    var current = []
    var carry = 0
    var drawing = true
    for (var i = 1; i < pts.length; i++) {
      var a = pts[i - 1]
      var b = pts[i]
      var seg = Math.hypot(b[0] - a[0], b[1] - a[1])
      var travelled = 0
      while (travelled < seg) {
        var budget = (drawing ? dash : gap) - carry
        var step = Math.min(seg - travelled, budget)
        var t0 = travelled / seg
        var t1 = (travelled + step) / seg
        if (drawing) {
          if (current.length === 0) current.push([a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0])
          current.push([a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1])
        }
        travelled += step
        carry += step
        if (carry >= (drawing ? dash : gap) - 1e-6) {
          if (drawing && current.length > 1) segments.push(current)
          current = []
          drawing = !drawing
          carry = 0
        }
      }
    }
    if (current.length > 1) segments.push(current)
    return segments
  }

  // ---------- marks ----------

  function markLine(pts, colour, width, alpha) {
    return { kind: "line", pts: pts, colour: colour || "rust", width: width || 2.4, alpha: alpha }
  }
  function markDot(x, y, r, colour) {
    return { kind: "dot", x: x, y: y, r: r, colour: colour || "rust" }
  }
  function markSparkle(x, y, r, colour) {
    return { kind: "sparkle", x: x, y: y, r: r, colour: colour || "paper" }
  }
  function markLabel(text, x, y, angle, size, colour) {
    return {
      kind: "label",
      text: text,
      x: x,
      y: y,
      angle: angle || 0,
      size: size || 0.03,
      colour: colour || "ink",
    }
  }

  // ---------- recipes, one per photograph ----------

  var RECIPES = {
    hubble: function (rng) {
      var marks = []
      var stars = [
        [0.135, 0.145],
        [0.305, 0.335],
        [0.445, 0.305],
        [0.565, 0.505],
        [0.745, 0.6],
      ]
      for (var i = 0; i < stars.length - 1; i++) {
        marks.push(markLine(squiggle(stars[i], stars[i + 1], rng, 0.006, 0.8, 12), "rust", 1.6, 0.75))
      }
      stars.forEach(function (star, index) {
        if (index === 0 || index === 3) marks.push(markSparkle(star[0], star[1], 0.012, "paper"))
        else marks.push(markDot(star[0], star[1], 0.006, "paper"))
      })
      marks.push(
        markLine(
          ellipsePts(0.895, 0.785, 0.05, 0.05, rng, { end: Math.PI * 2 + 0.5, wobble: 0.05 }),
          "paper",
          1.8,
          0.8,
        ),
      )
      marks.push(markLine(squiggle([0.705, 0.845], [0.838, 0.8], rng, 0.008, 1.2, 12), "sky", 1.7, 0.85))
      marks.push(markLabel("a whole galaxy", 0.55, 0.888, -5, 0.03, "paper"))
      marks.push(markLabel("you are here", 0.135, 0.635, -6, 0.03, "rust"))
      marks.push(markLine(squiggle([0.255, 0.648], [0.318, 0.61], rng, 0.006, 1, 10), "rust", 1.6, 0.85))
      marks.push(markDot(0.325, 0.606, 0.007, "rust"))
      marks.push(markSparkle(0.72, 0.205, 0.011, "sky"))
      marks.push(markSparkle(0.185, 0.52, 0.01, "paper"))
      marks.push(markSparkle(0.5, 0.9, 0.009, "sky"))
      marks.push(markLine(spiralPts(0.46, 0.76, 0.004, 0.03, 2.4, rng), "sky", 1.6, 0.85))
      return marks
    },

    haeckel: function (rng) {
      var marks = []
      marks.push(markLine(squiggle([0.235, 0.245], [0.128, 0.118], rng, 0.007, 0.9, 12), "rust", 1.9))
      marks.push(markLabel("orbits", 0.3, 0.3, -10, 0.032, "rust"))
      marks.push(markLine(heartPts(0.228, 0.262, 0.026, rng), "rust", 2.2, 0.9))
      ;[
        [0.575, 0.6, 0.017],
        [0.545, 0.525, 0.012],
        [0.522, 0.472, 0.008],
      ].forEach(function (bubble) {
        marks.push(
          markLine(
            ellipsePts(bubble[0], bubble[1], bubble[2], bubble[2] * 0.94, rng, {
              end: Math.PI * 2 + 0.35,
              wobble: 0.05,
            }),
            "navy",
            1.8,
          ),
        )
      })
      marks.push(markLabel("float gently", 0.685, 0.405, -8, 0.032, "rust"))
      marks.push(markLine(wavePts(0.44, 0.6, 0.775, 0.005, 2.5), "rust", 1.6, 0.8))
      return marks
    },

    mirror: function (rng) {
      var marks = []
      var anchors = [
        [0.335, 0.5],
        [0.415, 0.435],
        [0.365, 0.375],
        [0.475, 0.315],
        [0.435, 0.26],
        [0.545, 0.205],
        [0.52, 0.165],
        [0.615, 0.125],
      ]
      var trail = []
      for (var i = 0; i < anchors.length - 1; i++) {
        var a = anchors[i]
        var b = anchors[i + 1]
        var mid = [(a[0] + b[0]) / 2 + (rng() - 0.5) * 0.012, (a[1] + b[1]) / 2 + (rng() - 0.5) * 0.012]
        var piece = qbez(a, mid, b, 8, rng, 0.004)
        trail = trail.concat(i === 0 ? piece : piece.slice(1))
      }
      dashPath(trail, 0.022, 0.016).forEach(function (dash) {
        marks.push(markLine(dash, "rust", 2.4, 0.9))
      })
      marks.push(markLine(squiggle([0.645, 0.055], [0.643, 0.128], rng, 0.003, 0.6, 8), "ink", 2.6))
      marks.push(
        markLine(
          [
            [0.645, 0.058],
            [0.705, 0.078],
            [0.645, 0.098],
            [0.645, 0.058],
          ],
          "rust",
          2.2,
        ),
      )
      marks.push(markLabel("worth the climb", 0.235, 0.115, -7, 0.034, "paper"))
      marks.push(markLine(wavePts(0.155, 0.1, 0.375, 0.006, 3), "rust", 1.6, 0.75))
      ;[
        [0.15, 0.2],
        [0.205, 0.165],
        [0.255, 0.21],
      ].forEach(function (b) {
        marks.push(markLine(birdPts(b[0], b[1], 0.022, rng), "paper", 2.2, 0.85))
      })
      marks.push(markLine(wavePts(0.615, 0.34, 0.66, 0.006, 3.5), "paper", 1.5, 0.6))
      var bx = 0.185
      var by = 0.7
      marks.push(
        markLine(
          [
            [bx - 0.05, by],
            [bx + 0.05, by],
            [bx + 0.032, by + 0.034],
            [bx - 0.032, by + 0.034],
            [bx - 0.05, by],
          ],
          "paper",
          2.3,
        ),
      )
      marks.push(
        markLine(
          [
            [bx + 0.002, by - 0.002],
            [bx + 0.002, by - 0.052],
            [bx + 0.038, by - 0.012],
            [bx + 0.002, by - 0.002],
          ],
          "paper",
          2.3,
        ),
      )
      marks.push(
        markLine(
          ellipsePts(bx, by + 0.045, 0.062, 0.014, rng, {
            start: Math.PI * 1.15,
            end: Math.PI * 1.85,
            wobble: 0.06,
          }),
          "paper",
          1.6,
          0.7,
        ),
      )
      marks.push(
        markLine(
          ellipsePts(bx, by + 0.062, 0.085, 0.018, rng, {
            start: Math.PI * 1.2,
            end: Math.PI * 1.8,
            wobble: 0.06,
          }),
          "paper",
          1.5,
          0.55,
        ),
      )
      return marks
    },

    mekong: function (rng) {
      var marks = []
      var sx = 0.79
      var sy = 0.362
      marks.push(
        markLine(
          ellipsePts(sx, sy, 0.028, 0.028, rng, { end: Math.PI * 2 + 0.3, wobble: 0.04 }),
          "rust",
          2.4,
        ),
      )
      for (var i = 0; i < 7; i++) {
        var a = -Math.PI * 0.95 + (i / 6) * Math.PI * 0.9
        var r0 = 0.042
        var r1 = 0.062 + rng() * 0.012
        marks.push(
          markLine(
            squiggle(
              [sx + Math.cos(a) * r0, sy + Math.sin(a) * r0 * 0.9],
              [sx + Math.cos(a) * r1, sy + Math.sin(a) * r1 * 0.9],
              rng,
              0.002,
              0.6,
              6,
            ),
            "rust",
            2,
          ),
        )
      }
      marks.push(markLabel("there it is", 0.575, 0.255, -6, 0.032, "paper"))
      var lx = 0.285
      var ly = 0.7
      marks.push(
        markLine(ellipsePts(lx, ly, 0.022, 0.027, rng, { end: Math.PI * 2 + 0.25, wobble: 0.05 }), "paper", 2.2),
      )
      marks.push(markLine([[lx - 0.016, ly - 0.03], [lx + 0.016, ly - 0.03]], "paper", 2, 0.9))
      marks.push(markLine([[lx - 0.014, ly + 0.03], [lx + 0.014, ly + 0.03]], "paper", 2, 0.9))
      dashPath(
        [
          [lx, ly - 0.035],
          [lx + 0.02, ly - 0.14],
          [lx + 0.045, ly - 0.25],
          [lx + 0.05, ly - 0.36],
        ],
        0.02,
        0.02,
      ).forEach(function (dash) {
        marks.push(markLine(dash, "paper", 1.5, 0.6))
      })
      marks.push(markLabel("send one up", 0.135, 0.6, -5, 0.032, "paper"))
      marks.push(
        markLine(
          ellipsePts(lx, ly + 0.04, 0.05, 0.011, rng, {
            start: Math.PI * 1.1,
            end: Math.PI * 1.9,
            wobble: 0.05,
          }),
          "paper",
          1.5,
          0.6,
        ),
      )
      marks.push(
        markLine(
          ellipsePts(lx, ly + 0.056, 0.072, 0.015, rng, {
            start: Math.PI * 1.15,
            end: Math.PI * 1.85,
            wobble: 0.05,
          }),
          "paper",
          1.4,
          0.45,
        ),
      )
      ;[
        [0.07, 0.72],
        [0.12, 0.78],
        [0.165, 0.7],
        [0.21, 0.83],
        [0.085, 0.86],
      ].forEach(function (spot, index) {
        if (index % 2 === 0) marks.push(markSparkle(spot[0], spot[1], 0.009, "rust"))
        else marks.push(markDot(spot[0], spot[1], 0.005, "paper"))
      })
      marks.push(markLine(wavePts(0.56, 0.38, 0.58, 0.005, 3.2), "paper", 1.4, 0.55))
      return marks
    },

    "vang-vieng": function (rng) {
      var marks = []
      var kx = 0.285
      var ky = 0.195
      var ks = 0.038
      marks.push(
        markLine(
          [
            [kx, ky - ks],
            [kx + ks * 0.78, ky],
            [kx, ky + ks],
            [kx - ks * 0.78, ky],
            [kx, ky - ks],
          ],
          "rust",
          2.6,
        ),
      )
      marks.push(markLine([[kx, ky - ks * 0.75], [kx, ky + ks * 0.75]], "rust", 1.6, 0.75))
      marks.push(markLine([[kx - ks * 0.55, ky], [kx + ks * 0.55, ky]], "rust", 1.6, 0.75))
      marks.push(markLine(squiggle([kx, ky + ks], [kx - 0.045, ky + 0.11], rng, 0.012, 2.4, 18), "rust", 1.9, 0.9))
      marks.push(markLine([[kx - 0.033, ky + 0.075], [kx - 0.048, ky + 0.062]], "rust", 1.7, 0.9))
      marks.push(markLine([[kx - 0.041, ky + 0.09], [kx - 0.056, ky + 0.077]], "rust", 1.7, 0.9))
      var fx = 0.335
      var fy = 0.645
      marks.push(
        markLine(
          qbez([kx - 0.005, ky + ks], [fx + 0.02, fy - 0.14], [fx + 0.004, fy - 0.062], 26, rng, 0.003),
          "ink",
          1.6,
          0.85,
        ),
      )
      marks.push(
        markLine(ellipsePts(fx, fy - 0.048, 0.011, 0.011, rng, { end: Math.PI * 2 + 0.2, wobble: 0.05 }), "ink", 2.2),
      )
      marks.push(markLine(squiggle([fx, fy - 0.036], [fx, fy - 0.006], rng, 0.003, 0.5, 8), "ink", 2.2))
      marks.push(markLine(squiggle([fx, fy - 0.03], [fx + 0.014, fy - 0.052], rng, 0.003, 0.5, 6), "ink", 2))
      marks.push(markLine(squiggle([fx, fy - 0.006], [fx - 0.014, fy + 0.03], rng, 0.003, 0.5, 6), "ink", 2.2))
      marks.push(markLine(squiggle([fx, fy - 0.006], [fx + 0.014, fy + 0.03], rng, 0.003, 0.5, 6), "ink", 2.2))
      ;[
        [0.415, 0.195],
        [0.462, 0.158],
        [0.505, 0.2],
      ].forEach(function (b) {
        marks.push(markLine(birdPts(b[0], b[1], 0.02, rng), "ink", 2.1, 0.85))
      })
      ;[
        [0.075, 0.665],
        [0.3, 0.745],
        [0.895, 0.65],
      ].forEach(function (clump) {
        for (var i = 0; i < 3; i++) {
          var baseX = clump[0] + i * 0.008
          var lean = (i - 1) * 0.014
          marks.push(
            markLine(
              squiggle([baseX, clump[1]], [baseX + lean, clump[1] - 0.035 - rng() * 0.012], rng, 0.004, 0.8, 6),
              "ink",
              1.7,
              0.85,
            ),
          )
        }
      })
      marks.push(
        markLine(
          ellipsePts(0.62, 0.8, 0.05, 0.011, rng, {
            start: Math.PI * 1.1,
            end: Math.PI * 1.9,
            wobble: 0.05,
          }),
          "ink",
          1.5,
          0.6,
        ),
      )
      marks.push(
        markLine(
          ellipsePts(0.23, 0.86, 0.045, 0.01, rng, {
            start: Math.PI * 1.15,
            end: Math.PI * 1.85,
            wobble: 0.05,
          }),
          "ink",
          1.5,
          0.55,
        ),
      )
      marks.push(markLabel("hold the string", 0.145, 0.575, -6, 0.032, "ink"))
      return marks
    },
  }

  // ---------- scene construction and drawing ----------

  function buildScene(pieceId, seed) {
    var recipe = RECIPES[pieceId]
    var rng = makeRng(seed)
    var marks = recipe ? recipe(rng) : []
    var cursor = 60
    marks.forEach(function (mark) {
      var length = 0
      if (mark.kind === "line") {
        for (var i = 1; i < mark.pts.length; i++) {
          length += Math.hypot(mark.pts[i][0] - mark.pts[i - 1][0], mark.pts[i][1] - mark.pts[i - 1][1])
        }
      } else if (mark.kind === "label") {
        length = 0.16
      } else {
        length = 0.03
      }
      mark.length = length
      mark.start = cursor
      mark.dur = Math.max(170, Math.min(1400, length * 3000))
      cursor += mark.dur + 60
    })
    return { marks: marks, total: cursor, started: false, finished: false }
  }

  function slicePath(pts, target) {
    var out = [pts[0]]
    var travelled = 0
    for (var i = 1; i < pts.length; i++) {
      var a = pts[i - 1]
      var b = pts[i]
      var seg = Math.hypot(b[0] - a[0], b[1] - a[1])
      if (travelled + seg <= target) {
        out.push(b)
        travelled += seg
      } else {
        var t = seg === 0 ? 0 : (target - travelled) / seg
        out.push([a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t])
        return out
      }
    }
    return out
  }

  function drawMark(ctx, mark, progress, width, height, dim, scale, colours) {
    var colour = colours[mark.colour] || colours.rust
    ctx.strokeStyle = colour
    ctx.fillStyle = colour

    if (mark.kind === "line") {
      var eased = progress * progress * (3 - 2 * progress)
      var partial = slicePath(mark.pts, mark.length * eased)
      if (partial.length < 2) return
      ctx.globalAlpha = mark.alpha == null ? 0.9 : mark.alpha
      ctx.lineWidth = Math.max(0.6, mark.width * scale)
      ctx.beginPath()
      ctx.moveTo(partial[0][0] * width, partial[0][1] * height)
      for (var i = 1; i < partial.length; i++) {
        ctx.lineTo(partial[i][0] * width, partial[i][1] * height)
      }
      ctx.stroke()
      return
    }

    if (mark.kind === "dot") {
      ctx.globalAlpha = progress
      ctx.beginPath()
      ctx.arc(mark.x * width, mark.y * height, mark.r * dim * (0.7 + 0.3 * progress), 0, Math.PI * 2)
      ctx.fill()
      return
    }

    if (mark.kind === "sparkle") {
      ctx.globalAlpha = progress * 0.9
      ctx.lineWidth = Math.max(0.6, 1.6 * scale)
      var reach = mark.r * dim * progress
      var cx = mark.x * width
      var cy = mark.y * height
      ctx.beginPath()
      ctx.moveTo(cx - reach, cy)
      ctx.lineTo(cx + reach, cy)
      ctx.moveTo(cx, cy - reach)
      ctx.lineTo(cx, cy + reach)
      ctx.moveTo(cx - reach * 0.55, cy - reach * 0.55)
      ctx.lineTo(cx + reach * 0.55, cy + reach * 0.55)
      ctx.moveTo(cx + reach * 0.55, cy - reach * 0.55)
      ctx.lineTo(cx - reach * 0.55, cy + reach * 0.55)
      ctx.stroke()
      return
    }

    if (mark.kind === "label") {
      ctx.globalAlpha = progress * 0.92
      ctx.save()
      ctx.translate(mark.x * width, mark.y * height)
      ctx.rotate(((mark.angle || 0) * Math.PI) / 180)
      ctx.font = "italic " + Math.round(mark.size * dim) + "px " + HAND_FONT
      ctx.textAlign = "center"
      ctx.textBaseline = "middle"
      ctx.fillText(mark.text, 0, 0)
      ctx.restore()
    }
  }

  function drawScene(ctx, scene, time, width, height, scale, colours, clear) {
    if (clear !== false) ctx.clearRect(0, 0, width, height)
    var dim = Math.min(width, height)
    ctx.lineCap = "round"
    ctx.lineJoin = "round"
    scene.marks.forEach(function (mark) {
      var progress = time == null ? 1 : clamp01((time - mark.start) / mark.dur)
      if (progress <= 0) return
      drawMark(ctx, mark, progress, width, height, dim, scale, colours)
    })
    ctx.globalAlpha = 1
  }

  // ---------- per-piece state ----------

  pieces.forEach(function (piece) {
    var stage = piece.querySelector(".ds-stage")
    var ink = piece.querySelector(".ds-ink")
    var pad = piece.querySelector(".ds-pad")
    var photo = piece.querySelector(".ds-photo")
    if (!(stage instanceof HTMLElement)) return
    if (!(ink instanceof HTMLCanvasElement) || !(pad instanceof HTMLCanvasElement)) return
    if (!(photo instanceof HTMLImageElement)) return
    var state = {
      id: piece.getAttribute("data-ds-piece"),
      piece: piece,
      stage: stage,
      ink: ink,
      pad: pad,
      photo: photo,
      seed: Number(piece.getAttribute("data-ds-seed")) || 7,
      colours: palette(),
      scene: null,
      raf: 0,
      w: 0,
      h: 0,
      dpr: 1,
      strokes: [],
      drawing: false,
      drawMode: false,
      clearButton: piece.querySelector("[data-ds-clear]"),
      saveButton: piece.querySelector("[data-ds-save]"),
      drawButton: piece.querySelector("[data-ds-draw]"),
    }
    state.scene = buildScene(state.id, state.seed)
    states.push(state)
    byPiece.set(piece, state)
    byStage.set(stage, state)

    pad.addEventListener("pointerdown", function (event) {
      if (!state.drawMode) return
      event.preventDefault()
      state.drawing = true
      var point = padPoint(state, event)
      var stroke = { colour: "rust", width: 0.0045, pts: [point] }
      state.strokes.push(stroke)
      pad.setPointerCapture(event.pointerId)
      redrawPad(state)
      refreshPad(state)
    })
    pad.addEventListener("pointermove", function (event) {
      if (!state.drawing) return
      event.preventDefault()
      var stroke = state.strokes[state.strokes.length - 1]
      var events = typeof event.getCoalescedEvents === "function" ? event.getCoalescedEvents() : [event]
      if (events.length === 0) events = [event]
      var ctx = pad.getContext("2d")
      ctx.setTransform(state.dpr, 0, 0, state.dpr, 0, 0)
      ctx.strokeStyle = state.colours[stroke.colour] || state.colours.rust
      ctx.lineWidth = Math.max(1, stroke.width * Math.min(state.w, state.h))
      ctx.lineCap = "round"
      ctx.lineJoin = "round"
      ctx.globalAlpha = 0.9
      events.forEach(function (sample) {
        var point = padPoint(state, sample)
        var last = stroke.pts[stroke.pts.length - 1]
        ctx.beginPath()
        ctx.moveTo(last[0] * state.w, last[1] * state.h)
        ctx.lineTo(point[0] * state.w, point[1] * state.h)
        ctx.stroke()
        stroke.pts.push(point)
      })
      ctx.globalAlpha = 1
    })
    var endStroke = function () {
      if (!state.drawing) return
      state.drawing = false
      refreshPad(state)
    }
    pad.addEventListener("pointerup", endStroke)
    pad.addEventListener("pointercancel", endStroke)
  })

  function padPoint(state, event) {
    var rect = state.pad.getBoundingClientRect()
    return [
      clamp01((event.clientX - rect.left) / Math.max(1, rect.width)),
      clamp01((event.clientY - rect.top) / Math.max(1, rect.height)),
    ]
  }

  // ---------- sizing ----------

  function resizeState(state) {
    var rect = state.stage.getBoundingClientRect()
    var dpr = Math.min(2, window.devicePixelRatio || 1)
    var w = Math.max(1, Math.round(rect.width))
    var h = Math.max(1, Math.round(rect.height))
    if (w === state.w && h === state.h && dpr === state.dpr) return
    state.w = w
    state.h = h
    state.dpr = dpr
    ;[state.ink, state.pad].forEach(function (canvas) {
      canvas.width = Math.round(w * dpr)
      canvas.height = Math.round(h * dpr)
      canvas.style.width = w + "px"
      canvas.style.height = h + "px"
    })
    if (state.scene.started) drawCurrent(state, null)
    redrawPad(state)
  }

  function drawCurrent(state, time) {
    var ctx = state.ink.getContext("2d")
    ctx.setTransform(state.dpr, 0, 0, state.dpr, 0, 0)
    drawScene(ctx, state.scene, time, state.w, state.h, 1, state.colours)
    if (time == null) state.scene.finished = true
  }

  function redrawPad(state) {
    var ctx = state.pad.getContext("2d")
    ctx.setTransform(state.dpr, 0, 0, state.dpr, 0, 0)
    ctx.clearRect(0, 0, state.w, state.h)
    var dim = Math.min(state.w, state.h)
    ctx.lineCap = "round"
    ctx.lineJoin = "round"
    state.strokes.forEach(function (stroke) {
      if (stroke.pts.length < 2) return
      ctx.strokeStyle = state.colours[stroke.colour] || state.colours.rust
      ctx.lineWidth = Math.max(1, stroke.width * dim)
      ctx.globalAlpha = 0.9
      ctx.beginPath()
      ctx.moveTo(stroke.pts[0][0] * state.w, stroke.pts[0][1] * state.h)
      for (var i = 1; i < stroke.pts.length; i++) {
        ctx.lineTo(stroke.pts[i][0] * state.w, stroke.pts[i][1] * state.h)
      }
      ctx.stroke()
    })
    ctx.globalAlpha = 1
  }

  // ---------- animation ----------

  function animate(state) {
    state.scene.started = true
    if (state.raf) cancelAnimationFrame(state.raf)
    if (motionQuery.matches) {
      drawCurrent(state, null)
      return
    }
    var started = performance.now()
    var step = function (now) {
      var time = now - started
      drawCurrent(state, time)
      if (time < state.scene.total + 140) {
        state.raf = requestAnimationFrame(step)
      } else {
        state.raf = 0
        state.scene.finished = true
      }
    }
    state.raf = requestAnimationFrame(step)
  }

  function redoodle(state) {
    var seed = ((Math.random() * 4294967295) >>> 0) || 7
    state.seed = seed
    state.piece.setAttribute("data-ds-seed", String(seed))
    state.scene = buildScene(state.id, seed)
    if (state.raf) cancelAnimationFrame(state.raf)
    animate(state)
  }

  // ---------- drawing mode and saving ----------

  function setDrawMode(state, on) {
    state.drawMode = on
    state.piece.classList.toggle("ds-drawing", on)
    if (state.drawButton instanceof HTMLButtonElement) {
      state.drawButton.setAttribute("aria-pressed", on ? "true" : "false")
      state.drawButton.textContent = on ? "done drawing" : "draw on it"
    }
    if (on && state.pad.hidden) state.pad.hidden = false
    refreshPad(state)
  }

  function refreshPad(state) {
    var hasStrokes = state.strokes.length > 0
    if (!state.drawMode && !hasStrokes) state.pad.hidden = true
    state.piece.classList.toggle("ds-has-marks", hasStrokes)
    if (state.clearButton instanceof HTMLButtonElement) {
      state.clearButton.hidden = !state.drawMode || !hasStrokes
    }
    if (state.saveButton instanceof HTMLButtonElement) {
      state.saveButton.hidden = !state.drawMode
    }
  }

  function savePiece(state) {
    var naturalW = state.photo.naturalWidth || Math.round(state.w * 2)
    var naturalH = state.photo.naturalHeight || Math.round(state.h * 2)
    var canvas = document.createElement("canvas")
    canvas.width = naturalW
    canvas.height = naturalH
    var ctx = canvas.getContext("2d")
    if (!ctx) return
    ctx.drawImage(state.photo, 0, 0, naturalW, naturalH)
    var scale = naturalH / Math.max(1, state.h)
    drawScene(ctx, state.scene, null, naturalW, naturalH, scale, state.colours, false)
    var dim = Math.min(naturalW, naturalH)
    state.strokes.forEach(function (stroke) {
      ctx.strokeStyle = state.colours[stroke.colour] || state.colours.rust
      ctx.lineWidth = Math.max(1, stroke.width * dim)
      ctx.lineCap = "round"
      ctx.lineJoin = "round"
      ctx.globalAlpha = 0.9
      ctx.beginPath()
      ctx.moveTo(stroke.pts[0][0] * naturalW, stroke.pts[0][1] * naturalH)
      for (var i = 1; i < stroke.pts.length; i++) {
        ctx.lineTo(stroke.pts[i][0] * naturalW, stroke.pts[i][1] * naturalH)
      }
      ctx.stroke()
    })
    ctx.globalAlpha = 1
    canvas.toBlob(
      function (blob) {
        if (!blob) return
        var url = URL.createObjectURL(blob)
        var link = document.createElement("a")
        link.href = url
        link.download = "deepseek-thoughts-" + state.id + ".jpg"
        document.body.appendChild(link)
        link.click()
        link.remove()
        window.setTimeout(function () {
          URL.revokeObjectURL(url)
        }, 4000)
      },
      "image/jpeg",
      0.92,
    )
  }

  // ---------- wiring ----------

  function onClick(event) {
    var target = event.target
    if (!(target instanceof Element)) return
    var button = target.closest("button")
    if (!button) return
    if (button.hasAttribute("data-ds-redoodle-all")) {
      states.forEach(function (state) {
        redoodle(state)
      })
      return
    }
    if (button.hasAttribute("data-ds-toggle-doodles")) {
      var hidden = root.classList.toggle("ds-hide-ink")
      button.setAttribute("aria-pressed", hidden ? "true" : "false")
      button.textContent = hidden ? "show the doodles" : "hide the doodles"
      return
    }
    var piece = button.closest("[data-ds-piece]")
    if (!(piece instanceof HTMLElement)) return
    var state = null
    for (var i = 0; i < states.length; i++) {
      if (states[i].piece === piece) state = states[i]
    }
    if (!state) return
    if (button.hasAttribute("data-ds-redoodle")) {
      redoodle(state)
    } else if (button.hasAttribute("data-ds-draw")) {
      var goingOn = !state.drawMode
      states.forEach(function (other) {
        if (other !== state) setDrawMode(other, false)
      })
      setDrawMode(state, goingOn)
    } else if (button.hasAttribute("data-ds-clear")) {
      state.strokes = []
      redrawPad(state)
      refreshPad(state)
    } else if (button.hasAttribute("data-ds-save")) {
      savePiece(state)
    }
  }
  root.addEventListener("click", onClick)

  var observer = new IntersectionObserver(
    function (entries) {
      entries.forEach(function (entry) {
        var state = byPiece.get(entry.target)
        if (!state || state.scene.started) return
        if (entry.isIntersecting) {
          animate(state)
          observer.unobserve(entry.target)
        }
      })
    },
    { threshold: 0.18 },
  )

  var sizeObserver = new ResizeObserver(function (entries) {
    entries.forEach(function (entry) {
      var state = byStage.get(entry.target)
      if (state) resizeState(state)
    })
  })

  var themeObserver = new MutationObserver(function () {
    states.forEach(function (state) {
      state.colours = palette()
      if (state.scene.finished) drawCurrent(state, null)
      redrawPad(state)
    })
  })

  var onWindowResize = function () {
    states.forEach(resizeState)
  }

  states.forEach(function (state) {
    resizeState(state)
    refreshPad(state)
    if (motionQuery.matches) {
      animate(state)
    } else {
      observer.observe(state.piece)
    }
    sizeObserver.observe(state.stage)
  })

  if (root.querySelector(".ds-pad") && root.querySelector(".ds-photo")) {
    // canvas does not use the webfont until it is loaded; ask for it, then
    // repaint any finished scene so the handwritten labels sharpen up
    var fontLoad =
      document.fonts && document.fonts.load
        ? document.fonts.load('italic 24px "Playwrite GB J Guides"').then(function () {
            return document.fonts.ready
          }).catch(function () {
            return null
          })
        : Promise.resolve()
    Promise.race([
      fontLoad,
      new Promise(function (resolve) {
        window.setTimeout(resolve, 1500)
      }),
    ]).then(function () {
      states.forEach(function (state) {
        if (state.scene.started && state.scene.finished) drawCurrent(state, null)
      })
    })
  }

  themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ["saved-theme"] })
  window.addEventListener("resize", onWindowResize, { passive: true })

  var motionListener = function () {
    if (!motionQuery.matches) return
    states.forEach(function (state) {
      if (state.raf) cancelAnimationFrame(state.raf)
      state.raf = 0
      state.scene.started = true
      drawCurrent(state, null)
    })
  }
  if (typeof motionQuery.addEventListener === "function") motionQuery.addEventListener("change", motionListener)

  window.addCleanup &&
    window.addCleanup(function () {
      states.forEach(function (state) {
        if (state.raf) cancelAnimationFrame(state.raf)
      })
      observer.disconnect()
      sizeObserver.disconnect()
      themeObserver.disconnect()
      root.removeEventListener("click", onClick)
      window.removeEventListener("resize", onWindowResize)
      if (typeof motionQuery.removeEventListener === "function")
        motionQuery.removeEventListener("change", motionListener)
      root.removeAttribute("data-ds-ready")
    })
}

document.addEventListener("nav", setupDeepSeekThoughts)
`
