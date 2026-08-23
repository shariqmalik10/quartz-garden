type GardenTrailCell = {
  column: number
  row: number
  energy: number
  born: number
}

type Vec3 = { x: number; y: number; z: number }

type OrbParticle = {
  direction: Vec3
  alive: boolean
  tone: 0 | 1 | 2
  jitter: number
  size: number
}

type OrbHole = {
  centre: Vec3
  radius: number
  cosRadius: number
}

type OrbTrailPoint = {
  position: Vec3
  energy: number
}

type OrbCrawler = {
  direction: Vec3
  heading: Vec3
}

type OrbDust = {
  sx: number
  sy: number
  vx: number
  vy: number
  energy: number
  tone: 0 | 1
}

function gardenColour(name: string, fallback: string) {
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim() || fallback
}

function normaliseVec(vector: Vec3): Vec3 {
  const length = Math.hypot(vector.x, vector.y, vector.z) || 1
  return { x: vector.x / length, y: vector.y / length, z: vector.z / length }
}

function crossVec(a: Vec3, b: Vec3): Vec3 {
  return {
    x: a.y * b.z - a.z * b.y,
    y: a.z * b.x - a.x * b.z,
    z: a.x * b.y - a.y * b.x,
  }
}

function tangentBasis(direction: Vec3): [Vec3, Vec3] {
  const reference: Vec3 = Math.abs(direction.y) < 0.92 ? { x: 0, y: 1, z: 0 } : { x: 1, y: 0, z: 0 }
  const across = normaliseVec(crossVec(reference, direction))
  return [across, normaliseVec(crossVec(direction, across))]
}

function randomDirection(): Vec3 {
  const theta = Math.random() * Math.PI * 2
  const elevation = Math.acos(2 * Math.random() - 1)
  const span = Math.sin(elevation)
  return { x: Math.cos(theta) * span, y: Math.cos(elevation), z: Math.sin(theta) * span }
}

function rotateTowards(direction: Vec3, heading: Vec3, angle: number): Vec3 {
  const cos = Math.cos(angle)
  const sin = Math.sin(angle)
  return normaliseVec({
    x: direction.x * cos + heading.x * sin,
    y: direction.y * cos + heading.y * sin,
    z: direction.z * cos + heading.z * sin,
  })
}

function setupGardenMotion() {
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)")
  const field = document.createElement("canvas")
  field.className = "garden-pixel-field"
  field.setAttribute("aria-hidden", "true")
  document.body.prepend(field)

  const fieldContext = field.getContext("2d", { alpha: true })
  const trail = new Map<string, GardenTrailCell>()
  const brightTrail: string[] = []
  const cellSize = 28
  let fieldFrame = 0
  let fieldWidth = 0
  let fieldHeight = 0
  let lastFieldTime = 0
  let fieldVisible = !document.hidden

  const resizeField = () => {
    fieldWidth = window.innerWidth
    fieldHeight = window.innerHeight
    field.width = Math.max(1, fieldWidth)
    field.height = Math.max(1, fieldHeight)
  }

  const addTrailCell = (event: PointerEvent) => {
    if (event.pointerType === "touch") return
    const column = Math.floor(event.clientX / cellSize)
    const row = Math.floor(event.clientY / cellSize)
    const key = `${column}:${row}`
    const existing = trail.get(key)
    if (existing) {
      existing.born = performance.now()
      existing.energy = Math.max(existing.energy, 0.7)
    } else {
      trail.set(key, { column, row, energy: 0, born: performance.now() })
    }

    const previousIndex = brightTrail.indexOf(key)
    if (previousIndex >= 0) brightTrail.splice(previousIndex, 1)
    brightTrail.push(key)
    while (brightTrail.length > 5) brightTrail.shift()
  }

  const drawField = (time: number) => {
    if (!fieldContext || !fieldVisible) return
    if (time - lastFieldTime < 32 && !reducedMotion.matches) {
      fieldFrame = requestAnimationFrame(drawField)
      return
    }

    const delta = Math.min(50, time - lastFieldTime || 16)
    lastFieldTime = time
    fieldContext.clearRect(0, 0, fieldWidth, fieldHeight)
    const ink = gardenColour("--garden-ink", "#172b4d")
    const rust = gardenColour("--garden-rust", "#bd5438")
    const columns = Math.ceil(fieldWidth / cellSize)
    const rows = Math.ceil(fieldHeight / cellSize)

    fieldContext.globalAlpha = 0.025
    fieldContext.fillStyle = ink
    for (let row = 0; row < rows; row += 1) {
      for (let column = 0; column < columns; column += 1) {
        const offset = ((column * 17 + row * 29) % 5) * 0.35
        fieldContext.fillRect(
          column * cellSize + 2 + offset,
          row * cellSize + 2 + offset,
          cellSize - 5,
          cellSize - 5,
        )
      }
    }

    const brightSet = new Set(brightTrail)
    for (const [key, item] of trail) {
      const stillBright = brightSet.has(key) && time - item.born < 150
      const target = stillBright ? 1 : 0
      const speed = target > item.energy ? 0.22 : Math.min(0.11, delta * 0.0016)
      item.energy += (target - item.energy) * speed
      if (target === 0) item.energy = Math.max(0, item.energy - delta * 0.00065)

      if (item.energy < 0.012 && !stillBright) {
        trail.delete(key)
        continue
      }

      fieldContext.globalAlpha = 0.03 + item.energy * 0.13
      fieldContext.fillStyle = rust
      fieldContext.fillRect(
        item.column * cellSize + 2,
        item.row * cellSize + 2,
        cellSize - 5,
        cellSize - 5,
      )
    }

    fieldContext.globalAlpha = 1
    if (!reducedMotion.matches) fieldFrame = requestAnimationFrame(drawField)
  }

  const windowCanvas = document.querySelector<HTMLCanvasElement>(".garden-flower")
  const windowContext = windowCanvas?.getContext("2d", { alpha: false }) ?? null
  let windowFrame = 0
  let windowVisible = true
  let windowWidth = 0
  let windowHeight = 0
  let lastWindowTime = 0
  let horizonY = 0
  let sphereRadius = 12
  let sphereCentreX = 0
  let sphereCentreY = 0

  let particles: OrbParticle[] = []
  let holes: OrbHole[] = []
  let trailPoints: OrbTrailPoint[] = []
  let crawlers: OrbCrawler[] = []
  let dustMotes: OrbDust[] = []

  let orbPhase: "spin" | "erode" | "fade" | "rebirth" = "spin"
  let phaseTime = 0
  let spawnClock = 0
  let rotOffset = Math.random() * Math.PI * 2
  let cosYaw = 1
  let sinYaw = 0
  let cosPitch = 1
  let sinPitch = 0

  const ORB_SPIN_MS = 1500
  const ORB_FADE_MS = 1500
  const ORB_REBIRTH_MS = 800
  const ORB_MAX_HOLES = 34
  const ORB_SPAWN_INTERVAL = 760
  const ORB_TILT = 0.34

  const resizeWindowScene = () => {
    if (!windowCanvas) return
    const bounds = windowCanvas.getBoundingClientRect()
    windowWidth = Math.max(120, Math.round(bounds.width / 3))
    windowHeight = Math.max(48, Math.round(bounds.height / 3))
    windowCanvas.width = windowWidth
    windowCanvas.height = windowHeight
    horizonY = Math.round(windowHeight * 0.82)
    sphereRadius = Math.min(27, Math.max(10, Math.min(windowWidth, windowHeight) * 0.36))
    sphereCentreX = Math.round(windowWidth * 0.5)
    sphereCentreY = horizonY - Math.round(sphereRadius * 0.68)
  }

  const respawnCrawlers = () => {
    crawlers = []
    for (let index = 0; index < 3; index += 1) {
      const direction = randomDirection()
      const basis = tangentBasis(direction)
      crawlers.push({ direction, heading: basis[index % 2] })
    }
  }

  const buildOrb = () => {
    const count = Math.round(Math.min(820, Math.max(320, sphereRadius * sphereRadius * 4.4)))
    const goldenAngle = Math.PI * (3 - Math.sqrt(5))
    particles = []
    for (let index = 0; index < count; index += 1) {
      const y = count > 1 ? 1 - (index / (count - 1)) * 2 : 0
      const span = Math.sqrt(Math.max(0, 1 - y * y))
      const theta = goldenAngle * index
      const roll = Math.random()
      const tone: 0 | 1 | 2 = roll < 0.055 ? 2 : Math.abs(y) > 0.7 && roll < 0.52 ? 0 : 1
      particles.push({
        direction: { x: Math.cos(theta) * span, y, z: Math.sin(theta) * span },
        alive: true,
        tone,
        jitter: Math.random() * 0.07,
        size: Math.random() < 0.76 ? 2 : 1,
      })
    }
    holes = []
    trailPoints = []
    dustMotes = []
    spawnClock = 0
    respawnCrawlers()
  }

  const seedHole = () => {
    const radius = 0.115
    holes.push({ centre: randomDirection(), radius, cosRadius: Math.cos(radius) })
  }

  const spawnChildHole = () => {
    const parent = holes[Math.floor(Math.random() * holes.length)]
    if (!parent) {
      seedHole()
      return
    }
    const [across, along] = tangentBasis(parent.centre)
    const angle = Math.random() * Math.PI * 2
    const drift = parent.radius * (0.35 + Math.random() * 0.55)
    const offsetX = (across.x * Math.cos(angle) + along.x * Math.sin(angle)) * drift
    const offsetY = (across.y * Math.cos(angle) + along.y * Math.sin(angle)) * drift
    const offsetZ = (across.z * Math.cos(angle) + along.z * Math.sin(angle)) * drift
    const radius = Math.max(0.05, parent.radius * (0.5 + Math.random() * 0.24))
    holes.push({
      centre: normaliseVec({
        x: parent.centre.x + offsetX,
        y: parent.centre.y + offsetY,
        z: parent.centre.z + offsetZ,
      }),
      radius,
      cosRadius: Math.cos(radius),
    })
  }

  const growHoles = (delta: number) => {
    for (const hole of holes) {
      hole.radius = Math.min(0.9, hole.radius + delta * 0.0022)
      hole.cosRadius = Math.cos(hole.radius)
    }
  }

  const projectDirection = (direction: Vec3) => {
    const rotatedX = direction.x * cosYaw + direction.z * sinYaw
    const rotatedZ = direction.z * cosYaw - direction.x * sinYaw
    const rotatedY = direction.y * cosPitch - rotatedZ * sinPitch
    const depth = direction.y * sinPitch + rotatedZ * cosPitch
    return {
      sx: sphereCentreX + rotatedX * sphereRadius,
      sy: sphereCentreY + rotatedY * sphereRadius * 0.96,
      depth,
    }
  }

  const spawnDust = (particle: OrbParticle) => {
    const projected = projectDirection(particle.direction)
    dustMotes.push({
      sx: projected.sx,
      sy: projected.sy,
      vx: (projected.sx - sphereCentreX) * 0.004 + (Math.random() - 0.5) * 0.02,
      vy: -0.012 - Math.random() * 0.028,
      energy: 0.7 + Math.random() * 0.3,
      tone: Math.random() < 0.5 ? 0 : 1,
    })
    if (dustMotes.length > 160) dustMotes.shift()
  }

  const runErosionPass = () => {
    let survivors = 0
    for (const particle of particles) {
      if (!particle.alive) continue
      for (const hole of holes) {
        const dot =
          particle.direction.x * hole.centre.x +
          particle.direction.y * hole.centre.y +
          particle.direction.z * hole.centre.z
        if (dot >= hole.cosRadius - particle.jitter) {
          particle.alive = false
          spawnDust(particle)
          break
        }
      }
      if (particle.alive) survivors += 1
    }
    return survivors / Math.max(1, particles.length)
  }

  const advanceCrawlers = (delta: number) => {
    const step = 0.0021 * delta
    for (const crawler of crawlers) {
      crawler.direction = rotateTowards(crawler.direction, crawler.heading, step)
      const [across] = tangentBasis(crawler.direction)
      const wobble = (Math.random() - 0.5) * 0.4
      let hx = crawler.heading.x + across.x * wobble
      let hy = crawler.heading.y + across.y * wobble
      let hz = crawler.heading.z + across.z * wobble
      const alignment =
        hx * crawler.direction.x + hy * crawler.direction.y + hz * crawler.direction.z
      hx -= alignment * crawler.direction.x
      hy -= alignment * crawler.direction.y
      hz -= alignment * crawler.direction.z
      crawler.heading = normaliseVec({ x: hx, y: hy, z: hz })
      trailPoints.push({ position: { ...crawler.direction }, energy: 1 })
    }
    while (trailPoints.length > 300) trailPoints.shift()
    trailPoints = trailPoints.filter((point) => {
      point.energy -= delta * 0.00042
      return point.energy > 0.02
    })
  }

  const advanceDust = (delta: number) => {
    dustMotes = dustMotes.filter((mote) => {
      mote.vy += delta * 0.00016
      mote.sx += mote.vx * delta
      mote.sy += mote.vy * delta
      mote.energy -= delta * 0.0011
      return mote.energy > 0 && mote.sy < windowHeight
    })
  }

  const pixel = (
    context: CanvasRenderingContext2D,
    x: number,
    y: number,
    width: number,
    height: number,
    colour: string,
    alpha = 1,
  ) => {
    context.globalAlpha = alpha
    context.fillStyle = colour
    context.fillRect(Math.round(x), Math.round(y), Math.round(width), Math.round(height))
  }

  const drawWindowScene = (now: number, frozen = false) => {
    if (!windowCanvas || !windowContext || !windowVisible || document.hidden) {
      // Mark the loop dead so the IntersectionObserver can restart it.
      windowFrame = 0
      return
    }
    if (!frozen && now - lastWindowTime < 32 && !reducedMotion.matches) {
      windowFrame = requestAnimationFrame(drawWindowScene)
      return
    }

    const delta = frozen ? 0 : Math.min(50, now - lastWindowTime || 16)
    lastWindowTime = now

    if (!frozen) {
      phaseTime += delta
      if (orbPhase === "spin") {
        if (phaseTime >= ORB_SPIN_MS) {
          orbPhase = "erode"
          phaseTime = 0
          seedHole()
        }
      } else if (orbPhase === "erode") {
        growHoles(delta)
        spawnClock += delta
        if (spawnClock >= ORB_SPAWN_INTERVAL && holes.length < ORB_MAX_HOLES) {
          spawnChildHole()
          spawnClock = 0
        }
      } else if (orbPhase === "fade") {
        if (phaseTime >= ORB_FADE_MS) {
          orbPhase = "rebirth"
          phaseTime = 0
          buildOrb()
          rotOffset += 1.7
        }
      } else if (phaseTime >= ORB_REBIRTH_MS) {
        orbPhase = "spin"
        phaseTime = 0
      }
    }

    const angleYaw = now * 0.00042 + rotOffset
    cosYaw = Math.cos(angleYaw)
    sinYaw = Math.sin(angleYaw)
    cosPitch = Math.cos(ORB_TILT)
    sinPitch = Math.sin(ORB_TILT)

    if (!frozen && orbPhase === "erode") {
      const ratio = runErosionPass()
      if (ratio <= 0.16 || phaseTime >= 8200) {
        orbPhase = "fade"
        phaseTime = 0
      }
    }

    if (!frozen && orbPhase !== "rebirth") {
      advanceCrawlers(delta)
      advanceDust(delta)
    }

    const paper = gardenColour("--garden-paper", "#f5efe1")
    const deep = gardenColour("--garden-paper-deep", "#e8deca")
    const ink = gardenColour("--garden-ink", "#172b4d")
    const rust = gardenColour("--garden-rust", "#bd5438")
    const sky = gardenColour("--garden-sky", "#90a9c5")
    const leaf = gardenColour("--garden-leaf", "#536d59")
    const toneColours = [paper, sky, rust]

    const context = windowContext
    context.fillStyle = deep
    context.fillRect(0, 0, windowWidth, windowHeight)

    pixel(context, 0, 0, windowWidth, horizonY, sky, 0.5)
    for (let y = 3; y < horizonY; y += 5) {
      for (let x = (y * 7) % 11; x < windowWidth; x += 13) {
        pixel(context, x, y, 1, 1, ink, 0.08)
      }
    }

    const drift = frozen ? 0.25 : (now * 0.006) % (windowWidth + 40)
    pixel(context, windowWidth - drift, 8, 22, 1, paper, 0.16)
    pixel(context, windowWidth - drift + 25, 19, 8, 1, paper, 0.1)

    for (let x = 0; x < windowWidth; x += 3) {
      const groundLine = horizonY + Math.sin(x * 0.09) * 2
      pixel(context, x, groundLine, 4, windowHeight - groundLine, leaf, 0.45)
    }

    const fadeAlpha =
      orbPhase === "fade"
        ? Math.max(0, 1 - phaseTime / ORB_FADE_MS)
        : orbPhase === "rebirth"
          ? Math.min(1, phaseTime / ORB_REBIRTH_MS)
          : 1
    const effRadius = sphereRadius * (orbPhase === "fade" ? 1 + (1 - fadeAlpha) * 0.3 : 1)

    for (const point of trailPoints) {
      const rotatedZ = point.position.z * cosYaw - point.position.x * sinYaw
      const rotatedY = point.position.y * cosPitch - rotatedZ * sinPitch
      const depth = point.position.y * sinPitch + rotatedZ * cosPitch
      const sx = sphereCentreX + (point.position.x * cosYaw + point.position.z * sinYaw) * effRadius
      const sy = sphereCentreY + rotatedY * effRadius * 0.96
      if (depth <= 0) pixel(context, sx, sy, 1, 1, rust, point.energy * 0.32 * fadeAlpha)
      else if (depth > 0) {
        const size = point.energy > 0.55 ? 2 : 1
        pixel(context, sx, sy, size, size, rust, point.energy * 0.78 * fadeAlpha)
      }
    }

    for (const particle of particles) {
      if (!particle.alive) continue
      const rotatedZ = particle.direction.z * cosYaw - particle.direction.x * sinYaw
      const rotatedY = particle.direction.y * cosPitch - rotatedZ * sinPitch
      const depth = particle.direction.y * sinPitch + rotatedZ * cosPitch
      const sx =
        sphereCentreX + (particle.direction.x * cosYaw + particle.direction.z * sinYaw) * effRadius
      const sy = sphereCentreY + rotatedY * effRadius * 0.96
      if (depth <= 0) {
        pixel(context, sx, sy, 1, 1, toneColours[particle.tone], 0.3 * fadeAlpha)
      } else {
        pixel(
          context,
          sx,
          sy,
          particle.size,
          particle.size,
          toneColours[particle.tone],
          0.95 * fadeAlpha,
        )
      }
    }

    for (const crawler of crawlers) {
      const rotatedZ = crawler.direction.z * cosYaw - crawler.direction.x * sinYaw
      const rotatedY = crawler.direction.y * cosPitch - rotatedZ * sinPitch
      const depth = crawler.direction.y * sinPitch + rotatedZ * cosPitch
      if (depth <= 0) continue
      const sx =
        sphereCentreX + (crawler.direction.x * cosYaw + crawler.direction.z * sinYaw) * effRadius
      const sy = sphereCentreY + rotatedY * effRadius * 0.96
      pixel(context, sx - 1, sy - 1, 3, 3, rust, 0.55 * fadeAlpha)
      pixel(context, sx, sy, 2, 2, paper, 0.95 * fadeAlpha)
    }

    for (const mote of dustMotes) {
      pixel(context, mote.sx, mote.sy, 1, 1, mote.tone === 0 ? leaf : sky, mote.energy * 0.85)
    }

    context.globalAlpha = 1
    if (!frozen && !reducedMotion.matches) windowFrame = requestAnimationFrame(drawWindowScene)
  }

  const composeStaticScene = () => {
    buildOrb()
    const seeds: Vec3[] = [
      { x: 0.28, y: 0.79, z: 0.55 },
      { x: -0.62, y: 0.31, z: -0.72 },
      { x: 0.51, y: -0.58, z: 0.64 },
      { x: -0.18, y: -0.83, z: -0.53 },
    ]
    for (const centre of seeds) {
      const radius = 0.09 + Math.random() * 0.05
      holes.push({ centre, radius, cosRadius: Math.cos(radius) })
    }
    runErosionPass()
    const walker = crawlers[0]
    if (walker) {
      for (let index = 0; index < 70; index += 1) {
        walker.direction = rotateTowards(walker.direction, walker.heading, 0.021)
        trailPoints.push({ position: { ...walker.direction }, energy: 1 - index / 74 })
      }
    }
  }

  const windowObserver = windowCanvas
    ? new IntersectionObserver((entries) => {
        windowVisible = entries[0]?.isIntersecting ?? false
        if (windowVisible && !windowFrame && !reducedMotion.matches) {
          windowFrame = requestAnimationFrame(drawWindowScene)
        }
      })
    : null

  const onVisibilityChange = () => {
    fieldVisible = !document.hidden
    if (fieldVisible && !reducedMotion.matches) {
      cancelAnimationFrame(fieldFrame)
      fieldFrame = requestAnimationFrame(drawField)
      if (windowVisible) {
        cancelAnimationFrame(windowFrame)
        windowFrame = requestAnimationFrame(drawWindowScene)
      }
    }
  }

  const onResize = () => {
    resizeField()
    resizeWindowScene()
    drawField(performance.now())
    drawWindowScene(performance.now(), true)
  }

  resizeField()
  resizeWindowScene()
  buildOrb()
  document.addEventListener("pointermove", addTrailCell, { passive: true })
  document.addEventListener("visibilitychange", onVisibilityChange)
  window.addEventListener("resize", onResize, { passive: true })
  if (windowCanvas) windowObserver?.observe(windowCanvas)
  drawField(performance.now())

  if (reducedMotion.matches) {
    composeStaticScene()
    drawWindowScene(performance.now() + 4200, true)
  } else {
    windowFrame = requestAnimationFrame(drawWindowScene)
  }

  window.addCleanup(() => {
    cancelAnimationFrame(fieldFrame)
    cancelAnimationFrame(windowFrame)
    windowObserver?.disconnect()
    document.removeEventListener("pointermove", addTrailCell)
    document.removeEventListener("visibilitychange", onVisibilityChange)
    window.removeEventListener("resize", onResize)
    field.remove()
  })
}

document.addEventListener("nav", setupGardenMotion)
