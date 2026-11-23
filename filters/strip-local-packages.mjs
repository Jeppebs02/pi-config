#!/usr/bin/env node
// git clean filter for pi/agent/settings.json (wired up in .gitattributes,
// configured by install.ps1 / install.sh).
//
// The PI Dashboard server self-registers its extension into settings.json's
// packages list using a machine-local absolute path (most-recently-asserted
// wins), so that line is different on every machine and must never be
// committed. pi loads the extension fine from the "npm:@blackbelt-technology/
// pi-agent-dashboard" package ref alone; the local path is only the standalone
// server's own bookkeeping. Strip every absolute-path entry; npm:/git refs and
// relative paths pass through.
import fs from "node:fs";

const raw = fs.readFileSync(0, "utf8");
const settings = JSON.parse(raw);
if (Array.isArray(settings.packages)) {
  settings.packages = settings.packages.filter(
    (p) =>
      typeof p === "string" &&
      !p.startsWith("/") &&
      !/^[a-zA-Z]:[\\/]/.test(p),
  );
}
process.stdout.write(JSON.stringify(settings, null, 2) + "\n");
