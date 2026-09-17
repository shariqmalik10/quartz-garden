import { h } from "preact"
import { DOODLE_SCRIPT } from "../doodle-script"

/**
 * Minimal local stand-ins for the harness types. Plugin sources are compiled
 * outside the main tsconfig, so they stay self-contained.
 */
type QuartzComponentProps = { fileData: { slug?: string } }
type QuartzComponent = ((props: QuartzComponentProps) => unknown) & {
  displayName?: string
  afterDOMLoaded?: string
}
type QuartzComponentConstructor = () => QuartzComponent

type Artwork = {
  id: string
  src: string
  width: number
  height: number
  alt: string
  title: string
  credit: string
  creditUrl: string
  seed: number
  wide?: boolean
}

/**
 * Pictures found while wandering the open web, one lazy afternoon each.
 * The doodle engine in ../doodle-script.ts responds to each composition.
 */
const ARTWORKS: Artwork[] = [
  {
    id: "hubble",
    src: "/static/deepseek-thoughts/hubble-deep-field.jpg",
    width: 1400,
    height: 1400,
    alt: "The Hubble Ultra Deep Field: thousands of distant galaxies scattered across black space, with a few bright foreground stars.",
    title: "A very deep field",
    credit: "NASA & ESA · public domain",
    creditUrl: "https://commons.wikimedia.org/wiki/File:Hubble_ultra_deep_field_high_rez_edit1.jpg",
    seed: 20140603,
  },
  {
    id: "haeckel",
    src: "/static/deepseek-thoughts/haeckel-narcomedusae.jpg",
    width: 992,
    height: 1400,
    alt: "Ernst Haeckel's 1904 lithograph plate of narcomedusae: nine jellyfish rendered in teal and cream on paper.",
    title: "Narcomedusae, plate 16",
    credit: "Ernst Haeckel, Kunstformen der Natur, 1904 · public domain",
    creditUrl: "https://commons.wikimedia.org/wiki/File:Haeckel_Narcomedusae.jpg",
    seed: 1904,
  },
  {
    id: "mirror",
    src: "/static/deepseek-thoughts/mirror-lake-mount-hood.jpg",
    width: 1400,
    height: 1111,
    alt: "Mount Hood reflected in Mirror Lake, Oregon, on a clear day, with forested shorelines on both sides.",
    title: "Mount Hood, twice",
    credit: "Oregon's Mt. Hood Territory / FHWA · public domain",
    creditUrl:
      "https://commons.wikimedia.org/wiki/File:Mount_Hood_reflected_in_Mirror_Lake,_Oregon.jpg",
    seed: 62736,
    wide: true,
  },
  {
    id: "mekong",
    src: "/static/deepseek-thoughts/mekong-sunset.jpg",
    width: 1400,
    height: 933,
    alt: "Sunset over the Mekong at Don Det, Laos: grey and orange clouds reflected in still water beside moored wooden boats.",
    title: "Two pirogues at dusk",
    credit: "Basile Morin · CC BY-SA 4.0",
    creditUrl:
      "https://commons.wikimedia.org/wiki/File:Water_reflection_of_sunset_with_gray_and_orange_clouds_and_pirogues_moored_to_the_bank_in_Don_Det_Laos.jpg",
    seed: 20191127,
  },
  {
    id: "vang-vieng",
    src: "/static/deepseek-thoughts/vang-vieng-rays.jpg",
    width: 1400,
    height: 875,
    alt: "Karst mountains in Vang Vieng, Laos, with shafts of evening light falling through clouds onto flooded rice fields.",
    title: "Borrowed light",
    credit: "Basile Morin · CC BY-SA 4.0",
    creditUrl:
      "https://commons.wikimedia.org/wiki/File:Water_reflection_of_the_mountains_of_Vang_Vieng_with_crepuscular_rays.jpg",
    seed: 20200618,
  },
  {
    id: "cat",
    src: "/static/deepseek-thoughts/tabby-cat.jpg",
    width: 1400,
    height: 852,
    alt: "A tabby cat lying against a white wall, one paw stretched out, looking thoroughly unbothered.",
    title: "The stretch",
    credit: "Alvesgaspar · CC BY-SA 3.0",
    creditUrl: "https://commons.wikimedia.org/wiki/File:Cat_August_2010-3.jpg",
    seed: 20100803,
  },
  {
    id: "whale",
    src: "/static/deepseek-thoughts/whale-breaching.jpg",
    width: 1400,
    height: 933,
    alt: "A humpback whale breaching clear of the water in Ballena Marine National Park, spray falling around it.",
    title: "Quite deep, actually",
    credit: "Giles Laurent · CC BY-SA 4.0",
    creditUrl:
      "https://commons.wikimedia.org/wiki/File:001_Humpback_whale_breaching_in_Ballena_Marine_National_Park_Photo_by_Giles_Laurent.jpg",
    seed: 20220722,
  },
  {
    id: "chart",
    src: "/static/deepseek-thoughts/porcupine-chart-1870.jpg",
    width: 1400,
    height: 706,
    alt: "An 1870 bathymetric chart of the western Mediterranean from the cruise of HMS Porcupine, with sounding depths dotted along the coastlines.",
    title: "The deeps, 1870",
    credit: "Cruise of the Porcupine, 1870 · public domain",
    creditUrl:
      "https://commons.wikimedia.org/wiki/File:Carpenter_Porcupine_1871_Chart_1_02398928_0076.jpg",
    seed: 1870,
    wide: true,
  },
]

const DeepSeekThoughts: QuartzComponentConstructor = () => {
  const DeepSeekThoughtsComponent = ({ fileData }: QuartzComponentProps) => {
    if (fileData.slug !== "deepseek-thoughts") return null

    return h(
      "section",
      {
        class: "deepseek-lab",
        "data-ds-lab": "true",
        "aria-labelledby": "deepseek-lab-title",
      },
      [
        h("div", { class: "ds-lab-head" }, [
          h("div", { class: "ds-lab-lede" }, [
            h("h2", { id: "deepseek-lab-title" }, "The sketchbook"),
            h(
              "p",
              null,
              "Every mark below was drawn in your browser with the Canvas 2D API — no pixels painted in advance. Tap a picture to open it big, reseed the ink, or pick up the pencil and add your own.",
            ),
          ]),
          h("div", { class: "ds-lab-actions" }, [
            h(
              "button",
              {
                type: "button",
                class: "ds-action ds-action-strong",
                "data-ds-redoodle-all": "true",
              },
              "doodle them all again",
            ),
            h(
              "button",
              {
                type: "button",
                class: "ds-action",
                "data-ds-toggle-doodles": "true",
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
                  "data-ds-piece": artwork.id,
                  "data-ds-seed": String(artwork.seed),
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
                      "data-ds-open": "true",
                      "aria-label": `Open ${artwork.title} in the focus view`,
                    },
                    h("span", { class: "ds-open-mark", "aria-hidden": "true" }, "⤢"),
                  ),
                  h("canvas", { class: "ds-ink", "aria-hidden": "true" }),
                  h("canvas", {
                    class: "ds-pad",
                    "data-ds-pad": "true",
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
                    { type: "button", class: "ds-action", "data-ds-redoodle": "true" },
                    "doodle again",
                  ),
                  h(
                    "button",
                    {
                      type: "button",
                      class: "ds-action",
                      "data-ds-draw": "true",
                      "aria-pressed": "false",
                    },
                    "draw on it",
                  ),
                  h(
                    "button",
                    {
                      type: "button",
                      class: "ds-action ds-action-quiet",
                      "data-ds-clear": "true",
                      hidden: true,
                    },
                    "clear my marks",
                  ),
                  h(
                    "button",
                    {
                      type: "button",
                      class: "ds-action ds-action-quiet",
                      "data-ds-save": "true",
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
          "Pictures: NASA & ESA (public domain); Ernst Haeckel, ",
          h("i", null, "Kunstformen der Natur"),
          ", 1904 (public domain); Oregon's Mt. Hood Territory / FHWA (public domain); ",
          "Cruise of HMS Porcupine, 1870 (public domain); Basile Morin, ",
          h(
            "a",
            {
              href: "https://creativecommons.org/licenses/by-sa/4.0/",
              target: "_blank",
              rel: "noopener noreferrer",
            },
            "CC BY-SA 4.0",
          ),
          " (Don Det, Vang Vieng, and the whale by Giles Laurent); Alvesgaspar, ",
          h(
            "a",
            {
              href: "https://creativecommons.org/licenses/by-sa/3.0/",
              target: "_blank",
              rel: "noopener noreferrer",
            },
            "CC BY-SA 3.0",
          ),
          " (the cat). Doodles live on a separate canvas and never touch the originals.",
        ]),
      ],
    )
  }

  DeepSeekThoughtsComponent.displayName = "DeepSeek Thoughts"
  DeepSeekThoughtsComponent.afterDOMLoaded = DOODLE_SCRIPT
  return DeepSeekThoughtsComponent
}

export { DeepSeekThoughts }
export default DeepSeekThoughts
