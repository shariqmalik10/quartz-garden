type GardenTrailCell = {
  column: number
  row: number
  energy: number
  born: number
}

function gardenColour(name: string, fallback: string) {
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim() || fallback
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

  const flower = document.querySelector<HTMLCanvasElement>(".garden-flower")
  const flowerContext = flower?.getContext("2d", { alpha: false }) ?? null
  let flowerFrame = 0
  let flowerVisible = true
  let flowerWidth = 0
  let flowerHeight = 0
  let lastFlowerTime = 0

  const resizeFlower = () => {
    if (!flower) return
    const bounds = flower.getBoundingClientRect()
    flowerWidth = Math.max(120, Math.round(bounds.width / 3))
    flowerHeight = Math.max(48, Math.round(bounds.height / 3))
    flower.width = flowerWidth
    flower.height = flowerHeight
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

  const drawFlower = (time: number) => {
    if (!flower || !flowerContext || !flowerVisible || document.hidden) return
    if (time - lastFlowerTime < 32 && !reducedMotion.matches) {
      flowerFrame = requestAnimationFrame(drawFlower)
      return
    }
    lastFlowerTime = time

    const ink = gardenColour("--garden-ink", "#172b4d")
    const paper = gardenColour("--garden-paper", "#f5efe1")
    const deep = gardenColour("--garden-paper-deep", "#e8deca")
    const rust = gardenColour("--garden-rust", "#bd5438")
    const sky = gardenColour("--garden-sky", "#90a9c5")
    const leaf = gardenColour("--garden-leaf", "#536d59")
    flowerContext.imageSmoothingEnabled = false
    flowerContext.fillStyle = deep
    flowerContext.fillRect(0, 0, flowerWidth, flowerHeight)

    const phase = reducedMotion.matches ? 0.35 : time * 0.001
    const wind = Math.sin(phase * 1.35) * 2.2 + Math.sin(phase * 0.47) * 1.1
    const horizon = Math.round(flowerHeight * 0.72)

    pixel(flowerContext, 0, 0, flowerWidth, horizon, sky, 0.56)
    for (let y = 3; y < horizon; y += 5) {
      for (let x = (y * 7) % 11; x < flowerWidth; x += 13) {
        pixel(flowerContext, x, y, 1, 1, ink, 0.1)
      }
    }

    for (let x = 0; x < flowerWidth; x += 3) {
      const groundY = horizon + Math.sin(x * 0.11) * 2
      pixel(flowerContext, x, groundY, 4, flowerHeight - groundY, leaf, 0.48)
    }

    for (let line = 0; line < 3; line += 1) {
      const travel = reducedMotion.matches
        ? 0.25
        : (phase * (9 + line * 2) + line * 31) % (flowerWidth + 34)
      const lineX = flowerWidth - travel
      pixel(flowerContext, lineX, 10 + line * 11, 24, 1, paper, 0.18)
      pixel(flowerContext, lineX + 27, 10 + line * 11, 7, 1, paper, 0.1)
    }

    const baseX = flowerWidth * 0.5
    const baseY = flowerHeight - 4
    const stemHeight = flowerHeight * 0.58
    const segments = Math.max(12, Math.floor(stemHeight / 2))
    let headX = baseX
    let headY = baseY - stemHeight
    for (let index = 0; index <= segments; index += 1) {
      const progress = index / segments
      const x = baseX + wind * progress * progress + Math.sin(progress * 5 + phase) * progress * 0.8
      const y = baseY - stemHeight * progress
      pixel(flowerContext, x, y, 2, 3, leaf)
      headX = x
      headY = y
    }

    const leafLift = Math.sin(phase * 1.6) * 1.2
    pixel(flowerContext, baseX - 9, baseY - stemHeight * 0.34 + leafLift, 10, 3, leaf)
    pixel(flowerContext, baseX - 12, baseY - stemHeight * 0.34 + 1 + leafLift, 5, 3, leaf, 0.82)
    pixel(flowerContext, baseX + 1, baseY - stemHeight * 0.52 - leafLift, 11, 3, leaf)
    pixel(flowerContext, baseX + 8, baseY - stemHeight * 0.52 - 2 - leafLift, 5, 3, leaf, 0.82)

    const petalDrift = Math.sin(phase * 1.8) * 1.4
    const petals = [
      [-1, -8],
      [6, -5],
      [8, 1],
      [4, 7],
      [-3, 8],
      [-9, 4],
      [-9, -3],
    ]
    for (const [petalX, petalY] of petals) {
      pixel(
        flowerContext,
        headX + petalX + petalDrift * (petalY < 0 ? 0.8 : 0.35),
        headY + petalY,
        6,
        5,
        paper,
      )
      pixel(
        flowerContext,
        headX + petalX + 1 + petalDrift * (petalY < 0 ? 0.8 : 0.35),
        headY + petalY + 1,
        4,
        3,
        rust,
        0.28,
      )
    }
    pixel(flowerContext, headX - 2 + petalDrift * 0.25, headY - 2, 7, 7, rust)
    pixel(flowerContext, headX, headY, 3, 3, paper, 0.68)

    for (let index = 0; index < 5; index += 1) {
      const pollenPhase = (phase * (0.7 + index * 0.06) + index * 0.19) % 1
      const pollenX = headX + 12 + pollenPhase * 42 + Math.sin(phase * 2 + index) * 2
      const pollenY = headY - 5 + index * 3 + Math.sin(phase * 1.4 + index) * 3
      pixel(flowerContext, pollenX, pollenY, 2, 2, rust, 0.72 * (1 - pollenPhase))
    }

    flowerContext.globalAlpha = 1
    if (!reducedMotion.matches) flowerFrame = requestAnimationFrame(drawFlower)
  }

  const flowerObserver = flower
    ? new IntersectionObserver((entries) => {
        flowerVisible = entries[0]?.isIntersecting ?? false
        if (flowerVisible && !flowerFrame && !reducedMotion.matches) {
          flowerFrame = requestAnimationFrame(drawFlower)
        }
      })
    : null

  const onVisibilityChange = () => {
    fieldVisible = !document.hidden
    if (fieldVisible && !reducedMotion.matches) {
      cancelAnimationFrame(fieldFrame)
      fieldFrame = requestAnimationFrame(drawField)
      if (flowerVisible) {
        cancelAnimationFrame(flowerFrame)
        flowerFrame = requestAnimationFrame(drawFlower)
      }
    }
  }

  const onResize = () => {
    resizeField()
    resizeFlower()
    drawField(performance.now())
    drawFlower(performance.now())
  }

  resizeField()
  resizeFlower()
  document.addEventListener("pointermove", addTrailCell, { passive: true })
  document.addEventListener("visibilitychange", onVisibilityChange)
  window.addEventListener("resize", onResize, { passive: true })
  if (flower) flowerObserver?.observe(flower)
  drawField(performance.now())
  drawFlower(performance.now())

  window.addCleanup(() => {
    cancelAnimationFrame(fieldFrame)
    cancelAnimationFrame(flowerFrame)
    flowerObserver?.disconnect()
    document.removeEventListener("pointermove", addTrailCell)
    document.removeEventListener("visibilitychange", onVisibilityChange)
    window.removeEventListener("resize", onResize)
    field.remove()
  })
}

document.addEventListener("nav", setupGardenMotion)
