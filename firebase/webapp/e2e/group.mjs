// Leader of one process group for e2e/run.mjs: `node e2e/group.mjs <run.mjs pid> <command> [args...]`.
// run.mjs spawns it detached, so the build, firebase emulators:exec, the seed and
// Playwright share this group. Some of their children start groups of their own
// (firebase-tools spawns the Firestore java detached, Playwright does the same with
// Chrome), so this process also keeps a list of those groups and takes them down
// with it. If run.mjs disappears without stopping it (SIGKILL), it stops by itself,
// so nothing is left behind with launchd as parent.
import { execFileSync, spawn } from 'node:child_process'
import { readFileSync, rmSync } from 'node:fs'
import { constants } from 'node:os'

const parent = Number(process.argv[2])
const [command, ...args] = process.argv.slice(3)
const sleep = (ms) => new Promise((done) => setTimeout(done, ms))
process.stdout.on('error', () => {})
process.stderr.on('error', () => {})

// pgid -> start time of its leader, so a reused PID is never signalled.
const subgroups = new Map()

function table() {
  try {
    return execFileSync('ps', ['-axo', 'pid=,ppid=,pgid=,lstart='], { encoding: 'utf8' })
      .split('\n')
      .map((line) => line.trim().match(/^(\d+)\s+(\d+)\s+(\d+)\s+(.+)$/))
      .filter(Boolean)
      .map(([, pid, ppid, pgid, started]) => ({ pid: +pid, ppid: +ppid, pgid: +pgid, started }))
  } catch {
    return []
  }
}

function track() {
  const rows = table()
  const mine = new Set([process.pid])
  // ps lists parents before children most of the time; loop until nothing new.
  for (let grew = true; grew; ) {
    grew = false
    for (const row of rows) {
      if (!mine.has(row.pid) && mine.has(row.ppid)) {
        mine.add(row.pid)
        grew = true
      }
    }
  }
  for (const row of rows) {
    if (mine.has(row.pid) && row.pgid !== process.pid && row.pid === row.pgid && !subgroups.has(row.pgid)) {
      subgroups.set(row.pgid, row.started)
    }
  }
  return rows
}

function signalAll(signal) {
  const rows = track()
  for (const [pgid, started] of subgroups) {
    const leader = rows.find((row) => row.pid === pgid)
    // The leader may be gone while the rest of its group lives on: still ours if any member is.
    if (leader && leader.started !== started) continue
    if (!leader && !rows.some((row) => row.pgid === pgid)) continue
    try {
      process.kill(-pgid, signal)
    } catch {}
  }
  try {
    process.kill(-process.pid, signal)
  } catch {}
}

function othersAlive() {
  const rows = table()
  return rows.some(
    (row) => row.pid !== process.pid && (row.pgid === process.pid || (subgroups.has(row.pgid) && (row.pid !== row.pgid || subgroups.get(row.pgid) === row.started))),
  )
}

let stopping = null
// SIGTERM to everything, SIGKILL to whatever is left after 6 s.
function stopAll() {
  stopping ??= (async () => {
    signalAll('SIGTERM')
    for (let i = 0; i < 24 && othersAlive(); i++) await sleep(250)
    if (othersAlive()) {
      // This process ignores SIGTERM but not SIGKILL: spare it so the exit code gets out.
      for (const [pgid] of subgroups) {
        try {
          process.kill(-pgid, 'SIGKILL')
        } catch {}
      }
      for (const row of table()) {
        if (row.pgid === process.pid && row.pid !== process.pid) {
          try {
            process.kill(row.pid, 'SIGKILL')
          } catch {}
        }
      }
    }
  })()
  return stopping
}

// run.mjs signals the whole group: stop everything, then exit with the command's code.
for (const signal of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.on(signal, () => stopAll())

const child = spawn(command, args, { stdio: 'inherit' })

function parentAlive() {
  try {
    process.kill(parent, 0)
  } catch {
    return false
  }
  return process.ppid === parent
}

// The files run.mjs would have removed: generated ones, and its machine slot if still its.
function cleanUpForParent() {
  for (const file of JSON.parse(process.env.E2E_GROUP_CLEANUP ?? '[]')) {
    try {
      if (file.endsWith('.lock') && JSON.parse(readFileSync(file, 'utf8')).pid !== parent) continue
      rmSync(file, { recursive: true, force: true })
    } catch {}
  }
}

const watch = setInterval(() => {
  track()
  if (stopping || parentAlive()) return
  console.error('[e2e] run.mjs sumiu: encerrando os emuladores e o Playwright')
  stopAll().then(() => {
    cleanUpForParent()
    process.exit(1)
  })
}, 1000)

child.on('error', (error) => {
  console.error(`[e2e] não deu para iniciar ${command}: ${error.message}`)
  process.exit(1)
})
child.on('exit', async (code, signal) => {
  clearInterval(watch)
  // Whatever the command left behind (a Chrome, a java) goes too.
  await stopAll()
  // run.mjs killed while this was shutting down: nobody else removes its files.
  if (!parentAlive()) cleanUpForParent()
  process.exit(code ?? (signal ? 128 + (constants.signals[signal] ?? 1) : 1))
})
