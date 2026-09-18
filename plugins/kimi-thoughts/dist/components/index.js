// src/components/index.ts
import { h } from "preact"

// src/doodle-script.ts
var DOODLE_SCRIPT = `
function setupKimiThoughts() {
  var root = document.querySelector("[data-kt-lab]")
  if (!(root instanceof HTMLElement) || root.getAttribute("data-kt-ready") === "true") return
  var pieces = Array.prototype.slice.call(root.querySelectorAll("[data-kt-piece]"))
  if (pieces.length === 0) return
  root.setAttribute("data-kt-ready", "true")

  var motionQuery = window.matchMedia("(prefers-reduced-motion: reduce)")
  var HAND_FONT = '"Playwrite GB J Guides", "Segoe Print", cursive'
  var IDLE_MS = 160
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
      white: "#ffffff",
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

  function pathLength(pts) {
    var length = 0
    for (var i = 1; i < pts.length; i++) {
      length += Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1])
    }
    return length
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
  function markDash(pts, colour, width, dash, gap, alpha) {
    return {
      kind: "dashline",
      pts: pts,
      colour: colour || "rust",
      width: width || 1.8,
      dash: dash || 0.02,
      gap: gap || 0.016,
      alpha: alpha,
    }
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

  function speechBubble(rng, cx, cy, rx, ry, tailX, tailY, colour) {
    var paint = colour || "paper"
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

  /** A slightly apologetic, hand-drawn lightning bolt with two branches. */
  function lightning(rng, from, to, spread, colour) {
    var paint = colour || "paper"
    var marks = []
    var dx = to[0] - from[0]
    var dy = to[1] - from[1]
    var len = Math.hypot(dx, dy) || 0.0001
    var nx = -dy / len
    var ny = dx / len
    var steps = 9
    var pts = [from.slice()]
    for (var i = 1; i < steps; i++) {
      var t = i / steps
      var off = (rng() - 0.5) * 2 * spread * Math.sin(t * Math.PI)
      pts.push([from[0] + dx * t + nx * off, from[1] + dy * t + ny * off])
    }
    pts.push(to.slice())
    marks.push(markLine(pts, paint, 2.6, 0.95))
    ;[
      [0.35, 1],
      [0.62, -1],
    ].forEach(function (cfg) {
      var base = pts[Math.floor(cfg[0] * steps)]
      var dir = cfg[1]
      var bl = len * (0.22 + rng() * 0.12)
      var bx = base[0] + (dx / len) * bl * 0.4 + nx * dir * bl * 0.8
      var by = base[1] + (dy / len) * bl * 0.4 + ny * dir * bl * 0.8
      var bpts = [base.slice()]
      for (var j = 1; j <= 4; j++) {
        var bt = j / 4
        bpts.push([
          base[0] + (bx - base[0]) * bt + (rng() - 0.5) * spread * 0.5,
          base[1] + (by - base[1]) * bt + (rng() - 0.5) * spread * 0.5,
        ])
      }
      marks.push(markLine(bpts, paint, 1.6, 0.8))
    })
    return marks
  }

  /** An umbrella: canopy, scalloped edge, handle with a hook. */
  function umbrella(rng, cx, cy, s, colour) {
    var paint = colour || "paper"
    var marks = []
    marks.push(
      markLine(ellipsePts(cx, cy, s * 0.95, s * 0.5, rng, { start: Math.PI, end: Math.PI * 2 + 0.1, wobble: 0.04 }), paint, 2.4, 0.95),
    )
    var scallops = []
    var n = 4
    for (var i = 0; i < n; i++) {
      var x0 = cx - s * 0.95 + (i / n) * s * 1.9
      var x1 = cx - s * 0.95 + ((i + 1) / n) * s * 1.9
      var seg = qbez([x0, cy], [(x0 + x1) / 2, cy + s * 0.16], [x1, cy], 6, rng, s * 0.01)
      scallops = scallops.concat(i === 0 ? seg : seg.slice(1))
    }
    marks.push(markLine(scallops, paint, 2, 0.9))
    marks.push(markLine([[cx, cy - s * 0.5], [cx, cy]], paint, 1.6, 0.8))
    marks.push(markLine(squiggle([cx, cy], [cx, cy + s * 0.95], rng, 0.002, 0.4, 6), paint, 2, 0.9))
    marks.push(
      markLine(qbez([cx, cy + s * 0.95], [cx + s * 0.16, cy + s * 1.1], [cx + s * 0.2, cy + s * 0.9], 8, rng, 0.002), paint, 2, 0.9),
    )
    return marks
  }

  /** A stick figure mid-stride, holding an umbrella against the weather. */
  function umbrellaFigure(rng, cx, baseY, s, colour) {
    var paint = colour || "paper"
    var marks = []
    marks.push(
      markLine(ellipsePts(cx, baseY - s * 0.92, s * 0.16, s * 0.16, rng, { end: Math.PI * 2 + 0.3, wobble: 0.05 }), paint, 2.2, 0.95),
    )
    marks.push(markLine(squiggle([cx, baseY - s * 0.76], [cx, baseY - s * 0.4], rng, 0.003, 0.5, 6), paint, 2.2, 0.95))
    marks.push(markLine(squiggle([cx, baseY - s * 0.4], [cx - s * 0.3, baseY], rng, 0.004, 0.5, 6), paint, 2.2, 0.9))
    marks.push(markLine(squiggle([cx, baseY - s * 0.4], [cx + s * 0.32, baseY - s * 0.04], rng, 0.004, 0.5, 6), paint, 2.2, 0.9))
    var hx = cx + s * 0.34
    marks.push(markLine(squiggle([cx, baseY - s * 0.66], [hx, baseY - s * 0.72], rng, 0.003, 0.5, 6), paint, 2, 0.9))
    marks = marks.concat(withMarks(umbrella(rng, hx, baseY - s * 1.32, s * 0.72, paint)))
    return marks
  }

  /** Three curved speed lines. */
  function whoosh(rng, cx, cy, s, angle, colour) {
    var paint = colour || "paper"
    var marks = []
    for (var i = 0; i < 3; i++) {
      var off = (i - 1) * s * 0.4
      var len = s * (1.4 - i * 0.3)
      var line = qbez([cx - len * 0.5, cy + off], [cx, cy + off - s * 0.12], [cx + len * 0.5, cy + off], 8, rng, s * 0.01)
      marks.push(markLine(rotatePts(line, cx, cy, angle), paint, 1.8, 0.75))
    }
    return marks
  }

  /** A butterfly: two wing pairs, a body, and antennae with little knobs. */
  function butterfly(rng, cx, cy, s, angle, colour) {
    var paint = colour || "rust"
    var marks = []
    var wings = [
      ellipsePts(cx - s * 0.42, cy - s * 0.22, s * 0.5, s * 0.38, rng, { end: Math.PI * 2 + 0.2, wobble: 0.05 }),
      ellipsePts(cx + s * 0.42, cy - s * 0.22, s * 0.5, s * 0.38, rng, { end: Math.PI * 2 + 0.2, wobble: 0.05 }),
      ellipsePts(cx - s * 0.3, cy + s * 0.3, s * 0.34, s * 0.26, rng, { end: Math.PI * 2 + 0.2, wobble: 0.05 }),
      ellipsePts(cx + s * 0.3, cy + s * 0.3, s * 0.34, s * 0.26, rng, { end: Math.PI * 2 + 0.2, wobble: 0.05 }),
    ]
    wings.forEach(function (w) {
      marks.push(markLine(rotatePts(w, cx, cy, angle), paint, 2, 0.9))
    })
    marks.push(
      markLine(rotatePts(squiggle([cx, cy - s * 0.5], [cx, cy + s * 0.55], rng, 0.003, 0.5, 8), cx, cy, angle), paint, 2.4, 0.95),
    )
    ;[-1, 1].forEach(function (d) {
      var tip = rotatePts(
        [
          [cx, cy - s * 0.5],
          [cx + d * s * 0.22, cy - s * 0.85],
        ],
        cx,
        cy,
        angle,
      )
      marks.push(markLine(tip, paint, 1.4, 0.85))
      marks.push(markDot(tip[1][0], tip[1][1], s * 0.05, paint))
    })
    return marks
  }

  /** A small mouse, whiskers and all. */
  function mouse(rng, cx, cy, s, colour) {
    var paint = colour || "ink"
    var marks = []
    marks.push(markLine(ellipsePts(cx, cy, s, s * 0.62, rng, { end: Math.PI * 2 + 0.3, wobble: 0.05 }), paint, 2.2, 0.95))
    marks.push(
      markLine(ellipsePts(cx + s * 0.85, cy - s * 0.12, s * 0.45, s * 0.4, rng, { end: Math.PI * 2 + 0.3, wobble: 0.05 }), paint, 2.2, 0.95),
    )
    marks.push(
      markLine(ellipsePts(cx + s * 0.68, cy - s * 0.5, s * 0.2, s * 0.2, rng, { end: Math.PI * 2 + 0.2, wobble: 0.06 }), paint, 1.8, 0.9),
    )
    marks.push(markDot(cx + s * 0.95, cy - s * 0.2, s * 0.06, paint))
    marks.push(markDot(cx + s * 1.3, cy - s * 0.06, s * 0.05, paint))
    marks.push(
      markLine(qbez([cx - s * 0.95, cy + s * 0.1], [cx - s * 1.9, cy - s * 0.3], [cx - s * 2.2, cy - s * 0.9], 12, rng, s * 0.02), paint, 1.8, 0.9),
    )
    marks.push(
      markLine(
        [
          [cx + s * 1.1, cy - s * 0.05],
          [cx + s * 1.5, cy - s * 0.15],
        ],
        paint,
        1.2,
        0.7,
      ),
    )
    marks.push(
      markLine(
        [
          [cx + s * 1.1, cy],
          [cx + s * 1.5, cy + s * 0.08],
        ],
        paint,
        1.2,
        0.7,
      ),
    )
    return marks
  }

  /** A trail of paw prints walking from one point to another. */
  function pawPrints(rng, from, to, count, colour) {
    var paint = colour || "rust"
    var marks = []
    var dx = to[0] - from[0]
    var dy = to[1] - from[1]
    var len = Math.hypot(dx, dy) || 0.0001
    var nx = -dy / len
    var ny = dx / len
    var walk = Math.atan2(dy, dx)
    for (var i = 0; i < count; i++) {
      var t = count === 1 ? 0.5 : i / (count - 1)
      var side = i % 2 === 0 ? 1 : -1
      var px = from[0] + dx * t + nx * side * 0.012
      var py = from[1] + dy * t + ny * side * 0.012
      var pad = ellipsePts(px, py, 0.0075, 0.0065, rng, { end: Math.PI * 2 + 0.2, wobble: 0.04 })
      marks.push(markFill(rotatePts(pad, px, py, (walk * 180) / Math.PI), paint, 0.75))
      for (var j = -1; j <= 1; j++) {
        var ta = walk + j * 0.45
        marks.push(markDot(px + Math.cos(ta) * 0.014, py + Math.sin(ta) * 0.014, 0.003, paint))
      }
    }
    return marks
  }

  /** A single quaver, head filled, flag flying. */
  function musicNote(rng, cx, cy, s, colour) {
    var paint = colour || "paper"
    var marks = []
    var head = ellipsePts(cx, cy, s * 0.32, s * 0.24, rng, { end: Math.PI * 2 + 0.2, wobble: 0.04 })
    marks.push(markFill(rotatePts(head, cx, cy, -18), paint, 0.9))
    marks.push(markLine(squiggle([cx + s * 0.28, cy - s * 0.05], [cx + s * 0.34, cy - s * 1.35], rng, 0.002, 0.4, 6), paint, 2, 0.9))
    marks.push(
      markLine(qbez([cx + s * 0.34, cy - s * 1.35], [cx + s * 0.85, cy - s * 1.1], [cx + s * 0.7, cy - s * 0.6], 8, rng, 0.003), paint, 2, 0.9),
    )
    return marks
  }

  /** A snail: spiral shell, soft body, two brave eyestalks. */
  function snail(rng, cx, cy, s, colour) {
    var paint = colour || "paper"
    var marks = []
    marks.push(markLine(spiralPts(cx, cy - s * 0.35, s * 0.55, s * 0.08, 2.2, rng), paint, 2.2, 0.95))
    marks.push(
      markLine(qbez([cx - s * 0.9, cy + s * 0.35], [cx, cy + s * 0.5], [cx + s * 1.1, cy + s * 0.3], 10, rng, s * 0.02), paint, 2.4, 0.95),
    )
    ;[-1, 1].forEach(function (d) {
      var tip = [cx + s * (1.15 + 0.18 * d), cy - s * 0.38]
      marks.push(markLine(squiggle([cx + s * 1.05, cy + s * 0.12], tip, rng, 0.003, 0.5, 6), paint, 1.7, 0.9))
      marks.push(markDot(tip[0], tip[1], s * 0.06, paint))
    })
    return marks
  }

  /** A spider letting itself down on a thread. */
  function spider(rng, cx, cy, s, threadFrom, colour) {
    var paint = colour || "ink"
    var marks = []
    marks.push(markLine(squiggle(threadFrom, [cx, cy - s * 0.5], rng, 0.001, 0.3, 5), paint, 1.4, 0.8))
    marks.push(markLine(ellipsePts(cx, cy, s * 0.5, s * 0.55, rng, { end: Math.PI * 2 + 0.3, wobble: 0.05 }), paint, 2, 0.95))
    marks.push(
      markLine(ellipsePts(cx, cy + s * 0.62, s * 0.28, s * 0.26, rng, { end: Math.PI * 2 + 0.2, wobble: 0.05 }), paint, 1.8, 0.9),
    )
    for (var i = 0; i < 4; i++) {
      var a = -0.9 + i * 0.55
      ;[-1, 1].forEach(function (d) {
        var kx = cx + d * s * 0.45
        var ky = cy + Math.sin(a) * s * 0.4
        var fx = cx + d * s * (1.1 + 0.15 * Math.cos(a))
        var fy = cy + Math.sin(a) * s * 1.05
        marks.push(markLine(qbez([kx, ky], [(kx + fx) / 2, ky - s * 0.35], [fx, fy], 6, rng, s * 0.01), paint, 1.5, 0.85))
      })
    }
    marks.push(markDot(cx - s * 0.1, cy + s * 0.6, s * 0.05, paint))
    marks.push(markDot(cx + s * 0.1, cy + s * 0.6, s * 0.05, paint))
    return marks
  }

  /** A reindeer on the shore, antlers held high. Sizes are explicit x/y units. */
  function reindeer(rng, cx, baseY, sx, sy, colour) {
    var paint = colour || "paper"
    var marks = []
    var bodyY = baseY - sy * 0.55
    marks.push(markLine(ellipsePts(cx, bodyY, sx * 0.5, sy * 0.3, rng, { end: Math.PI * 2 + 0.3, wobble: 0.04 }), paint, 2.2, 0.95))
    ;[-0.3, -0.12, 0.14, 0.32].forEach(function (d) {
      marks.push(markLine(squiggle([cx + sx * d, bodyY + sy * 0.2], [cx + sx * (d + 0.02), baseY], rng, 0.0015, 0.4, 5), paint, 1.8, 0.9))
    })
    marks.push(markLine(squiggle([cx + sx * 0.35, bodyY - sy * 0.15], [cx + sx * 0.52, bodyY - sy * 0.62], rng, 0.0015, 0.4, 5), paint, 2.2, 0.9))
    marks.push(
      markLine(ellipsePts(cx + sx * 0.58, bodyY - sy * 0.66, sx * 0.16, sy * 0.11, rng, { end: Math.PI * 2 + 0.2, wobble: 0.05 }), paint, 2, 0.9),
    )
    var ax = cx + sx * 0.55
    var ay = bodyY - sy * 0.76
    ;[-1, 1].forEach(function (d) {
      marks.push(markLine(qbez([ax, ay], [ax + sx * 0.1 * d, ay - sy * 0.3], [ax + sx * 0.22 * d, ay - sy * 0.42], 6, rng, 0.001), paint, 1.8, 0.9))
      marks.push(
        markLine(
          [
            [ax + sx * 0.08 * d, ay - sy * 0.18],
            [ax + sx * 0.2 * d, ay - sy * 0.26],
          ],
          paint,
          1.5,
          0.85,
        ),
      )
      marks.push(
        markLine(
          [
            [ax + sx * 0.16 * d, ay - sy * 0.32],
            [ax + sx * 0.3 * d, ay - sy * 0.38],
          ],
          paint,
          1.5,
          0.85,
        ),
      )
    })
    marks.push(
      markLine(
        [
          [cx - sx * 0.5, bodyY - sy * 0.1],
          [cx - sx * 0.6, bodyY - sy * 0.22],
        ],
        paint,
        1.8,
        0.9,
      ),
    )
    return marks
  }

  /** A small owl on a perch. Sizes are explicit x/y units. */
  function owl(rng, cx, cy, sx, sy, colour) {
    var paint = colour || "paper"
    var marks = []
    marks.push(markLine(ellipsePts(cx, cy, sx, sy, rng, { end: Math.PI * 2 + 0.3, wobble: 0.04 }), paint, 2.2, 0.95))
    marks.push(
      markLine(
        [
          [cx - sx * 0.55, cy - sy * 0.75],
          [cx - sx * 0.75, cy - sy * 1.15],
        ],
        paint,
        2,
        0.9,
      ),
    )
    marks.push(
      markLine(
        [
          [cx + sx * 0.55, cy - sy * 0.75],
          [cx + sx * 0.75, cy - sy * 1.15],
        ],
        paint,
        2,
        0.9,
      ),
    )
    ;[-1, 1].forEach(function (d) {
      marks.push(
        markLine(ellipsePts(cx + d * sx * 0.38, cy - sy * 0.3, sx * 0.26, sy * 0.22, rng, { end: Math.PI * 2 + 0.2, wobble: 0.05 }), paint, 1.8, 0.9),
      )
      marks.push(markDot(cx + d * sx * 0.38, cy - sy * 0.3, Math.min(sx, sy) * 0.09, paint))
    })
    marks.push(
      markLine(
        [
          [cx, cy - sy * 0.08],
          [cx - sx * 0.08, cy + sy * 0.08],
          [cx + sx * 0.08, cy + sy * 0.08],
          [cx, cy - sy * 0.08],
        ],
        paint,
        1.6,
        0.9,
      ),
    )
    marks.push(markLine(squiggle([cx - sx * 1.4, cy + sy * 1.05], [cx + sx * 1.4, cy + sy * 1.0], rng, 0.002, 0.5, 8), paint, 2, 0.85))
    return marks
  }

  /** The classic folded-paper boat. */
  function origamiBoat(rng, cx, cy, s, angle, colour) {
    var paint = colour || "rust"
    var hull = [
      [-1, 0.12],
      [-0.45, 0.12],
      [0, -0.72],
      [0.45, 0.12],
      [1, 0.12],
      [0.5, 0.55],
      [-0.5, 0.55],
      [-1, 0.12],
    ].map(function (p) {
      return [cx + p[0] * s, cy + p[1] * s]
    })
    var fold = [
      [cx - s * 0.45, cy + s * 0.12],
      [cx + s * 0.45, cy + s * 0.12],
    ]
    var mast = [
      [cx, cy - s * 0.72],
      [cx, cy + s * 0.12],
    ]
    return [
      markFill(rotatePts(hull, cx, cy, angle), "paper", 0.8),
      markLine(rotatePts(hull, cx, cy, angle), paint, 2.2, 0.95),
      markLine(rotatePts(fold, cx, cy, angle), paint, 1.5, 0.8),
      markLine(rotatePts(mast, cx, cy, angle), paint, 1.5, 0.8),
    ]
  }

  /** A crouched surfer riding the face. */
  function surfer(rng, cx, cy, s, angle, colour) {
    var paint = colour || "paper"
    var marks = []
    marks.push(
      markLine(rotatePts(qbez([cx - s, cy + s * 0.34], [cx, cy + s * 0.46], [cx + s, cy + s * 0.3], 10, rng, s * 0.015), cx, cy, angle), paint, 2.6, 0.95),
    )
    marks.push(
      markLine(rotatePts(ellipsePts(cx + s * 0.05, cy - s * 0.62, s * 0.15, s * 0.15, rng, { end: Math.PI * 2 + 0.2, wobble: 0.05 }), cx, cy, angle), paint, 2.2, 0.95),
    )
    marks.push(
      markLine(rotatePts(qbez([cx + s * 0.02, cy - s * 0.48], [cx - s * 0.12, cy - s * 0.2], [cx - s * 0.02, cy - s * 0.05], 8, rng, s * 0.01), cx, cy, angle), paint, 2.4, 0.95),
    )
    marks.push(
      markLine(rotatePts(qbez([cx - s * 0.04, cy - s * 0.36], [cx + s * 0.4, cy - s * 0.3], [cx + s * 0.58, cy - s * 0.42], 6, rng, s * 0.01), cx, cy, angle), paint, 2, 0.9),
    )
    marks.push(
      markLine(rotatePts(qbez([cx - s * 0.06, cy - s * 0.36], [cx - s * 0.42, cy - s * 0.5], [cx - s * 0.6, cy - s * 0.42], 6, rng, s * 0.01), cx, cy, angle), paint, 2, 0.9),
    )
    marks.push(
      markLine(
        rotatePts(
          [
            [cx - s * 0.02, cy - s * 0.05],
            [cx + s * 0.3, cy + s * 0.12],
            [cx + s * 0.34, cy + s * 0.34],
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
            [cx - s * 0.02, cy - s * 0.05],
            [cx - s * 0.3, cy + s * 0.14],
            [cx - s * 0.36, cy + s * 0.36],
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
      markLine(rotatePts(squiggle([cx - s * 1.05, cy + s * 0.3], [cx - s * 1.4, cy + s * 0.1], rng, 0.006, 1, 8), cx, cy, angle), paint, 1.6, 0.7),
    )
    return marks
  }

  /** A cat loaf, asleep on duty. */
  function sittingCat(rng, cx, baseY, s, colour) {
    var paint = colour || "paper"
    var marks = []
    var body = qbez([cx - s, baseY], [cx - s * 0.9, baseY - s * 0.85], [cx, baseY - s * 0.8], 10, rng, s * 0.02).concat(
      qbez([cx, baseY - s * 0.8], [cx + s * 0.9, baseY - s * 0.85], [cx + s, baseY], 10, rng, s * 0.02).slice(1),
    )
    marks.push(markLine(body, paint, 2.4, 0.95))
    marks.push(
      markLine(ellipsePts(cx + s * 0.25, baseY - s * 0.95, s * 0.34, s * 0.3, rng, { end: Math.PI * 2 + 0.2, wobble: 0.05 }), paint, 2.2, 0.95),
    )
    marks.push(
      markLine(
        [
          [cx + s * 0.02, baseY - s * 1.14],
          [cx + s * 0.08, baseY - s * 1.36],
          [cx + s * 0.2, baseY - s * 1.18],
        ],
        paint,
        2,
        0.9,
      ),
    )
    marks.push(
      markLine(
        [
          [cx + s * 0.34, baseY - s * 1.18],
          [cx + s * 0.46, baseY - s * 1.36],
          [cx + s * 0.5, baseY - s * 1.12],
        ],
        paint,
        2,
        0.9,
      ),
    )
    marks.push(
      markLine(qbez([cx - s * 0.95, baseY - s * 0.05], [cx - s * 1.25, baseY - s * 0.4], [cx - s * 0.85, baseY - s * 0.5], 8, rng, s * 0.015), paint, 2, 0.9),
    )
    marks.push(
      markLine(qbez([cx + s * 0.12, baseY - s * 0.98], [cx + s * 0.18, baseY - s * 0.94], [cx + s * 0.24, baseY - s * 0.98], 4, rng, 0.001), paint, 1.5, 0.9),
    )
    return marks
  }

  /** Sunglasses, for a sun that knows it is the centre of things. */
  function sunglasses(rng, cx, cy, s, colour) {
    var paint = colour || "ink"
    var marks = []
    ;[-1, 1].forEach(function (d) {
      var lens = ellipsePts(cx + d * s * 0.55, cy, s * 0.42, s * 0.34, rng, { end: Math.PI * 2 + 0.2, wobble: 0.03 })
      marks.push(markFill(lens, paint, 0.85))
      marks.push(markLine(lens, paint, 2.2, 0.95))
    })
    marks.push(markLine(qbez([cx - s * 0.15, cy - s * 0.05], [cx, cy - s * 0.16], [cx + s * 0.15, cy - s * 0.05], 6, rng, 0.002), paint, 2.2, 0.95))
    marks.push(
      markLine(
        [
          [cx - s * 0.97, cy - s * 0.05],
          [cx - s * 1.3, cy - s * 0.3],
        ],
        paint,
        2,
        0.9,
      ),
    )
    marks.push(
      markLine(
        [
          [cx + s * 0.97, cy - s * 0.05],
          [cx + s * 1.3, cy - s * 0.3],
        ],
        paint,
        2,
        0.9,
      ),
    )
    return marks
  }

  /** A little astronaut, tethered and floating. */
  function astronaut(rng, cx, cy, s, angle, colour) {
    var paint = colour || "paper"
    var marks = []
    marks.push(
      markLine(rotatePts(ellipsePts(cx, cy - s * 0.4, s * 0.34, s * 0.34, rng, { end: Math.PI * 2 + 0.2, wobble: 0.04 }), cx, cy, angle), paint, 2.2, 0.95),
    )
    marks.push(
      markLine(
        rotatePts(ellipsePts(cx, cy - s * 0.4, s * 0.2, s * 0.16, rng, { start: Math.PI * 0.1, end: Math.PI * 0.9, wobble: 0.04 }), cx, cy, angle),
        paint,
        1.6,
        0.85,
      ),
    )
    marks.push(markLine(rotatePts(squiggle([cx, cy - s * 0.06], [cx, cy + s * 0.5], rng, 0.003, 0.5, 6), cx, cy, angle), paint, 2.4, 0.95))
    marks.push(
      markLine(rotatePts(qbez([cx, cy + s * 0.05], [cx - s * 0.45, cy + s * 0.2], [cx - s * 0.6, cy + s * 0.05], 6, rng, 0.002), cx, cy, angle), paint, 2, 0.9),
    )
    marks.push(
      markLine(rotatePts(qbez([cx, cy + s * 0.05], [cx + s * 0.45, cy - s * 0.15], [cx + s * 0.62, cy - s * 0.3], 6, rng, 0.002), cx, cy, angle), paint, 2, 0.9),
    )
    marks.push(
      markLine(rotatePts(qbez([cx, cy + s * 0.5], [cx - s * 0.25, cy + s * 0.85], [cx - s * 0.2, cy + s * 1.05], 6, rng, 0.002), cx, cy, angle), paint, 2.2, 0.9),
    )
    marks.push(
      markLine(rotatePts(qbez([cx, cy + s * 0.5], [cx + s * 0.3, cy + s * 0.8], [cx + s * 0.42, cy + s * 0.98], 6, rng, 0.002), cx, cy, angle), paint, 2.2, 0.9),
    )
    return marks
  }

  /** A comet with a tapering three-line tail. */
  function comet(rng, cx, cy, s, angle, colour) {
    var paint = colour || "rust"
    var marks = []
    marks.push(markLine(ellipsePts(cx, cy, s * 0.28, s * 0.28, rng, { end: Math.PI * 2 + 0.3, wobble: 0.05 }), paint, 2.2, 0.95))
    for (var i = 0; i < 3; i++) {
      var spread = (i - 1) * s * 0.3
      var tail = qbez(
        [cx - s * 0.2, cy + spread * 0.3],
        [cx - s * 1.2, cy + spread],
        [cx - s * (2 + i * 0.3), cy + spread * 1.6],
        10,
        rng,
        s * 0.02,
      )
      marks.push(markLine(rotatePts(tail, cx, cy, angle), paint, 2 - i * 0.3, 0.7))
    }
    return marks
  }

  /** A constellation: dashed lines between named stars, plus a tail if given. */
  function constellation(rng, pts, tailPts, colour) {
    var paint = colour || "paper"
    var marks = []
    marks.push(markDash(pts.concat([pts[0]]), paint, 1.6, 0.016, 0.014, 0.8))
    pts.forEach(function (p, index) {
      if (index % 2 === 0) marks.push(markSparkle(p[0], p[1], 0.008, paint))
      else marks.push(markDot(p[0], p[1], 0.004, paint))
    })
    if (tailPts) marks.push(markDash(tailPts, paint, 1.4, 0.014, 0.012, 0.7))
    return marks
  }

  /** A little flag on a pole. */
  function flagOnPole(rng, cx, cy, s, colour) {
    var paint = colour || "rust"
    var marks = []
    marks.push(markLine(squiggle([cx, cy], [cx, cy - s * 1.4], rng, 0.002, 0.4, 6), paint, 2, 0.9))
    var flag = [
      [cx, cy - s * 1.4],
      [cx + s * 0.75, cy - s * 1.2],
      [cx, cy - s * 1.0],
      [cx, cy - s * 1.4],
    ]
    marks.push(markFill(flag, paint, 0.8))
    marks.push(markLine(flag, paint, 1.8, 0.9))
    return marks
  }

  /** A little arched door, for places that clearly have an inside. */
  function doorway(rng, cx, baseY, w, h, colour) {
    var paint = colour || "ink"
    var marks = []
    var arch = qbez([cx - w, baseY], [cx - w, baseY - h * 1.5], [cx, baseY - h * 1.5], 8, rng, 0.002).concat(
      qbez([cx, baseY - h * 1.5], [cx + w, baseY - h * 1.5], [cx + w, baseY], 8, rng, 0.002).slice(1),
    )
    marks.push(markLine(arch, paint, 2.4, 0.95))
    marks.push(markLine(squiggle([cx - w * 0.55, baseY], [cx - w * 0.55, baseY - h * 1.1], rng, 0.002, 0.4, 5), paint, 1.5, 0.8))
    marks.push(markLine(squiggle([cx + w * 0.55, baseY], [cx + w * 0.55, baseY - h * 1.1], rng, 0.002, 0.4, 5), paint, 1.5, 0.8))
    marks.push(markDot(cx + w * 0.35, baseY - h * 0.5, w * 0.12, paint))
    marks.push(markLine(squiggle([cx - w * 1.3, baseY + h * 0.06], [cx + w * 1.3, baseY + h * 0.06], rng, 0.002, 0.4, 6), paint, 1.8, 0.85))
    return marks
  }

  /** A tent with a door flap and one guy line. Sizes are explicit x/y units. */
  function tentXY(rng, cx, baseY, hx, hy, colour) {
    var paint = colour || "paper"
    var outline = [
      [cx - hx, baseY],
      [cx, baseY - hy],
      [cx + hx, baseY],
      [cx - hx, baseY],
    ]
    var door = [
      [cx - hx * 0.05, baseY],
      [cx + hx * 0.2, baseY - hy * 0.5],
    ]
    var guy = squiggle([cx, baseY - hy], [cx + hx * 1.7, baseY], rng, 0.0015, 0.6, 8)
    return [markLine(outline, paint, 2.2, 0.95), markLine(door, paint, 1.8, 0.85), markLine(guy, paint, 1.4, 0.6)]
  }

  /** A campfire: two logs, one flame, two embers. Sizes are explicit x/y units. */
  function campfireXY(rng, cx, cy, hx, hy, colour) {
    var paint = colour || "paper"
    var marks = []
    marks.push(markLine(squiggle([cx - hx, cy + hy * 0.35], [cx + hx, cy + hy * 0.1], rng, 0.0015, 0.6, 6), paint, 2.2, 0.95))
    marks.push(markLine(squiggle([cx - hx * 0.85, cy], [cx + hx * 0.9, cy + hy * 0.4], rng, 0.0015, 0.6, 6), paint, 2.2, 0.95))
    marks.push(markLine(squiggle([cx, cy + hy * 0.12], [cx - hx * 0.1, cy - hy * 0.9], rng, 0.003, 1.4, 8), "rust", 2.2, 0.9))
    marks.push(markLine(squiggle([cx + hx * 0.18, cy + hy * 0.05], [cx + hx * 0.34, cy - hy * 0.7], rng, 0.003, 1.4, 8), "rust", 2, 0.85))
    marks.push(markDot(cx - hx * 0.35, cy - hy * 0.85, hy * 0.09, "rust"))
    marks.push(markDot(cx + hx * 0.55, cy - hy * 1.05, hy * 0.07, "rust"))
    return marks
  }

  /** A curl of smoke rising. Sizes are explicit x/y units. */
  function smokeCurlXY(rng, cx, cy, hx, hy, colour) {
    var paint = colour || "paper"
    var pts = []
    var steps = 24
    for (var i = 0; i <= steps; i++) {
      var t = i / steps
      pts.push([cx + Math.sin(t * Math.PI * 3.2) * hx * 0.4 * (1 - t * 0.5), cy - t * hy * 1.6])
    }
    var marks = [markLine(pts, paint, 1.8, 0.8)]
    marks.push(markLine(ellipsePts(cx + hx * 0.42, cy - hy * 1.62, hx * 0.22, hy * 0.16, rng, { end: Math.PI * 2, wobble: 0.06 }), paint, 1.5, 0.6))
    return marks
  }

  // ---------- recipes, one per photograph ----------

  var RECIPES = {
    storm: function (rng) {
      var marks = []
      // an extra bolt, drawn by someone who is trying their best
      marks = marks.concat(withMarks(lightning(rng, [0.43, 0.13], [0.455, 0.42], 0.02, "paper")))
      marks.push(markLabel("amateur hour", 0.535, 0.3, -4, 0.03, "rust"))
      // the two lighthouses keep working through it
      marks.push(markSparkle(0.588, 0.6, 0.013, "paper"))
      marks.push(markSparkle(0.163, 0.615, 0.012, "sky"))
      // the green one has opinions about the competition
      marks = marks.concat(withMarks(speechBubble(rng, 0.25, 0.42, 0.115, 0.062, 0.175, 0.6, "paper")))
      marks.push(markLabel("show-offs.", 0.25, 0.42, -3, 0.027, "navy"))
      // someone did not check the forecast
      marks = marks.concat(withMarks(umbrellaFigure(rng, 0.715, 0.79, 0.055, "paper")))
      ;[
        [0.66, 0.62],
        [0.68, 0.66],
        [0.7, 0.6],
        [0.73, 0.64],
        [0.75, 0.61],
        [0.76, 0.67],
        [0.665, 0.7],
      ].forEach(function (drop) {
        marks.push(markLine(squiggle(drop, [drop[0] - 0.004, drop[1] + 0.03], rng, 0.001, 0.3, 4), "sky", 1.5, 0.6))
      })
      // a fish, unbothered, with its own arrangements
      marks = marks.concat(withMarks(smallFish(rng, 0.13, 0.86, 0.04, -8, "sky")))
      marks = marks.concat(withMarks(umbrella(rng, 0.13, 0.775, 0.035, "sky")))
      marks.push(markLabel("dry down here", 0.24, 0.9, -4, 0.028, "sky"))
      // one gull out in it anyway
      marks.push(markLine(birdPts(0.83, 0.17, 0.02, rng), "paper", 2.2, 0.85))
      marks = marks.concat(withMarks(whoosh(rng, 0.875, 0.19, 0.03, 190, "paper")))
      marks.push(markLabel("the sky is arguing", 0.5, 0.065, -3, 0.034, "paper"))
      return marks
    },

    wave: function (rng) {
      var marks = []
      // an origami boat that heard about the other boats and came anyway
      marks = marks.concat(withMarks(origamiBoat(rng, 0.47, 0.135, 0.042, -10, "rust")))
      marks.push(markDash(qbez([0.3, 0.22], [0.38, 0.24], [0.45, 0.15], 14, rng, 0.004), "rust", 1.7, 0.02, 0.016, 0.7))
      // someone is having an excellent day on the face
      marks = marks.concat(withMarks(surfer(rng, 0.335, 0.47, 0.05, -22, "paper")))
      marks.push(markLabel("hang ten", 0.24, 0.33, -6, 0.03, "paper"))
      // gulls in the quiet corner of the sky
      ;[
        [0.72, 0.1],
        [0.8, 0.07],
        [0.88, 0.12],
      ].forEach(function (b) {
        marks.push(markLine(birdPts(b[0], b[1], 0.02, rng), "ink", 2.1, 0.85))
      })
      // Fuji, unbothered
      marks.push(markSparkle(0.625, 0.635, 0.011, "sky"))
      marks.push(markLabel("unbothered", 0.72, 0.6, -5, 0.03, "ink"))
      // a fish that saw it coming
      marks = marks.concat(withMarks(smallFish(rng, 0.77, 0.73, 0.04, -38, "paper")))
      marks.push(markDot(0.735, 0.775, 0.005, "paper"))
      marks.push(markDot(0.758, 0.792, 0.004, "paper"))
      // encouragement for the lowest boat
      marks.push(markLabel("hold on", 0.45, 0.955, -3, 0.03, "paper"))
      // a flag for the left boat
      marks = marks.concat(withMarks(flagOnPole(rng, 0.055, 0.53, 0.035, "rust")))
      // spray off the claw
      marks.push(markDot(0.5, 0.3, 0.005, "paper"))
      marks.push(markDot(0.545, 0.26, 0.004, "paper"))
      marks.push(markDot(0.575, 0.32, 0.0045, "paper"))
      return marks
    },

    fox: function (rng) {
      var marks = []
      // a butterfly wanders past the professional
      marks = marks.concat(withMarks(butterfly(rng, 0.3, 0.5, 0.028, -15, "rust")))
      var flight = qbez([0.08, 0.3], [0.22, 0.2], [0.2, 0.38], 12, rng, 0.004).concat(
        qbez([0.2, 0.38], [0.17, 0.52], [0.285, 0.485], 12, rng, 0.004).slice(1),
      )
      marks.push(markDash(flight, "rust", 1.6, 0.018, 0.015, 0.7))
      // the professional's only question
      marks = marks.concat(withMarks(speechBubble(rng, 0.16, 0.14, 0.125, 0.062, 0.44, 0.42, "paper")))
      marks.push(markLabel("was that a snack?", 0.16, 0.14, -3, 0.024, "navy"))
      // a mouse with a secret
      marks = marks.concat(withMarks(mouse(rng, 0.07, 0.875, 0.024, "ink")))
      marks = marks.concat(withMarks(speechBubble(rng, 0.185, 0.775, 0.09, 0.045, 0.095, 0.855, "paper")))
      marks.push(markLabel("he can't see me", 0.185, 0.775, -3, 0.02, "navy"))
      // evidence of earlier business
      marks = marks.concat(withMarks(pawPrints(rng, [0.15, 0.965], [0.36, 0.9], 4, "rust")))
      // credit where credit is due
      marks.push(markLabel("professional listener", 0.19, 0.06, -4, 0.028, "paper"))
      marks.push(markLine(squiggle([0.3, 0.062], [0.385, 0.095], rng, 0.005, 0.8, 10), "paper", 1.6, 0.8))
      // the left whiskers, exaggerated for emphasis
      marks = marks.concat(withMarks(whiskerFan(rng, 0.365, 0.6, 0.07, -1, "rust")))
      return marks
    },

    puffin: function (rng) {
      var marks = []
      // the one that got away
      marks = marks.concat(withMarks(smallFish(rng, 0.335, 0.64, 0.038, -125, "rust")))
      marks = marks.concat(withMarks(whoosh(rng, 0.385, 0.6, 0.025, -125, "rust")))
      marks = marks.concat(withMarks(speechBubble(rng, 0.165, 0.62, 0.095, 0.05, 0.32, 0.65, "paper")))
      marks.push(markLabel("tell my story", 0.165, 0.62, -3, 0.022, "navy"))
      // the puffin's announcement
      marks = marks.concat(withMarks(speechBubble(rng, 0.74, 0.13, 0.125, 0.06, 0.52, 0.44, "paper")))
      marks.push(markLabel("got the groceries", 0.74, 0.13, -3, 0.024, "white"))
      // pre-landing checklist
      marks.push(markLabel("landing gear: down", 0.77, 0.87, -4, 0.026, "ink"))
      marks.push(markLine(squiggle([0.72, 0.855], [0.635, 0.77], rng, 0.005, 0.8, 10), "ink", 1.6, 0.8))
      // wingtip weather
      marks = marks.concat(withMarks(whoosh(rng, 0.08, 0.3, 0.035, 205, "ink")))
      // the victory lap
      marks.push(markDash(qbez([0.82, 0.4], [0.95, 0.32], [0.9, 0.2], 12, rng, 0.004), "rust", 1.6, 0.018, 0.015, 0.65))
      marks.push(markLine(ellipsePts(0.885, 0.185, 0.02, 0.014, rng, { end: Math.PI * 2 + 0.3, wobble: 0.05 }), "rust", 1.6, 0.65))
      // a fan on the rocks
      marks = marks.concat(withMarks(smallFish(rng, 0.1, 0.875, 0.03, -18, "ink")))
      marks.push(markLabel("go go go", 0.17, 0.845, -5, 0.022, "ink"))
      return marks
    },

    tornado: function (rng) {
      var marks = []
      // doodled smoke rings joining the real steam
      marks.push(markLine(ellipsePts(0.31, 0.15, 0.02, 0.014, rng, { end: Math.PI * 2 + 0.4, wobble: 0.08 }), "ink", 2, 0.85))
      marks.push(markLine(ellipsePts(0.355, 0.095, 0.028, 0.019, rng, { end: Math.PI * 2 + 0.4, wobble: 0.08 }), "ink", 2, 0.85))
      marks.push(markLine(ellipsePts(0.415, 0.045, 0.036, 0.024, rng, { end: Math.PI * 2 + 0.5, wobble: 0.08 }), "ink", 2, 0.85))
      marks.push(markLabel("choo", 0.415, 0.045, -3, 0.024, "rust"))
      // birds, keeping a respectful distance
      ;[
        [0.62, 0.1],
        [0.7, 0.07],
        [0.78, 0.12],
      ].forEach(function (b) {
        marks.push(markLine(birdPts(b[0], b[1], 0.02, rng), "ink", 2.1, 0.85))
      })
      // one on the signal, closer than strictly advised
      marks.push(markLine(birdPts(0.148, 0.1, 0.013, rng), "rust", 2, 0.9))
      // riding shotgun
      marks = marks.concat(withMarks(sittingCat(rng, 0.17, 0.875, 0.034, "paper")))
      marks.push(markLabel("riding shotgun", 0.13, 0.955, -3, 0.026, "paper"))
      // the man trusts her
      marks = marks.concat(withMarks(speechBubble(rng, 0.9, 0.57, 0.1, 0.052, 0.815, 0.7, "paper")))
      marks.push(markLabel("she purrs, mostly", 0.9, 0.57, -3, 0.022, "navy"))
      return marks
    },

    aurora: function (rng) {
      var marks = []
      // a camp on the snowy slope, watching the sky work
      marks = marks.concat(withMarks(tentXY(rng, 0.865, 0.79, 0.013, 0.05, "paper")))
      marks = marks.concat(withMarks(campfireXY(rng, 0.887, 0.8, 0.006, 0.02, "paper")))
      marks = marks.concat(withMarks(smokeCurlXY(rng, 0.887, 0.775, 0.004, 0.03, "paper")))
      // footprints leading over
      marks.push(markDash(qbez([0.79, 0.97], [0.83, 0.9], [0.862, 0.82], 14, rng, 0.002), "paper", 1.8, 0.012, 0.014, 0.7))
      // the sky, mid-project
      marks.push(markLabel("the sky is knitting", 0.17, 0.09, -2, 0.045, "paper"))
      marks.push(markLabel("shhh \u2014 it's working", 0.63, 0.06, -2, 0.04, "paper"))
      // an old friend overhead
      var dipper = [
        [0.035, 0.05],
        [0.055, 0.075],
        [0.075, 0.09],
        [0.095, 0.085],
        [0.11, 0.11],
        [0.13, 0.1],
        [0.125, 0.075],
      ]
      marks.push(markDash(dipper, "sky", 1.6, 0.01, 0.012, 0.75))
      dipper.forEach(function (p, index) {
        if (index % 2 === 0) marks.push(markSparkle(p[0], p[1], 0.007, "sky"))
        else marks.push(markDot(p[0], p[1], 0.0035, "sky"))
      })
      marks.push(markLabel("a bear, apparently", 0.095, 0.16, -3, 0.038, "sky"))
      // one for the road
      marks.push(markDash([[0.9, 0.03], [0.84, 0.1]], "paper", 1.8, 0.014, 0.012, 0.7))
      marks.push(markSparkle(0.84, 0.1, 0.009, "paper"))
      // the local wildlife, also watching
      marks = marks.concat(withMarks(reindeer(rng, 0.06, 0.86, 0.014, 0.055, "paper")))
      marks = marks.concat(withMarks(owl(rng, 0.79, 0.52, 0.006, 0.022, "paper")))
      // a boat with a lantern, out late on purpose
      marks.push(
        markLine(ellipsePts(0.4, 0.62, 0.012, 0.018, rng, { start: Math.PI * 0.1, end: Math.PI * 0.9, wobble: 0.03 }), "paper", 2.2, 0.95),
      )
      marks.push(markLine([[0.4, 0.618], [0.4, 0.588]], "paper", 1.8, 0.9))
      marks.push(markDot(0.4, 0.605, 0.0035, "rust"))
      marks.push(markSparkle(0.4, 0.605, 0.007, "rust"))
      marks.push(markDash([[0.385, 0.625], [0.36, 0.632]], "paper", 1.4, 0.01, 0.01, 0.6))
      // snow and water, keeping time
      marks.push(markSparkle(0.87, 0.86, 0.008, "sky"))
      marks.push(markSparkle(0.5, 0.66, 0.008, "paper"))
      return marks
    },

    cellarius: function (rng) {
      var marks = []
      // the sun knows
      marks = marks.concat(withMarks(sunglasses(rng, 0.5, 0.505, 0.05, "ink")))
      marks.push(markLabel("center of it all", 0.635, 0.565, -4, 0.028, "rust"))
      // a rocket, doing laps
      marks = marks.concat(withMarks(rocket(rng, 0.71, 0.42, 0.038, 40, "rust")))
      marks.push(
        markDash(ellipsePts(0.5, 0.51, 0.23, 0.2, rng, { start: -0.6, end: 1.4, wobble: 0.01 }), "ink", 1.6, 0.018, 0.015, 0.55),
      )
      // the small blue one
      marks.push(markLabel("you are here", 0.63, 0.27, -5, 0.026, "rust"))
      marks.push(markLine(squiggle([0.6, 0.285], [0.525, 0.34], rng, 0.004, 0.8, 10), "rust", 1.6, 0.85))
      marks.push(markDot(0.515, 0.348, 0.005, "rust"))
      // a constellation the engraver missed
      marks = marks.concat(
        withMarks(
          constellation(
            rng,
            [
              [0.68, 0.22],
              [0.71, 0.2],
              [0.74, 0.22],
              [0.76, 0.26],
              [0.75, 0.3],
              [0.71, 0.31],
              [0.68, 0.29],
            ],
            [
              [0.68, 0.29],
              [0.65, 0.27],
              [0.64, 0.23],
            ],
            "paper",
          ),
        ),
      )
      marks.push(markLabel("felis major", 0.72, 0.355, -4, 0.024, "paper"))
      // just passing
      marks = marks.concat(withMarks(comet(rng, 0.2, 0.5, 0.03, -25, "rust")))
      marks.push(markLabel("just passing", 0.2, 0.575, -4, 0.024, "rust"))
      // the two gentlemen have notes
      marks = marks.concat(withMarks(speechBubble(rng, 0.2, 0.62, 0.09, 0.05, 0.14, 0.71, "paper")))
      marks.push(markLabel("I have notes.", 0.2, 0.62, -3, 0.022, "navy"))
      marks = marks.concat(withMarks(speechBubble(rng, 0.79, 0.6, 0.085, 0.048, 0.86, 0.7, "paper")))
      marks.push(markLabel("trust me.", 0.79, 0.6, -3, 0.022, "navy"))
      // and one small visitor, very far from the ship
      marks = marks.concat(withMarks(astronaut(rng, 0.56, 0.78, 0.028, -15, "paper")))
      marks.push(markDash(qbez([0.56, 0.81], [0.53, 0.85], [0.5, 0.83], 8, rng, 0.002), "paper", 1.4, 0.012, 0.01, 0.7))
      return marks
    },

    balloon: function (rng) {
      var marks = []
      // the yellow crown is clearly a door
      marks = marks.concat(withMarks(doorway(rng, 0.5, 0.585, 0.028, 0.045, "ink")))
      marks.push(markLabel("the sun's front door", 0.635, 0.47, -4, 0.026, "ink"))
      // someone took a wrong turn
      marks = marks.concat(withMarks(spider(rng, 0.46, 0.49, 0.012, [0.46, 0.44], "ink")))
      marks.push(markLabel("wrong turn", 0.395, 0.44, -5, 0.02, "ink"))
      // the silhouette is obviously conducting
      marks = marks.concat(withMarks(musicNote(rng, 0.6, 0.68, 0.02, "paper")))
      marks = marks.concat(withMarks(musicNote(rng, 0.635, 0.615, 0.017, "paper")))
      marks = marks.concat(withMarks(musicNote(rng, 0.53, 0.65, 0.018, "paper")))
      marks.push(markLabel("the conductor", 0.57, 0.855, -3, 0.028, "paper"))
      // a visitor, wondering how it got in
      marks.push(markLine(birdPts(0.22, 0.22, 0.02, rng), "paper", 2.1, 0.85))
      marks.push(markDash(qbez([0.15, 0.28], [0.19, 0.3], [0.215, 0.235], 10, rng, 0.003), "paper", 1.5, 0.016, 0.014, 0.65))
      marks.push(markLabel("a visitor", 0.28, 0.17, -4, 0.024, "paper"))
      // the slowest passenger
      marks = marks.concat(withMarks(snail(rng, 0.3, 0.915, 0.022, "paper")))
      // where we are
      marks.push(markLabel("inside a rainbow", 0.5, 0.06, -2, 0.034, "ink"))
      marks.push(markSparkle(0.5, 0.53, 0.01, "paper"))
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
      if (mark.kind === "line" || mark.kind === "fill") {
        length = pathLength(mark.pts)
      } else if (mark.kind === "dashline") {
        mark.dashes = dashPath(mark.pts, mark.dash, mark.gap)
        mark.dashLengths = mark.dashes.map(pathLength)
        length = pathLength(mark.pts)
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
    var maxTotal = 6800
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

  function drawMark(ctx, mark, progress, width, height, dim, scale, colours, twinkleNow) {
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

    if (mark.kind === "dashline") {
      var easedDash = progress * progress * (3 - 2 * progress)
      var target = mark.length * easedDash
      ctx.globalAlpha = mark.alpha == null ? 0.85 : mark.alpha
      ctx.lineWidth = Math.max(0.6, mark.width * scale)
      var spent = 0
      for (var i = 0; i < mark.dashes.length; i++) {
        var dlen = mark.dashLengths[i]
        if (spent + dlen <= target) {
          tracePath(ctx, mark.dashes[i], width, height)
          ctx.stroke()
        } else {
          if (target > spent) {
            var partialDash = slicePath(mark.dashes[i], target - spent)
            if (partialDash.length > 1) {
              tracePath(ctx, partialDash, width, height)
              ctx.stroke()
            }
          }
          break
        }
        spent += dlen
      }
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
      var tw = 1
      var reachScale = 1
      if (twinkleNow != null) {
        var phase = twinkleNow / 420 + mark.x * 31 + mark.y * 47
        tw = 0.62 + 0.38 * Math.sin(phase)
        reachScale = 0.85 + 0.3 * Math.sin(phase + 1.3)
      }
      ctx.globalAlpha = progress * 0.9 * tw
      ctx.lineWidth = Math.max(0.6, 1.6 * scale)
      var reach = mark.r * dim * progress * reachScale
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

  function drawScene(ctx, scene, time, width, height, scale, colours, clear, twinkleNow) {
    if (clear !== false) ctx.clearRect(0, 0, width, height)
    var dim = Math.min(width, height)
    ctx.lineCap = "round"
    ctx.lineJoin = "round"
    scene.marks.forEach(function (mark) {
      var progress = time == null ? 1 : clamp01((time - mark.start) / mark.dur)
      if (progress <= 0) return
      drawMark(ctx, mark, progress, width, height, dim, scale, colours, twinkleNow)
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

  function drawView(view, time, twinkleNow) {
    var ctx = view.ink.getContext("2d")
    ctx.setTransform(view.dpr, 0, 0, view.dpr, 0, 0)
    drawScene(ctx, view.state.scene, time, view.w, view.h, 1, view.state.colours, true, twinkleNow)
  }

  function drawState(state, time, twinkleNow) {
    state.views.forEach(function (view) {
      drawView(view, time, twinkleNow)
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

  // ---------- animation, and the small matter of staying awake ----------

  function startIdle(state) {
    if (motionQuery.matches || state.idleTimer || !state.scene.finished) return
    var tick = function () {
      state.idleTimer = 0
      if (document.hidden || state.inView === false) return
      drawState(state, null, performance.now())
      state.idleTimer = window.setTimeout(tick, IDLE_MS)
    }
    state.idleTimer = window.setTimeout(tick, IDLE_MS)
  }

  function stopIdle(state) {
    if (state.idleTimer) {
      window.clearTimeout(state.idleTimer)
      state.idleTimer = 0
    }
  }

  function animate(state) {
    state.scene.started = true
    stopIdle(state)
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
        startIdle(state)
      }
    }
    state.raf = requestAnimationFrame(step)
  }

  function redoodle(state) {
    stopIdle(state)
    var seed = ((Math.random() * 4294967295) >>> 0) || 7
    state.seed = seed
    state.piece.setAttribute("data-kt-seed", String(seed))
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
      var draw = rootEl.querySelector("[data-kt-draw]")
      if (draw) {
        draw.setAttribute("aria-pressed", state.drawMode ? "true" : "false")
        draw.textContent = state.drawMode ? "done drawing" : "draw on it"
      }
      var clear = rootEl.querySelector("[data-kt-clear]")
      if (clear) clear.hidden = !state.drawMode || !hasStrokes
      var save = rootEl.querySelector("[data-kt-save]")
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
        link.download = "kimi-thoughts-" + state.id + ".jpg"
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
    dialog.setAttribute("data-kt-focus", "true")
    dialog.setAttribute("aria-labelledby", "kt-focus-title")
    dialog.innerHTML = [
      '<div class="ds-focus-sheet">',
      '<header class="ds-focus-head">',
      '<div class="ds-focus-meta">',
      '<h3 class="ds-focus-title" id="kt-focus-title"></h3>',
      '<p class="ds-focus-credit"><a target="_blank" rel="noopener noreferrer"></a></p>',
      "</div>",
      '<button type="button" class="ds-action ds-focus-close" data-kt-focus-close="true" aria-label="Close the focus view">close</button>',
      "</header>",
      '<div class="ds-focus-wrap">',
      '<div class="ds-focus-stage">',
      '<img class="ds-photo ds-focus-photo" src="data:image/gif;base64,R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs=" alt="" decoding="async">',
      '<canvas class="ds-ink ds-focus-ink" aria-hidden="true"></canvas>',
      '<canvas class="ds-pad ds-focus-pad" aria-hidden="true"></canvas>',
      "</div>",
      "</div>",
      '<div class="ds-tools ds-focus-tools">',
      '<button type="button" class="ds-action" data-kt-redoodle="true">doodle again</button>',
      '<button type="button" class="ds-action" data-kt-draw="true" aria-pressed="false">draw on it</button>',
      '<button type="button" class="ds-action ds-action-quiet" data-kt-clear="true" hidden>clear my marks</button>',
      '<button type="button" class="ds-action ds-action-quiet" data-kt-save="true" hidden>save a copy</button>',
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
    var titleEl = focusDialog.querySelector("#kt-focus-title")
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
    var closeButton = focusDialog.querySelector("[data-kt-focus-close]")
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
    if (button.hasAttribute("data-kt-redoodle-all")) {
      states.forEach(function (state) {
        redoodle(state)
      })
      return
    }
    if (button.hasAttribute("data-kt-toggle-doodles")) {
      var hidden = root.classList.toggle("ds-hide-ink")
      button.setAttribute("aria-pressed", hidden ? "true" : "false")
      button.textContent = hidden ? "show the doodles" : "hide the doodles"
      return
    }
    if (button.hasAttribute("data-kt-focus-close")) {
      closeFocus()
      return
    }
    var state = null
    var piece = button.closest("[data-kt-piece]")
    if (piece) {
      state = byPiece.get(piece)
    } else if (button.closest("[data-kt-focus]")) {
      state = focusState
    }
    if (!state) return
    if (button.hasAttribute("data-kt-open")) {
      openFocus(state)
    } else if (button.hasAttribute("data-kt-redoodle")) {
      redoodle(state)
    } else if (button.hasAttribute("data-kt-draw")) {
      setDrawMode(state, !state.drawMode)
    } else if (button.hasAttribute("data-kt-clear")) {
      state.strokes = []
      redrawAllPads(state)
      refreshPad(state)
    } else if (button.hasAttribute("data-kt-save")) {
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
        if (!state) return
        if (entry.isIntersecting) {
          state.inView = true
          if (!state.scene.started) animate(state)
          else startIdle(state)
        } else {
          state.inView = false
          stopIdle(state)
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

  var onVisibility = function () {
    if (document.hidden) {
      states.forEach(stopIdle)
    } else {
      states.forEach(function (state) {
        if (state.inView !== false) startIdle(state)
      })
    }
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
      id: pieceEl.getAttribute("data-kt-piece"),
      piece: pieceEl,
      stage: stage,
      ink: ink,
      pad: pad,
      photo: photo,
      seed: Number(pieceEl.getAttribute("data-kt-seed")) || 7,
      colours: palette(),
      scene: null,
      raf: 0,
      idleTimer: 0,
      inView: false,
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
  document.addEventListener("visibilitychange", onVisibility)

  var onKeyDown = function (event) {
    if (event.key !== "Escape") return
    if (focusDialog && focusDialog.open) closeFocus()
  }
  document.addEventListener("keydown", onKeyDown)

  var motionListener = function () {
    if (!motionQuery.matches) return
    states.forEach(function (state) {
      stopIdle(state)
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
        stopIdle(state)
      })
      if (focusDialog && focusDialog.open) focusDialog.close()
      sizeObserver.disconnect()
      observer.disconnect()
      themeObserver.disconnect()
      root.removeEventListener("click", onClick)
      document.removeEventListener("keydown", onKeyDown)
      document.removeEventListener("visibilitychange", onVisibility)
      window.removeEventListener("resize", onWindowResize)
      if (typeof motionQuery.removeEventListener === "function")
        motionQuery.removeEventListener("change", motionListener)
      root.removeAttribute("data-kt-ready")
    })
}

document.addEventListener("nav", setupKimiThoughts)
`

// src/components/index.ts
var ARTWORKS = [
  {
    id: "storm",
    src: "/static/kimi-thoughts/storm-lighthouse.jpg",
    width: 1920,
    height: 1080,
    alt: "Lightning forking through a purple night sky over the harbour at Port-la-Nouvelle, two small lighthouses glowing green and gold at the end of a long pier.",
    title: "Argument night",
    credit: "Maxime Raynal \xB7 CC BY 2.0",
    creditUrl:
      "https://commons.wikimedia.org/wiki/File:Port_and_lighthouse_overnight_storm_with_lightning_in_Port-la-Nouvelle.jpg",
    seed: 20141128,
    wide: true,
  },
  {
    id: "wave",
    src: "/static/kimi-thoughts/great-wave.jpg",
    width: 1920,
    height: 1314,
    alt: "Hokusai's Great Wave off Kanagawa: a huge cresting wave with foam claws looming over three wooden boats, Mount Fuji small in the distance.",
    title: "Hold on",
    credit: "After Hokusai, c. 1831 \xB7 public domain",
    creditUrl: "https://commons.wikimedia.org/wiki/File:Great_Wave_off_Kanagawa2.jpg",
    seed: 1831,
  },
  {
    id: "fox",
    src: "/static/kimi-thoughts/red-fox.jpg",
    width: 1920,
    height: 1280,
    alt: "Portrait of a red fox in soft light, ears up, gazing into the distance with a thoroughly professional expression.",
    title: "Professional listener",
    credit: "Chuck Homler / Focus On Wildlife \xB7 CC BY-SA 4.0",
    creditUrl: "https://commons.wikimedia.org/wiki/File:Red_Fox_Portrait.jpg",
    seed: 20150125,
  },
  {
    id: "puffin",
    src: "/static/kimi-thoughts/puffin-fish.jpg",
    width: 1920,
    height: 1280,
    alt: "An Atlantic puffin coming in to land with wings spread and bright orange feet down, beak full of silver fish.",
    title: "Got the groceries",
    credit: "Giles Laurent \xB7 CC BY-SA 4.0",
    creditUrl:
      "https://commons.wikimedia.org/wiki/File:027_Atlantic_puffin_in_flight_with_mouth_full_of_fishes_Photo_by_Giles_Laurent.jpg",
    seed: 20240417,
  },
  {
    id: "tornado",
    src: "/static/kimi-thoughts/tornado-steam.jpg",
    width: 1920,
    height: 1280,
    alt: "Peppercorn A1 steam locomotive 60163 Tornado in dark blue, steam drifting from its chimney, standing at a heritage railway platform.",
    title: "She purrs, mostly",
    credit: "Alan Wilson \xB7 CC BY-SA 2.0",
    creditUrl: "https://commons.wikimedia.org/wiki/File:LNER_A1_4-6-2_No_60163_%27Tornado%27.jpg",
    seed: 20131109,
  },
  {
    id: "aurora",
    src: "/static/kimi-thoughts/aurora-storfjorden.jpg",
    width: 3840,
    height: 1056,
    alt: "A wide winter panorama over Storfjorden in Norway: northern lights rippling above snowy mountains, village lights reflected in the still fjord.",
    title: "The sky is knitting",
    credit: "Simo R\xE4s\xE4nen (Ximonic) \xB7 CC BY-SA 3.0",
    creditUrl:
      "https://commons.wikimedia.org/wiki/File:Aurora_borealis_above_Storfjorden_and_the_Lyngen_Alps_in_moonlight,_2012_March.jpg",
    seed: 20120304,
    wide: true,
  },
  {
    id: "cellarius",
    src: "/static/kimi-thoughts/cellarius-copernicanum.jpg",
    width: 1600,
    height: 1381,
    alt: "Andreas Cellarius's 1660 hand-coloured chart of the Copernican system: the sun at the centre, planet rings and a zodiac band sweeping in a grand arc above two astronomers.",
    title: "Center of it all",
    credit: "Andreas Cellarius, Harmonia Macrocosmica, 1660 \xB7 public domain",
    creditUrl:
      "https://commons.wikimedia.org/wiki/File:Cellarius_Harmonia_Macrocosmica_-_Planisphaerium_Copernicanum.jpg",
    seed: 1660,
  },
  {
    id: "balloon",
    src: "/static/kimi-thoughts/cappadocia-balloon.jpg",
    width: 1920,
    height: 1280,
    alt: "Inside a hot air balloon being inflated in Cappadocia: concentric rings of rainbow fabric rising to a glowing yellow crown, a person silhouetted at the centre holding the lines.",
    title: "The conductor",
    credit: "Benh LIEU SONG \xB7 CC BY-SA 3.0",
    creditUrl:
      "https://commons.wikimedia.org/wiki/File:Cappadocia_Balloon_Inflating_Wikimedia_Commons.JPG",
    seed: 20100618,
  },
]
var KimiThoughts = () => {
  const KimiThoughtsComponent = ({ fileData }) => {
    if (fileData.slug !== "model-sketchbooks/kimi") return null
    return h(
      "section",
      {
        class: "deepseek-lab kimi-lab",
        "data-kt-lab": "true",
        "aria-labelledby": "kimi-lab-title",
      },
      [
        h("div", { class: "ds-lab-head" }, [
          h("div", { class: "ds-lab-lede" }, [
            h("h2", { id: "kimi-lab-title" }, "The sketchbook, vol. II"),
            h(
              "p",
              null,
              "Every mark below was drawn in your browser with the Canvas 2D API \u2014 no pixels painted in advance, and the sparkles keep twinkling once the ink dries. Tap a picture to open it big, reseed the ink, or pick up the pencil and add your own.",
            ),
          ]),
          h("div", { class: "ds-lab-actions" }, [
            h(
              "button",
              {
                type: "button",
                class: "ds-action ds-action-strong",
                "data-kt-redoodle-all": "true",
              },
              "doodle them all again",
            ),
            h(
              "button",
              {
                type: "button",
                class: "ds-action",
                "data-kt-toggle-doodles": "true",
                "aria-pressed": "false",
              },
              "hide the doodles",
            ),
          ]),
        ]),
        h(
          "ol",
          { class: "ds-grid" },
          ARTWORKS.map((artwork) =>
            h(
              "li",
              {
                key: artwork.id,
                class: "ds-piece" + (artwork.wide ? " ds-piece-wide" : ""),
              },
              h(
                "figure",
                {
                  class: "ds-frame",
                  "data-kt-piece": artwork.id,
                  "data-kt-seed": String(artwork.seed),
                },
                h("div", { class: "ds-stage" }, [
                  h("img", {
                    class: "ds-photo",
                    src: artwork.src,
                    alt: artwork.alt,
                    width: artwork.width,
                    height: artwork.height,
                    loading: "lazy",
                    decoding: "async",
                  }),
                  h(
                    "button",
                    {
                      type: "button",
                      class: "ds-open",
                      "data-kt-open": "true",
                      "aria-label": `Open ${artwork.title} in the focus view`,
                    },
                    h("span", { class: "ds-open-mark", "aria-hidden": "true" }, "\u2922"),
                  ),
                  h("canvas", { class: "ds-ink", "aria-hidden": "true" }),
                  h("canvas", {
                    class: "ds-pad",
                    "data-kt-pad": "true",
                    "aria-hidden": "true",
                    hidden: true,
                  }),
                ]),
                h("figcaption", { class: "ds-caption" }, [
                  h("span", { class: "ds-title" }, artwork.title),
                  h(
                    "a",
                    {
                      class: "ds-credit",
                      href: artwork.creditUrl,
                      target: "_blank",
                      rel: "noopener noreferrer",
                    },
                    artwork.credit,
                  ),
                ]),
                h("div", { class: "ds-tools" }, [
                  h(
                    "button",
                    { type: "button", class: "ds-action", "data-kt-redoodle": "true" },
                    "doodle again",
                  ),
                  h(
                    "button",
                    {
                      type: "button",
                      class: "ds-action",
                      "data-kt-draw": "true",
                      "aria-pressed": "false",
                    },
                    "draw on it",
                  ),
                  h(
                    "button",
                    {
                      type: "button",
                      class: "ds-action ds-action-quiet",
                      "data-kt-clear": "true",
                      hidden: true,
                    },
                    "clear my marks",
                  ),
                  h(
                    "button",
                    {
                      type: "button",
                      class: "ds-action ds-action-quiet",
                      "data-kt-save": "true",
                      hidden: true,
                    },
                    "save a copy",
                  ),
                ]),
              ),
            ),
          ),
        ),
        h("p", { class: "ds-footnote" }, [
          "Pictures: Maxime Raynal, ",
          h(
            "a",
            {
              href: "https://creativecommons.org/licenses/by/2.0/",
              target: "_blank",
              rel: "noopener noreferrer",
            },
            "CC BY 2.0",
          ),
          " (the storm); after Hokusai, c. 1831 (public domain); Chuck Homler / Focus On Wildlife and Giles Laurent, ",
          h(
            "a",
            {
              href: "https://creativecommons.org/licenses/by-sa/4.0/",
              target: "_blank",
              rel: "noopener noreferrer",
            },
            "CC BY-SA 4.0",
          ),
          " (the fox and the puffin); Alan Wilson, ",
          h(
            "a",
            {
              href: "https://creativecommons.org/licenses/by-sa/2.0/",
              target: "_blank",
              rel: "noopener noreferrer",
            },
            "CC BY-SA 2.0",
          ),
          " (Tornado); Simo R\xE4s\xE4nen (Ximonic) and Benh LIEU SONG, ",
          h(
            "a",
            {
              href: "https://creativecommons.org/licenses/by-sa/3.0/",
              target: "_blank",
              rel: "noopener noreferrer",
            },
            "CC BY-SA 3.0",
          ),
          " (the aurora and the balloon); Andreas Cellarius, ",
          h("i", null, "Harmonia Macrocosmica"),
          ", 1660 (public domain). Doodles live on a separate canvas and never touch the originals.",
        ]),
      ],
    )
  }
  KimiThoughtsComponent.displayName = "Kimi Thoughts"
  KimiThoughtsComponent.afterDOMLoaded = DOODLE_SCRIPT
  return KimiThoughtsComponent
}
var index_default = KimiThoughts
export { KimiThoughts, index_default as default }
