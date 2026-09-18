import { h } from "preact"
import { DOODLE_SCRIPT } from "../doodle-script"

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

const ARTWORKS: Artwork[] = [
  {
    id: "cosmic",
    src: "/static/model-sketchbooks/medium/cosmic-cliffs.jpg",
    width: 1920,
    height: 1112,
    alt: "The Cosmic Cliffs in the Carina Nebula, a glowing wall of amber gas beneath a blue field of stars.",
    title: "The nursery is loud",
    credit: "NASA, ESA, CSA & STScI · public domain",
    creditUrl:
      "https://commons.wikimedia.org/wiki/File:NASA%E2%80%99s_Webb_Reveals_Cosmic_Cliffs%2C_Glittering_Landscape_of_Star_Birth.jpg",
    seed: 56001,
    wide: true,
  },
  {
    id: "salt",
    src: "/static/model-sketchbooks/medium/salt-ponds.jpg",
    width: 1920,
    height: 1282,
    alt: "Aerial view of geometric salt ponds around San Francisco Bay in rust, green, tan, and blue.",
    title: "Colour by evaporation",
    credit: "Daniel L. Lu · CC BY-SA 4.0",
    creditUrl:
      "https://commons.wikimedia.org/wiki/File:Aerial_view_of_San_Francisco_Bay_Area_salt_ponds_dllu.jpg",
    seed: 56002,
    wide: true,
  },
  {
    id: "fungi",
    src: "/static/model-sketchbooks/medium/mushrooms.jpg",
    width: 1744,
    height: 2395,
    alt: "A 1797 botanical plate of field mushrooms, showing caps, stems, and gills against aged paper.",
    title: "A quiet network",
    credit: "James Sowerby, 1797 · public domain",
    creditUrl:
      "https://commons.wikimedia.org/wiki/File:1797-09-03_Agaricus_campestris_Plate_by_James_Sowerby.jpg",
    seed: 56003,
  },
  {
    id: "jelly",
    src: "/static/model-sketchbooks/medium/jellyfish.jpg",
    width: 1840,
    height: 1840,
    alt: "A translucent jellyfish drifting through deep blue aquarium water, with tentacles trailing below.",
    title: "Soft machinery",
    credit: "KSC60 · CC BY-SA 4.0",
    creditUrl: "https://commons.wikimedia.org/wiki/File:Jellyfish_in_blue_aquarium.jpg",
    seed: 56004,
  },
  {
    id: "station",
    src: "/static/model-sketchbooks/medium/train-station.jpg",
    width: 1024,
    height: 649,
    alt: "A busy platform at Riihimäki railway station in Finland during the 1910s, with passengers and steam trains.",
    title: "Everybody is almost somewhere",
    credit: "Unknown photographer, 1910s · public domain",
    creditUrl: "https://commons.wikimedia.org/wiki/File:Riihim%C3%A4ki_train_station_1910s.jpg",
    seed: 56005,
    wide: true,
  },
  {
    id: "gullfoss",
    src: "/static/model-sketchbooks/medium/gullfoss.jpg",
    width: 1920,
    height: 1200,
    alt: "Gullfoss waterfall in winter, white water dropping between dark rock walls covered with snow.",
    title: "Gravity rehearsing",
    credit: "Pierre-Selim Huard · CC BY 4.0",
    creditUrl: "https://commons.wikimedia.org/wiki/File:Iceland_-_2017-02-22_-_Gullfoss_-_3684.jpg",
    seed: 56006,
    wide: true,
  },
]

const MediumThoughts: QuartzComponentConstructor = () => {
  const MediumThoughtsComponent = ({ fileData }: QuartzComponentProps) => {
    if (fileData.slug !== "model-sketchbooks/5-6-medium") return null

    return h(
      "section",
      {
        class: "deepseek-lab medium-lab",
        "data-mt-lab": "true",
        "aria-labelledby": "medium-lab-title",
      },
      [
        h("div", { class: "ds-lab-head" }, [
          h("div", { class: "ds-lab-lede" }, [
            h("h2", { id: "medium-lab-title" }, "Margin Weather"),
            h(
              "p",
              null,
              "Six open images, six small interruptions. Every line is generated in your browser with the Canvas 2D API; the source pictures remain untouched.",
            ),
          ]),
          h("div", { class: "ds-lab-actions" }, [
            h(
              "button",
              {
                type: "button",
                class: "ds-action ds-action-strong",
                "data-mt-redoodle-all": "true",
              },
              "doodle them all again",
            ),
            h(
              "button",
              {
                type: "button",
                class: "ds-action",
                "data-mt-toggle-doodles": "true",
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
              { key: artwork.id, class: "ds-piece" + (artwork.wide ? " ds-piece-wide" : "") },
              h(
                "figure",
                {
                  class: "ds-frame",
                  "data-mt-piece": artwork.id,
                  "data-mt-seed": String(artwork.seed),
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
                      "data-mt-open": "true",
                      "aria-label": `Open ${artwork.title} in the focus view`,
                    },
                    h("span", { class: "ds-open-mark", "aria-hidden": "true" }, "⤢"),
                  ),
                  h("canvas", { class: "ds-ink", "aria-hidden": "true" }),
                  h("canvas", {
                    class: "ds-pad",
                    "data-mt-pad": "true",
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
                    { type: "button", class: "ds-action", "data-mt-redoodle": "true" },
                    "doodle again",
                  ),
                  h(
                    "button",
                    {
                      type: "button",
                      class: "ds-action",
                      "data-mt-draw": "true",
                      "aria-pressed": "false",
                    },
                    "draw on it",
                  ),
                  h(
                    "button",
                    {
                      type: "button",
                      class: "ds-action ds-action-quiet",
                      "data-mt-clear": "true",
                      hidden: true,
                    },
                    "clear my marks",
                  ),
                  h(
                    "button",
                    {
                      type: "button",
                      class: "ds-action ds-action-quiet",
                      "data-mt-save": "true",
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
          "Images from Wikimedia Commons: NASA, ESA, CSA & STScI; James Sowerby; and an unknown Finnish photographer (public domain); Daniel L. Lu and KSC60 (",
          h(
            "a",
            {
              href: "https://creativecommons.org/licenses/by-sa/4.0/",
              target: "_blank",
              rel: "noopener noreferrer",
            },
            "CC BY-SA 4.0",
          ),
          "); Pierre-Selim Huard (",
          h(
            "a",
            {
              href: "https://creativecommons.org/licenses/by/4.0/",
              target: "_blank",
              rel: "noopener noreferrer",
            },
            "CC BY 4.0",
          ),
          "). Doodles live on a separate JavaScript canvas and never alter the originals.",
        ]),
      ],
    )
  }

  MediumThoughtsComponent.displayName = "5.6 Medium Thoughts"
  MediumThoughtsComponent.afterDOMLoaded = DOODLE_SCRIPT
  return MediumThoughtsComponent
}

export { MediumThoughts }
export default MediumThoughts
