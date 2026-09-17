/**
 * The doodle engine for /model-sketchbooks/deepseek.
 *
 * Everything a visitor sees on top of the photographs is drawn here, in the
 * browser, with the Canvas 2D API: hand-trembled strokes, hats, bubbles,
 * boats, krakens, and little handwritten labels. Marks are generated from a
 * seed with a small mulberry32 PRNG, so every picture has a stable default
 * doodle and "doodle again" is just a new seed.
 *
 * Each piece can also be opened in a focus dialog with a larger stage; both
 * the inline and focus surfaces share one scene, one stroke list, and one
 * animation clock through the small "view" abstraction below.
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
  var focusDialog = null
  var focusView = null
  var focusState = null
  var lastFocusTrigger = null

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

  function rotatePts(pts, cx, cy, degrees) {
    var a = (degrees * Math.PI) / 180
    var cos = Math.cos(a)
    var sin = Math.sin(a)
    return pts.map(function (p) {
      var dx = p[0] - cx
      var dy = p[1] - cy
      return [cx + dx * cos - dy * sin, cy + dx * sin + dy * cos]
    })
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
  function markFill(pts, colour, alpha) {
    return { kind: "fill", pts: pts, colour: colour || "paper", alpha: alpha == null ? 0.85 : alpha }
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
  function withMarks() {
    var list = []
    for (var i = 0; i < arguments.length; i++) {
      var value = arguments[i]
      if (!value) continue
      if (Array.isArray(value)) list = list.concat(value)
      else list.push(value)
    }
    return list
  }

  // ---------- little doodled objects ----------

  function topHat(rng, cx, cy, s, angle, colour) {
    var paint = colour || "paper"
    var crown = rotatePts(
      [
        [cx - s * 0.55, cy - s * 0.06],
        [cx - s * 0.5, cy - s * 1.05],
        [cx + s * 0.5, cy - s * 1.05],
        [cx + s * 0.55, cy - s * 0.06],
      ],
      cx,
      cy,
      angle,
    )
    var brim = rotatePts(
      ellipsePts(cx, cy, s * 0.95, s * 0.2, rng, { end: Math.PI * 2 + 0.4, wobble: 0.03 }),
      cx,
      cy,
      angle,
    )
    var band = rotatePts([[cx - s * 0.53, cy - s * 0.34], [cx + s * 0.53, cy - s * 0.34]], cx, cy, angle)
    return [
      markLine(crown, paint, 2.6, 0.95),
      markLine(brim, paint, 2.6, 0.95),
      markLine(band, "rust", 2.2, 0.9),
    ]
  }

  function speechBubble(rng, cx, cy, rx, ry, tailX, tailY, colour) {
    var paint = colour || "rust"
    var bubble = ellipsePts(cx, cy, rx, ry, rng, { end: Math.PI * 2 + 0.2, wobble: 0.02 })
    var tail = [
      [cx + rx * 0.18, cy + ry * 0.92],
      [tailX, tailY],
      [cx - rx * 0.42, cy + ry * 0.82],
    ]
    return [
      markFill(bubble, "paper", 0.86),
      markLine(bubble, paint, 2.2, 0.95),
      markFill(tail, "paper", 0.86),
      markLine(tail, paint, 2.2, 0.95),
    ]
  }

  function yarnBall(rng, cx, cy, r, colour) {
    var paint = colour || "rust"
    var marks = [markLine(ellipsePts(cx, cy, r, r, rng, { end: Math.PI * 2 + 0.35, wobble: 0.04 }), paint, 2.2)]
    for (var i = 0; i < 3; i++) {
      var loop = ellipsePts(cx, cy, r * (0.92 - i * 0.06), r * (0.3 + i * 0.22), rng, {
        end: Math.PI * 2 + 0.15,
        wobble: 0.05,
      })
      marks.push(markLine(rotatePts(loop, cx, cy, 28 + i * 44), paint, 1.8, 0.9))
    }
    marks.push(
      markLine(
        squiggle([cx + r * 0.85, cy + r * 0.45], [cx + r * 3.3, cy + r * 1.05], rng, 0.02, 1.7, 20),
        paint,
        1.8,
        0.9,
      ),
    )
    return marks
  }

  function fishBone(rng, cx, cy, s, angle, colour) {
    var paint = colour || "ink"
    var spine = [
      [cx - s * 0.48, cy],
      [cx + s * 0.5, cy],
    ]
    var marks = [markLine(rotatePts(spine, cx, cy, angle), paint, 2, 0.9)]
    for (var i = 0; i < 5; i++) {
      var t = 0.12 + i * 0.17
      var x = cx - s * 0.44 + s * t
      marks.push(
        markLine(
          rotatePts(
            [
              [x, cy - s * 0.16],
              [x, cy + s * 0.16],
            ],
            cx,
            cy,
            angle,
          ),
          paint,
          1.6,
          0.85,
        ),
      )
    }
    marks.push(
      markLine(
        rotatePts(ellipsePts(cx - s * 0.48, cy, s * 0.15, s * 0.15, rng, { end: Math.PI * 2 + 0.3, wobble: 0.04 }), cx, cy, angle),
        paint,
        2,
        0.9,
      ),
    )
    marks.push(
      markLine(
        rotatePts(
          [
            [cx + s * 0.5, cy],
            [cx + s * 0.76, cy - s * 0.22],
          ],
          cx,
          cy,
          angle,
        ),
        paint,
        2,
        0.9,
      ),
    )
    marks.push(
      markLine(
        rotatePts(
          [
            [cx + s * 0.5, cy],
            [cx + s * 0.76, cy + s * 0.22],
          ],
          cx,
          cy,
          angle,
        ),
        paint,
        2,
        0.9,
      ),
    )
    var eye = rotatePts([[cx - s * 0.52, cy - s * 0.05]], cx, cy, angle)[0]
    marks.push(markDot(eye[0], eye[1], s * 0.028, paint))
    return marks
  }

  function rocket(rng, cx, cy, s, angle, colour) {
    var paint = colour || "paper"
    var marks = []
    var left = qbez([cx, cy - s * 0.95], [cx - s * 0.46, cy - s * 0.3], [cx - s * 0.34, cy + s * 0.62], 10, rng, s * 0.03)
    var right = qbez([cx + s * 0.34, cy + s * 0.62], [cx + s * 0.46, cy - s * 0.3], [cx, cy - s * 0.95], 10, rng, s * 0.03)
    marks.push(markLine(rotatePts(left.concat(right.slice(1)), cx, cy, angle), paint, 2.4, 0.95))
    marks.push(
      markLine(
        rotatePts(
          qbez([cx - s * 0.33, cy + s * 0.6], [cx, cy + s * 0.8], [cx + s * 0.33, cy + s * 0.6], 8, rng, s * 0.02),
          cx,
          cy,
          angle,
        ),
        paint,
        2.4,
        0.95,
      ),
    )
    marks.push(
      markLine(
        rotatePts(
          [
            [cx - s * 0.3, cy + s * 0.24],
            [cx - s * 0.66, cy + s * 0.74],
            [cx - s * 0.28, cy + s * 0.6],
          ],
          cx,
          cy,
          angle,
        ),
        paint,
        2.2,
        0.9,
      ),
    )
    marks.push(
      markLine(
        rotatePts(
          [
            [cx + s * 0.3, cy + s * 0.24],
            [cx + s * 0.66, cy + s * 0.74],
            [cx + s * 0.28, cy + s * 0.6],
          ],
          cx,
          cy,
          angle,
        ),
        paint,
        2.2,
        0.9,
      ),
    )
    marks.push(
      markLine(
        rotatePts(ellipsePts(cx, cy - s * 0.16, s * 0.16, s * 0.16, rng, { end: Math.PI * 2 + 0.25, wobble: 0.04 }), cx, cy, angle),
        "sky",
        2,
        0.95,
      ),
    )
    for (var i = 0; i < 3; i++) {
      var spread = (i - 1) * s * 0.22
      marks.push(
        markLine(
          rotatePts(
            squiggle([cx + spread, cy + s * 0.78], [cx + spread * 1.5, cy + s * 1.24], rng, 0.006, 1.2, 8),
            cx,
            cy,
            angle,
          ),
          "rust",
          2.2,
          0.9,
        ),
      )
    }
    return marks
  }

  function paperPlane(rng, cx, cy, s, angle, colour) {
    var paint = colour || "rust"
    var outline = [
      [cx - s, cy + s * 0.55],
      [cx + s, cy - s * 0.3],
      [cx - s * 0.3, cy - s * 0.05],
      [cx - s, cy + s * 0.55],
    ]
    var fold = [
      [cx - s * 0.3, cy - s * 0.05],
      [cx + s * 0.08, cy + s * 0.3],
    ]
    return [
      markFill(rotatePts(outline, cx, cy, angle), "paper", 0.7),
      markLine(rotatePts(outline, cx, cy, angle), paint, 2.2, 0.95),
      markLine(rotatePts(fold, cx, cy, angle), paint, 1.8, 0.9),
    ]
  }

  function shootingStar(rng, from, to, colour) {
    var paint = colour || "paper"
    var marks = []
    dashPath([from, to], 0.024, 0.02).forEach(function (dash) {
      marks.push(markLine(dash, paint, 1.8, 0.65))
    })
    marks.push(markSparkle(to[0], to[1], 0.014, paint))
    return marks
  }

  function tent(rng, cx, baseY, s, colour) {
    var paint = colour || "paper"
    var outline = [
      [cx - s, baseY],
      [cx, baseY - s * 1.05],
      [cx + s, baseY],
      [cx - s, baseY],
    ]
    var door = [
      [cx - s * 0.04, baseY],
      [cx + s * 0.2, baseY - s * 0.5],
    ]
    var guy = squiggle([cx, baseY - s * 1.05], [cx + s * 1.6, baseY], rng, 0.006, 0.8, 10)
    return [
      markLine(outline, paint, 2.2, 0.95),
      markLine(door, paint, 1.8, 0.85),
      markLine(guy, paint, 1.4, 0.6),
    ]
  }

  function campfire(rng, cx, cy, s, colour) {
    var paint = colour || "paper"
    var marks = []
    marks.push(markLine(squiggle([cx - s, cy + s * 0.35], [cx + s, cy + s * 0.1], rng, 0.006, 0.8, 8), paint, 2.2, 0.95))
    marks.push(markLine(squiggle([cx - s * 0.85, cy], [cx + s * 0.9, cy + s * 0.4], rng, 0.006, 0.8, 8), paint, 2.2, 0.95))
    marks.push(markLine(squiggle([cx, cy + s * 0.12], [cx - s * 0.1, cy - s * 0.9], rng, 0.012, 1.4, 10), "rust", 2.2, 0.9))
    marks.push(markLine(squiggle([cx + s * 0.18, cy + s * 0.05], [cx + s * 0.34, cy - s * 0.7], rng, 0.012, 1.4, 10), "rust", 2, 0.85))
    marks.push(markDot(cx - s * 0.35, cy - s * 0.85, s * 0.09, "rust"))
    marks.push(markDot(cx + s * 0.55, cy - s * 1.05, s * 0.07, "rust"))
    return marks
  }

  function smokeCurl(rng, cx, cy, s, colour) {
    var paint = colour || "paper"
    var pts = []
    var steps = 24
    for (var i = 0; i <= steps; i++) {
      var t = i / steps
      pts.push([cx + Math.sin(t * Math.PI * 3.2) * s * 0.4 * (1 - t * 0.5), cy - t * s * 1.6])
    }
    var marks = [markLine(pts, paint, 1.8, 0.8)]
    marks.push(markLine(ellipsePts(cx + s * 0.42, cy - s * 1.62, s * 0.22, s * 0.16, rng, { end: Math.PI * 2, wobble: 0.06 }), paint, 1.5, 0.6))
    return marks
  }

  function kraken(rng, cx, cy, s, colour) {
    var paint = colour || "rust"
    var marks = []
    marks.push(markLine(ellipsePts(cx, cy, s * 0.44, s * 0.36, rng, { end: Math.PI * 2 + 0.25, wobble: 0.04 }), paint, 2.4, 0.95))
    marks.push(markDot(cx - s * 0.16, cy - s * 0.06, s * 0.06, paint))
    marks.push(markDot(cx + s * 0.16, cy - s * 0.06, s * 0.06, paint))
    marks.push(markLine(spiralPts(cx - s * 0.66, cy + s * 0.5, s * 0.52, s * 0.1, 1.5, rng), paint, 2.2, 0.9))
    marks.push(markLine(spiralPts(cx + s * 0.05, cy + s * 0.72, s * 0.55, s * 0.1, 1.5, rng), paint, 2.2, 0.9))
    marks.push(markLine(spiralPts(cx + s * 0.72, cy + s * 0.5, s * 0.5, s * 0.1, 1.5, rng), paint, 2.2, 0.9))
    marks.push(
      markLine(
        ellipsePts(cx, cy + s * 0.86, s * 0.85, s * 0.12, rng, { start: Math.PI * 1.08, end: Math.PI * 1.92, wobble: 0.05 }),
        paint,
        1.6,
        0.6,
      ),
    )
    return marks
  }

  function ship(rng, cx, cy, s, colour) {
    var paint = colour || "navy"
    var marks = []
    marks.push(
      markLine(
        ellipsePts(cx, cy, s, s * 0.34, rng, { start: Math.PI * 0.06, end: Math.PI * 0.94, wobble: 0.02 }),
        paint,
        2.2,
        0.95,
      ),
    )
    marks.push(markLine([[cx - s * 0.95, cy], [cx + s * 0.95, cy]], paint, 1.6, 0.8))
    marks.push(markLine([[cx, cy], [cx, cy - s * 1.55]], paint, 2, 0.9))
    marks.push(
      markLine(
        qbez([cx + s * 0.05, cy - s * 1.42], [cx + s * 0.78, cy - s * 0.9], [cx + s * 0.05, cy - s * 0.32], 10, rng, s * 0.02),
        paint,
        2,
        0.9,
      ),
    )
    marks.push(
      markLine(
        [
          [cx, cy - s * 1.55],
          [cx + s * 0.34, cy - s * 1.45],
          [cx, cy - s * 1.35],
        ],
        "rust",
        2,
        0.9,
      ),
    )
    return marks
  }

  function compassRose(rng, cx, cy, r, colour) {
    var paint = colour || "rust"
    var marks = []
    marks.push(markLine(ellipsePts(cx, cy, r, r, rng, { end: Math.PI * 2 + 0.3, wobble: 0.015 }), paint, 2, 0.9))
    var star = []
    for (var i = 0; i <= 16; i++) {
      var a = (i / 8) * Math.PI * 2 - Math.PI / 2
      var radius = i % 2 === 0 ? r * 0.8 : r * 0.34
      star.push([cx + Math.cos(a) * radius, cy + Math.sin(a) * radius])
    }
    marks.push(markLine(star, paint, 2, 0.9))
    marks.push(markLine(ellipsePts(cx, cy, r * 0.22, r * 0.22, rng, { end: Math.PI * 2, wobble: 0.03 }), paint, 1.5, 0.7))
    marks.push(markDot(cx, cy, r * 0.07, paint))
    return marks
  }

  function smallFish(rng, cx, cy, s, angle, colour) {
    var paint = colour || "paper"
    var top = qbez([cx - s * 0.5, cy], [cx, cy - s * 0.6], [cx + s * 0.5, cy], 10, rng, s * 0.02)
    var bottom = qbez([cx + s * 0.5, cy], [cx, cy + s * 0.6], [cx - s * 0.5, cy], 10, rng, s * 0.02)
    var tail = [
      [cx + s * 0.48, cy],
      [cx + s * 0.88, cy - s * 0.36],
      [cx + s * 0.62, cy],
      [cx + s * 0.88, cy + s * 0.36],
    ]
    var marks = [
      markLine(rotatePts(top.concat(bottom.slice(1)), cx, cy, angle), paint, 2.2, 0.95),
      markLine(rotatePts(tail, cx, cy, angle), paint, 2, 0.9),
    ]
    var eye = rotatePts([[cx - s * 0.26, cy - s * 0.08]], cx, cy, angle)[0]
    marks.push(markDot(eye[0], eye[1], s * 0.09, paint))
    return marks
  }

  function whiskerFan(rng, cx, cy, s, dir, colour) {
    var paint = colour || "rust"
    var marks = []
    var fans = [
      [-0.42, 1.25],
      [0.04, 1.45],
      [0.5, 1.2],
    ]
    fans.forEach(function (fan, index) {
      marks.push(
        markLine(
          squiggle(
            [cx, cy + s * fan[0] * 0.3],
            [cx + dir * s * fan[1], cy + s * fan[0] * 0.55],
            rng,
            0.005,
            0.9,
            10,
          ),
          paint,
          index === 1 ? 2 : 1.8,
          0.9,
        ),
      )
    })
    return marks
  }

  function loon(rng, cx, cy, s, colour) {
    var paint = colour || "paper"
    var body = qbez([cx - s, cy], [cx - s * 0.1, cy - s * 0.75], [cx + s * 0.8, cy - s * 0.12], 12, rng, s * 0.03)
    var belly = qbez([cx + s * 0.8, cy - s * 0.12], [cx, cy + s * 0.5], [cx - s, cy], 10, rng, s * 0.03)
    var neck = squiggle([cx - s * 0.25, cy - s * 0.3], [cx - s * 0.45, cy - s * 0.95], rng, 0.006, 0.6, 8)
    var beak = [
      [cx - s * 0.5, cy - s * 1.0],
      [cx - s * 0.92, cy - s * 0.88],
    ]
    var marks = [
      markLine(body.concat(belly.slice(1)), paint, 2.2, 0.95),
      markLine(neck, paint, 2, 0.9),
      markLine(beak, paint, 2, 0.9),
      markDot(cx - s * 0.4, cy - s * 0.9, s * 0.08, paint),
    ]
    return marks
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
      // a little rocket heading out of the field, with a dashed exhaust
      marks = marks.concat(withMarks(rocket(rng, 0.215, 0.72, 0.052, -38)))
      dashPath(
        [
          [0.28, 0.79],
          [0.4, 0.86],
          [0.52, 0.91],
          [0.62, 0.955],
        ],
        0.022,
        0.018,
      ).forEach(function (dash) {
        marks.push(markLine(dash, "rust", 1.8, 0.7))
      })
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
      // a small fish visiting the bubbles
      marks = marks.concat(withMarks(smallFish(rng, 0.655, 0.675, 0.05, -18, "rust")))
      marks.push(markDot(0.6, 0.655, 0.007, "navy"))
      marks.push(markDot(0.578, 0.638, 0.005, "navy"))
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
      // a little camp on the western shore
      marks = marks.concat(withMarks(tent(rng, 0.095, 0.585, 0.034)))
      marks = marks.concat(withMarks(campfire(rng, 0.152, 0.605, 0.02)))
      marks = marks.concat(withMarks(smokeCurl(rng, 0.152, 0.585, 0.02)))
      // and a loon out on the water
      marks = marks.concat(withMarks(loon(rng, 0.79, 0.61, 0.028)))
      marks.push(
        markLine(
          ellipsePts(0.79, 0.648, 0.05, 0.012, rng, {
            start: Math.PI * 1.1,
            end: Math.PI * 1.9,
            wobble: 0.05,
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
      // a shooting star over the clouds, and a fish jumping
      marks = marks.concat(withMarks(shootingStar(rng, [0.08, 0.09], [0.27, 0.2], "paper")))
      marks = marks.concat(withMarks(smallFish(rng, 0.45, 0.665, 0.042, -34)))
      marks.push(markDot(0.5, 0.63, 0.005, "paper"))
      marks.push(markDot(0.52, 0.68, 0.004, "paper"))
      marks.push(
        markLine(
          ellipsePts(0.49, 0.72, 0.035, 0.008, rng, {
            start: Math.PI * 1.15,
            end: Math.PI * 1.85,
            wobble: 0.05,
          }),
          "paper",
          1.4,
          0.5,
        ),
      )
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
      // a paper plane gliding through the light
      marks = marks.concat(withMarks(paperPlane(rng, 0.73, 0.135, 0.05, -16)))
      dashPath(qbez([0.56, 0.4], [0.5, 0.16], [0.695, 0.115], 16, rng, 0.004), 0.022, 0.018).forEach(function (dash) {
        marks.push(markLine(dash, "rust", 1.7, 0.7))
      })
      return marks
    },

    whale: function (rng) {
      var marks = []
      // the arc of the jump, drawn like a trampoline path
      var arc = qbez([0.16, 0.82], [0.1, 0.36], [0.24, 0.235], 22, rng, 0.004)
      dashPath(arc, 0.02, 0.017).forEach(function (dash) {
        marks.push(markLine(dash, "paper", 2.2, 0.8))
      })
      marks.push(
        markLine(
          [
            [0.24, 0.235],
            [0.205, 0.3],
          ],
          "paper",
          2.4,
          0.9,
        ),
      )
      marks.push(
        markLine(
          [
            [0.24, 0.235],
            [0.285, 0.29],
          ],
          "paper",
          2.4,
          0.9,
        ),
      )
      // top hat, because of course
      marks = marks.concat(withMarks(topHat(rng, 0.315, 0.3, 0.045, -14)))
      // a speech bubble with the whale's considered opinion
      marks = marks.concat(withMarks(speechBubble(rng, 0.66, 0.135, 0.135, 0.078, 0.56, 0.23, "paper")))
      marks.push(markLabel("quite deep, actually", 0.66, 0.135, -3, 0.027, "navy"))
      // a fish getting out of the way
      marks = marks.concat(withMarks(smallFish(rng, 0.875, 0.52, 0.04, -42)))
      marks.push(markDot(0.845, 0.575, 0.005, "paper"))
      marks.push(markDot(0.9, 0.585, 0.004, "paper"))
      // sparkles in the splash and bubbles underneath
      marks.push(markSparkle(0.63, 0.42, 0.011, "paper"))
      marks.push(markSparkle(0.71, 0.55, 0.009, "paper"))
      marks.push(markSparkle(0.5, 0.78, 0.009, "sky"))
      marks.push(markDot(0.36, 0.88, 0.006, "sky"))
      marks.push(markDot(0.4, 0.925, 0.0045, "sky"))
      return marks
    },

    cat: function (rng) {
      var marks = []
      // the opinion
      marks = marks.concat(withMarks(speechBubble(rng, 0.815, 0.125, 0.125, 0.075, 0.63, 0.36, "rust")))
      marks.push(markLabel("meow.", 0.815, 0.125, -4, 0.03, "navy"))
      marks.push(markLabel("unbothered", 0.63, 0.42, -5, 0.03, "rust"))
      marks.push(markLine(wavePts(0.45, 0.545, 0.715, 0.005, 2.5), "rust", 1.5, 0.75))
      // exaggerated whiskers on both sides of the muzzle
      marks = marks.concat(withMarks(whiskerFan(rng, 0.335, 0.555, 0.075, -1, "rust")))
      marks = marks.concat(withMarks(whiskerFan(rng, 0.585, 0.55, 0.06, 1, "rust")))
      // a ball of yarn, because the paw is clearly reaching for one
      marks = marks.concat(withMarks(yarnBall(rng, 0.135, 0.8, 0.055, "rust")))
      // and a fish bone just beyond the stretch
      marks = marks.concat(withMarks(fishBone(rng, 0.865, 0.6, 0.075, 10, "rust")))
      return marks
    },

    chart: function (rng) {
      var marks = []
      // compass, for orientation
      marks = marks.concat(withMarks(compassRose(rng, 0.575, 0.665, 0.065, "rust")))
      // a plotted route and a mark on the spot
      var route = qbez([0.14, 0.64], [0.24, 0.86], [0.42, 0.72], 18, rng, 0.004)
      var routeB = qbez([0.42, 0.72], [0.52, 0.64], [0.6, 0.775], 18, rng, 0.004)
      dashPath(route.concat(routeB.slice(1)), 0.022, 0.018).forEach(function (dash) {
        marks.push(markLine(dash, "rust", 2.2, 0.85))
      })
      marks.push(markLine([[0.575, 0.75], [0.625, 0.8]], "rust", 3.2, 0.95))
      marks.push(markLine([[0.625, 0.75], [0.575, 0.8]], "rust", 3.2, 0.95))
      // a ship under sail, leaving a wake
      marks = marks.concat(withMarks(ship(rng, 0.4, 0.655, 0.042)))
      dashPath(
        [
          [0.365, 0.675],
          [0.32, 0.69],
          [0.28, 0.698],
        ],
        0.012,
        0.011,
      ).forEach(function (dash) {
        marks.push(markLine(dash, "navy", 1.4, 0.6))
      })
      // something with tentacles, out where the soundings stop
      marks = marks.concat(withMarks(kraken(rng, 0.75, 0.835, 0.055, "rust")))
      // a jellyfish and a warning for travellers
      marks = marks.concat(withMarks(smallJellyfish(rng, 0.375, 0.34, 0.032, "rust")))
      marks.push(markLabel("here be jellies", 0.475, 0.285, -5, 0.03, "rust"))
      return marks
    },
  }

  function smallJellyfish(rng, cx, cy, s, colour) {
    var paint = colour || "rust"
    var bell = ellipsePts(cx, cy, s, s * 0.72, rng, { start: Math.PI, end: Math.PI * 2 + 0.25, wobble: 0.05 })
    var marks = [markLine(bell, paint, 2, 0.9)]
    for (var i = 0; i < 3; i++) {
      var startX = cx - s * 0.5 + i * s * 0.5
      marks.push(markLine(squiggle([startX, cy + s * 0.1], [startX + (i - 1) * s * 0.24, cy + s * 1.15], rng, 0.01, 1.6, 10), paint, 1.7, 0.85))
    }
    return marks
  }

  // ---------- scene construction and drawing ----------

  function buildScene(pieceId, seed) {
    var recipe = RECIPES[pieceId]
    var rng = makeRng(seed)
    var marks = recipe ? recipe(rng) : []
    var cursor = 60
    marks.forEach(function (mark) {
      var length = 0
      if (mark.kind === "line" || mark.kind === "fill") {
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
      mark.dur = Math.max(150, Math.min(900, length * 2200))
      cursor += Math.max(80, mark.dur * 0.55)
    })
    var maxTotal = 6200
    if (cursor > maxTotal) {
      var factor = maxTotal / cursor
      marks.forEach(function (mark) {
        mark.start *= factor
        mark.dur *= factor
      })
      cursor = maxTotal
    }
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

  function tracePath(ctx, pts, width, height) {
    ctx.beginPath()
    ctx.moveTo(pts[0][0] * width, pts[0][1] * height)
    for (var i = 1; i < pts.length; i++) {
      ctx.lineTo(pts[i][0] * width, pts[i][1] * height)
    }
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
      tracePath(ctx, partial, width, height)
      ctx.stroke()
      return
    }

    if (mark.kind === "fill") {
      var easedFill = progress * progress * (3 - 2 * progress)
      ctx.globalAlpha = (mark.alpha == null ? 0.85 : mark.alpha) * easedFill
      ctx.beginPath()
      ctx.moveTo(mark.pts[0][0] * width, mark.pts[0][1] * height)
      for (var f = 1; f < mark.pts.length; f++) {
        ctx.lineTo(mark.pts[f][0] * width, mark.pts[f][1] * height)
      }
      ctx.closePath()
      ctx.fill()
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

  // ---------- views (inline stages and the focus dialog share one scene) ----------

  function makeView(state, stage, ink, pad, kind) {
    var view = { state: state, stage: stage, ink: ink, pad: pad, kind: kind, w: 0, h: 0, dpr: 1 }
    if (kind === "inline") {
      bindPad(pad, function () {
        return view
      })
    }
    byStage.set(stage, view)
    sizeObserver.observe(stage)
    resizeView(view)
    return view
  }

  function drawView(view, time) {
    var ctx = view.ink.getContext("2d")
    ctx.setTransform(view.dpr, 0, 0, view.dpr, 0, 0)
    drawScene(ctx, view.state.scene, time, view.w, view.h, 1, view.state.colours)
  }

  function drawState(state, time) {
    state.views.forEach(function (view) {
      drawView(view, time)
    })
    if (time == null) state.scene.finished = true
  }

  function resizeView(view) {
    var rect = view.stage.getBoundingClientRect()
    var dpr = Math.min(2, window.devicePixelRatio || 1)
    var w = Math.max(1, Math.round(rect.width))
    var h = Math.max(1, Math.round(rect.height))
    if (w === view.w && h === view.h && dpr === view.dpr) return
    view.w = w
    view.h = h
    view.dpr = dpr
    ;[view.ink, view.pad].forEach(function (canvas) {
      canvas.width = Math.round(w * dpr)
      canvas.height = Math.round(h * dpr)
      canvas.style.width = w + "px"
      canvas.style.height = h + "px"
    })
    if (view.state.scene.started) drawView(view, null)
    redrawPad(view)
  }

  function redrawPad(view) {
    var state = view.state
    var ctx = view.pad.getContext("2d")
    ctx.setTransform(view.dpr, 0, 0, view.dpr, 0, 0)
    ctx.clearRect(0, 0, view.w, view.h)
    var dim = Math.min(view.w, view.h)
    ctx.lineCap = "round"
    ctx.lineJoin = "round"
    state.strokes.forEach(function (stroke) {
      if (stroke.pts.length < 2) return
      ctx.strokeStyle = state.colours[stroke.colour] || state.colours.rust
      ctx.lineWidth = Math.max(1, stroke.width * dim)
      ctx.globalAlpha = 0.9
      tracePath(ctx, stroke.pts, view.w, view.h)
      ctx.stroke()
    })
    ctx.globalAlpha = 1
  }

  function redrawAllPads(state) {
    state.views.forEach(redrawPad)
  }

  // ---------- animation ----------

  function animate(state) {
    state.scene.started = true
    if (state.raf) cancelAnimationFrame(state.raf)
    if (motionQuery.matches) {
      drawState(state, null)
      return
    }
    var started = performance.now()
    var step = function (now) {
      var time = now - started
      drawState(state, time)
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
    if (on) {
      states.forEach(function (other) {
        if (other !== state && other.drawMode) setDrawMode(other, false)
      })
    }
    state.drawMode = on
    refreshPad(state)
  }

  function refreshPad(state) {
    var hasStrokes = state.strokes.length > 0
    state.views.forEach(function (view) {
      if (view.kind === "inline") view.pad.hidden = !state.drawMode && !hasStrokes
    })
    state.piece.classList.toggle("ds-has-marks", hasStrokes)
    state.piece.classList.toggle("ds-drawing", state.drawMode)
    if (focusDialog && focusState === state) {
      focusDialog.classList.toggle("ds-drawing", state.drawMode)
    }
    var roots = [state.piece]
    if (focusDialog && focusState === state) roots.push(focusDialog)
    roots.forEach(function (rootEl) {
      var draw = rootEl.querySelector("[data-ds-draw]")
      if (draw) {
        draw.setAttribute("aria-pressed", state.drawMode ? "true" : "false")
        draw.textContent = state.drawMode ? "done drawing" : "draw on it"
      }
      var clear = rootEl.querySelector("[data-ds-clear]")
      if (clear) clear.hidden = !state.drawMode || !hasStrokes
      var save = rootEl.querySelector("[data-ds-save]")
      if (save) save.hidden = !state.drawMode
    })
  }

  function savePiece(state) {
    var naturalW = state.photo.naturalWidth || 1400
    var naturalH = state.photo.naturalHeight || 933
    var view = state.views[0]
    var canvas = document.createElement("canvas")
    canvas.width = naturalW
    canvas.height = naturalH
    var ctx = canvas.getContext("2d")
    if (!ctx) return
    ctx.drawImage(state.photo, 0, 0, naturalW, naturalH)
    var scale = naturalH / Math.max(1, view.h)
    drawScene(ctx, state.scene, null, naturalW, naturalH, scale, state.colours, false)
    var dim = Math.min(naturalW, naturalH)
    state.strokes.forEach(function (stroke) {
      if (stroke.pts.length < 2) return
      ctx.strokeStyle = state.colours[stroke.colour] || state.colours.rust
      ctx.lineWidth = Math.max(1, stroke.width * dim)
      ctx.lineCap = "round"
      ctx.lineJoin = "round"
      ctx.globalAlpha = 0.9
      tracePath(ctx, stroke.pts, naturalW, naturalH)
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

  // ---------- focus dialog ----------

  function buildFocusDialog() {
    var dialog = document.createElement("dialog")
    dialog.className = "ds-focus"
    dialog.setAttribute("data-ds-focus", "true")
    dialog.setAttribute("aria-labelledby", "ds-focus-title")
    dialog.innerHTML = [
      '<div class="ds-focus-sheet">',
      '<header class="ds-focus-head">',
      '<div class="ds-focus-meta">',
      '<h3 class="ds-focus-title" id="ds-focus-title"></h3>',
      '<p class="ds-focus-credit"><a target="_blank" rel="noopener noreferrer"></a></p>',
      "</div>",
      '<button type="button" class="ds-action ds-focus-close" data-ds-focus-close="true" aria-label="Close the focus view">close</button>',
      "</header>",
      '<div class="ds-focus-wrap">',
      '<div class="ds-focus-stage">',
      '<img class="ds-photo ds-focus-photo" src="data:image/gif;base64,R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs=" alt="" decoding="async">',
      '<canvas class="ds-ink ds-focus-ink" aria-hidden="true"></canvas>',
      '<canvas class="ds-pad ds-focus-pad" aria-hidden="true"></canvas>',
      "</div>",
      "</div>",
      '<div class="ds-tools ds-focus-tools">',
      '<button type="button" class="ds-action" data-ds-redoodle="true">doodle again</button>',
      '<button type="button" class="ds-action" data-ds-draw="true" aria-pressed="false">draw on it</button>',
      '<button type="button" class="ds-action ds-action-quiet" data-ds-clear="true" hidden>clear my marks</button>',
      '<button type="button" class="ds-action ds-action-quiet" data-ds-save="true" hidden>save a copy</button>',
      "</div>",
      "</div>",
    ].join("")
    dialog.addEventListener("click", function (event) {
      if (event.target === dialog) closeFocus()
    })
    dialog.addEventListener("close", finishClose)
    root.appendChild(dialog)
    var focusPad = dialog.querySelector(".ds-focus-pad")
    if (focusPad) {
      bindPad(focusPad, function () {
        return focusView
      })
    }
    return dialog
  }

  function layoutFocus() {
    if (!focusView || !focusDialog) return
    var wrap = focusDialog.querySelector(".ds-focus-wrap")
    var state = focusView.state
    var naturalW = state.photo.naturalWidth || 3
    var naturalH = state.photo.naturalHeight || 2
    var aspect = naturalW / naturalH
    var viewportW = Math.max(220, window.innerWidth - (window.innerWidth <= 800 ? 28 : 72))
    var availW = Math.min(wrap ? wrap.clientWidth : viewportW, viewportW)
    var availH = Math.max(180, Math.round(window.innerHeight * 0.62))
    var w = Math.max(220, Math.min(availW, Math.round(availH * aspect)))
    var h = Math.max(150, Math.round(w / aspect))
    focusView.stage.style.width = w + "px"
    focusView.stage.style.height = h + "px"
    resizeView(focusView)
  }

  function openFocus(state) {
    if (!focusDialog || state.drawMode) return
    focusState = state
    lastFocusTrigger = document.activeElement
    var title = state.piece.querySelector(".ds-title")
    var credit = state.piece.querySelector(".ds-credit")
    var titleEl = focusDialog.querySelector("#ds-focus-title")
    if (titleEl) titleEl.textContent = title ? title.textContent : ""
    var creditLink = focusDialog.querySelector(".ds-focus-credit a")
    if (creditLink instanceof HTMLAnchorElement) {
      if (credit instanceof HTMLAnchorElement) {
        creditLink.textContent = credit.textContent
        creditLink.href = credit.href
      } else {
        creditLink.textContent = ""
        creditLink.removeAttribute("href")
      }
    }
    var photo = focusDialog.querySelector(".ds-focus-photo")
    if (photo instanceof HTMLImageElement) {
      photo.src = state.photo.currentSrc || state.photo.src
      photo.alt = state.photo.alt
    }
    var stage = focusDialog.querySelector(".ds-focus-stage")
    var ink = focusDialog.querySelector(".ds-focus-ink")
    var pad = focusDialog.querySelector(".ds-focus-pad")
    if (!(stage instanceof HTMLElement) || !(ink instanceof HTMLCanvasElement) || !(pad instanceof HTMLCanvasElement)) return
    focusDialog.showModal()
    focusView = makeView(state, stage, ink, pad, "focus")
    state.views.push(focusView)
    layoutFocus()
    refreshPad(state)
    if (state.scene.started) drawView(focusView, null)
    else animate(state)
    var closeButton = focusDialog.querySelector("[data-ds-focus-close]")
    if (closeButton instanceof HTMLButtonElement) closeButton.focus({ preventScroll: true })
  }

  function closeFocus() {
    if (focusDialog && focusDialog.open) focusDialog.close()
  }

  function finishClose() {
    if (focusView) {
      sizeObserver.unobserve(focusView.stage)
      byStage.delete(focusView.stage)
      var index = focusState ? focusState.views.indexOf(focusView) : -1
      if (focusState && index >= 0) focusState.views.splice(index, 1)
      focusView = null
    }
    if (focusState) {
      focusState.piece.classList.remove("ds-drawing")
      refreshPad(focusState)
    }
    focusState = null
    if (lastFocusTrigger instanceof HTMLElement) lastFocusTrigger.focus({ preventScroll: true })
    lastFocusTrigger = null
  }

  // ---------- pad input ----------

  function padPoint(view, event) {
    var rect = view.pad.getBoundingClientRect()
    return [
      clamp01((event.clientX - rect.left) / Math.max(1, rect.width)),
      clamp01((event.clientY - rect.top) / Math.max(1, rect.height)),
    ]
  }

  function bindPad(pad, viewResolver) {
    pad.addEventListener("pointerdown", function (event) {
      var view = viewResolver()
      if (!view) return
      var state = view.state
      if (!state.drawMode) return
      event.preventDefault()
      state.drawing = true
      var stroke = { colour: "rust", width: 0.0045, pts: [padPoint(view, event)] }
      state.strokes.push(stroke)
      pad.setPointerCapture(event.pointerId)
      redrawPad(view)
      refreshPad(state)
    })
    pad.addEventListener("pointermove", function (event) {
      var view = viewResolver()
      if (!view) return
      var state = view.state
      if (!state.drawing) return
      event.preventDefault()
      var stroke = state.strokes[state.strokes.length - 1]
      if (!stroke) return
      var samples = typeof event.getCoalescedEvents === "function" ? event.getCoalescedEvents() : [event]
      if (samples.length === 0) samples = [event]
      var ctx = view.pad.getContext("2d")
      ctx.setTransform(view.dpr, 0, 0, view.dpr, 0, 0)
      ctx.strokeStyle = state.colours[stroke.colour] || state.colours.rust
      ctx.lineWidth = Math.max(1, stroke.width * Math.min(view.w, view.h))
      ctx.lineCap = "round"
      ctx.lineJoin = "round"
      ctx.globalAlpha = 0.9
      samples.forEach(function (sample) {
        var point = padPoint(view, sample)
        var last = stroke.pts[stroke.pts.length - 1]
        ctx.beginPath()
        ctx.moveTo(last[0] * view.w, last[1] * view.h)
        ctx.lineTo(point[0] * view.w, point[1] * view.h)
        ctx.stroke()
        stroke.pts.push(point)
      })
      ctx.globalAlpha = 1
    })
    var endStroke = function () {
      var view = viewResolver()
      if (!view) return
      var state = view.state
      if (!state.drawing) return
      state.drawing = false
      redrawAllPads(state)
      refreshPad(state)
    }
    pad.addEventListener("pointerup", endStroke)
    pad.addEventListener("pointercancel", endStroke)
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
    if (button.hasAttribute("data-ds-focus-close")) {
      closeFocus()
      return
    }
    var state = null
    var piece = button.closest("[data-ds-piece]")
    if (piece) {
      state = byPiece.get(piece)
    } else if (button.closest("[data-ds-focus]")) {
      state = focusState
    }
    if (!state) return
    if (button.hasAttribute("data-ds-open")) {
      openFocus(state)
    } else if (button.hasAttribute("data-ds-redoodle")) {
      redoodle(state)
    } else if (button.hasAttribute("data-ds-draw")) {
      setDrawMode(state, !state.drawMode)
    } else if (button.hasAttribute("data-ds-clear")) {
      state.strokes = []
      redrawAllPads(state)
      refreshPad(state)
    } else if (button.hasAttribute("data-ds-save")) {
      savePiece(state)
    }
  }
  root.addEventListener("click", onClick)

  var sizeObserver = new ResizeObserver(function (entries) {
    entries.forEach(function (entry) {
      var view = byStage.get(entry.target)
      if (view) resizeView(view)
    })
  })

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

  var themeObserver = new MutationObserver(function () {
    states.forEach(function (state) {
      state.colours = palette()
      if (state.scene.finished) drawState(state, null)
      redrawAllPads(state)
    })
  })

  var onWindowResize = function () {
    states.forEach(function (state) {
      state.views.forEach(resizeView)
    })
    layoutFocus()
  }

  // ---------- build ----------

  pieces.forEach(function (pieceEl) {
    var stage = pieceEl.querySelector(".ds-stage")
    var ink = pieceEl.querySelector(".ds-ink")
    var pad = pieceEl.querySelector(".ds-pad")
    var photo = pieceEl.querySelector(".ds-photo")
    if (!(stage instanceof HTMLElement)) return
    if (!(ink instanceof HTMLCanvasElement) || !(pad instanceof HTMLCanvasElement)) return
    if (!(photo instanceof HTMLImageElement)) return
    var state = {
      id: pieceEl.getAttribute("data-ds-piece"),
      piece: pieceEl,
      stage: stage,
      ink: ink,
      pad: pad,
      photo: photo,
      seed: Number(pieceEl.getAttribute("data-ds-seed")) || 7,
      colours: palette(),
      scene: null,
      raf: 0,
      strokes: [],
      drawing: false,
      drawMode: false,
      views: [],
    }
    state.scene = buildScene(state.id, state.seed)
    states.push(state)
    byPiece.set(pieceEl, state)
  })

  if (states.length === 0) return

  focusDialog = buildFocusDialog()

  states.forEach(function (state) {
    var stage = state.stage
    var ink = state.ink
    var pad = state.pad
    var view = makeView(state, stage, ink, pad, "inline")
    state.views.push(view)
    refreshPad(state)
    if (motionQuery.matches) {
      animate(state)
    } else {
      observer.observe(state.piece)
    }
  })

  var fontLoad =
    document.fonts && document.fonts.load
      ? document.fonts
          .load('italic 24px "Playwrite GB J Guides"')
          .then(function () {
            return document.fonts.ready
          })
          .catch(function () {
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
      if (state.scene.started && state.scene.finished) drawState(state, null)
    })
  })

  themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ["saved-theme"] })
  window.addEventListener("resize", onWindowResize, { passive: true })

  var onKeyDown = function (event) {
    if (event.key !== "Escape") return
    if (focusDialog && focusDialog.open) closeFocus()
  }
  document.addEventListener("keydown", onKeyDown)

  var motionListener = function () {
    if (!motionQuery.matches) return
    states.forEach(function (state) {
      if (state.raf) cancelAnimationFrame(state.raf)
      state.raf = 0
      state.scene.started = true
      drawState(state, null)
    })
  }
  if (typeof motionQuery.addEventListener === "function") motionQuery.addEventListener("change", motionListener)

  window.addCleanup &&
    window.addCleanup(function () {
      states.forEach(function (state) {
        if (state.raf) cancelAnimationFrame(state.raf)
      })
      if (focusDialog && focusDialog.open) focusDialog.close()
      sizeObserver.disconnect()
      observer.disconnect()
      themeObserver.disconnect()
      root.removeEventListener("click", onClick)
      document.removeEventListener("keydown", onKeyDown)
      window.removeEventListener("resize", onWindowResize)
      if (typeof motionQuery.removeEventListener === "function")
        motionQuery.removeEventListener("change", motionListener)
      root.removeAttribute("data-ds-ready")
    })
}

document.addEventListener("nav", setupDeepSeekThoughts)
`
