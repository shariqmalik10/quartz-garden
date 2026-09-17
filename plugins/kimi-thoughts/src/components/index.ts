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
 *
 * Note on naming: the markup intentionally reuses the shared "ds-*"
 * shared sketchbook classes in custom.scss so both
 * sketchbooks look like siblings. Behaviour hooks are the "data-kt-*"
 * attributes, which the kimi doodle script owns.
 */
const ARTWORKS: Artwork[] = [
  {
    id: "storm",
    src: "/static/kimi-thoughts/storm-lighthouse.jpg",
    width: 1920,
    height: 1080,
    alt: "Lightning forking through a purple night sky over the harbour at Port-la-Nouvelle, two small lighthouses glowing green and gold at the end of a long pier.",
    title: "Argument night",
    credit: "Maxime Raynal · CC BY 2.0",
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
    credit: "After Hokusai, c. 1831 · public domain",
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
    credit: "Chuck Homler / Focus On Wildlife · CC BY-SA 4.0",
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
    credit: "Giles Laurent · CC BY-SA 4.0",
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
    credit: "Alan Wilson · CC BY-SA 2.0",
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
    credit: "Simo Räsänen (Ximonic) · CC BY-SA 3.0",
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
    credit: "Andreas Cellarius, Harmonia Macrocosmica, 1660 · public domain",
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
    credit: "Benh LIEU SONG · CC BY-SA 3.0",
    creditUrl:
      "https://commons.wikimedia.org/wiki/File:Cappadocia_Balloon_Inflating_Wikimedia_Commons.JPG",
    seed: 20100618,
  },
]

const KimiThoughts: QuartzComponentConstructor = () => {
  const KimiThoughtsComponent = ({ fileData }: QuartzComponentProps) => {
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
              "Every mark below was drawn in your browser with the Canvas 2D API — no pixels painted in advance, and the sparkles keep twinkling once the ink dries. Tap a picture to open it big, reseed the ink, or pick up the pencil and add your own.",
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
                    h("span", { class: "ds-open-mark", "aria-hidden": "true" }, "⤢"),
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
          " (Tornado); Simo Räsänen (Ximonic) and Benh LIEU SONG, ",
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

export { KimiThoughts }
export default KimiThoughts
