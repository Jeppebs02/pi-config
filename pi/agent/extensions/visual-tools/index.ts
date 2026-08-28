/**
 * visual-tools
 *
 * Registers the six maker-subagent tools directly as plain extension tools, so
 * they're available in the parent session AND in any child pi process (children
 * spawned by pi-sub-agent load the same global extensions):
 *
 *   • write_mermaid / edit_mermaid / render_mermaid
 *       (tools/mermaid_tools.ts) — author a Mermaid source, exact-match edit
 *       it, render to a PNG (via bundled @mermaid-js/mermaid-cli + Chrome),
 *       return the PNG inline for inspection, and publish into <cwd>/viz.
 *   • write_svg / edit_svg / render_svg
 *       (tools/svg_tools.ts) — same shape, rendering SVG via rsvg-convert
 *       (fallback: ImageMagick).
 *
 * Originally wired through the interactive-subagents `registerToolExtension`
 * hook; direct registration works with any subagent implementation that loads
 * global extensions in the child (pi-sub-agent does).
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import mermaidTools from "./tools/mermaid_tools.ts";
import svgTools from "./tools/svg_tools.ts";

export default function (pi: ExtensionAPI) {
 mermaidTools(pi);
 svgTools(pi);
}
