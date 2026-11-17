// npm audit, but with a short list of advisories accepted temporarily.
// Run from the package folder: node ../.github/scripts/npm-audit.mjs
// Fails on any advisory at any severity that is not listed below, and on a listed one that no longer appears
// (so the exception is removed as soon as a fixed version lands).
import { execFileSync } from 'node:child_process'

const ALLOWED = {
  // picomatch <=4.0.7 ReDoS via repeated extglobs. No patched release yet; reached through nextra and patch-package.
  // Accepted because the docs build only globs repository-controlled patterns, and fork PRs run on `pull_request`
  // with a read-only token and no secrets. Remove once picomatch ships a fix and the lockfile is updated.
  'GHSA-fc5q-39xc-vjpf': 'picomatch ReDoS, no fix released',
}

let raw
try {
  raw = execFileSync('npm', ['audit', '--json'], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 })
} catch (error) {
  raw = error.stdout // npm audit exits non-zero when it finds anything
  if (!raw) throw error
}
const report = JSON.parse(raw)
if (report.error) {
  console.error('npm audit failed:', report.error.summary ?? report.error)
  process.exit(1)
}

const found = new Map()
for (const vuln of Object.values(report.vulnerabilities ?? {})) {
  for (const via of vuln.via) {
    if (typeof via !== 'object') continue // a package name: the advisory itself is listed under that package
    const id = via.url?.split('/').pop() ?? String(via.source)
    found.set(id, `${via.name} ${via.range}: ${via.title} (${via.severity})`)
  }
}

let failed = false
for (const [id, text] of found) {
  if (ALLOWED[id]) {
    console.log(`::warning::Allowed advisory ${id}: ${text}`)
  } else {
    console.log(`::error::${id}: ${text}`)
    failed = true
  }
}
for (const id of Object.keys(ALLOWED)) {
  if (!found.has(id)) {
    console.log(`::error::${id} is no longer reported. Remove it from .github/scripts/npm-audit.mjs.`)
    failed = true
  }
}
console.log(failed ? 'Audit failed.' : `Audit passed (${found.size} allowed advisory).`)
process.exit(failed ? 1 : 0)
