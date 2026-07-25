// k6 load test for Le Cinque's game hot path (TypeScript).
//
// k6 runs .ts directly — it transpiles with esbuild (types are stripped, not
// type-checked), so no build step and no npm install are needed.
//
// Each virtual user (VU) plays as a stable guest. The server's Player
// middleware accepts ANY value in the "player" cookie, so we send our own and
// skip login entirely — no session, no Secure-cookie-over-http problem.
//
// The endpoint under the microscope is GET /game. One call runs BOTH of the
// queries that lack an index today:
//   latest()   -> SELECT ... FROM games   WHERE username = $1 ORDER BY id DESC
//   attempts() -> SELECT guess FROM guesses WHERE game_id  = $1
// Watch the "GET /game" p95 line in the summary before vs. after adding indexes.
//
// Run (seed the DB first — see README.md):
//   k6 run loadtest/play.ts
//   k6 run -e BASE=http://localhost:8080 loadtest/play.ts
//   k6 run -e VUS=3 -e DURATION=3s loadtest/play.ts     # quick smoke test

import http from 'k6/http';
import { check, sleep } from 'k6';

// k6 injects these globals at runtime; declare them so the file is valid
// standalone TypeScript without pulling in @types/k6.
declare const __ENV: Record<string, string>;
declare const __VU: number;
declare const __ITER: number;

type Params = { headers: Record<string, string>; tags?: Record<string, string> };

const BASE: string = __ENV.BASE ?? 'http://localhost:8080';
const VUS: number = Number(__ENV.VUS ?? '20');
const HOLD: string = __ENV.DURATION ?? '30s';

export const options = {
  scenarios: {
    play: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '5s', target: VUS }, // ramp up
        { duration: HOLD, target: VUS }, // hold
        { duration: '3s', target: 0 }, // ramp down
      ],
    },
  },
  thresholds: {
    // the number that matters: read-path latency. Compare it across runs.
    'http_req_duration{name:GET /game}': ['p(95)<200'],
  },
};

export default function (): void {
  const player = `loadtest_vu_${__VU}`;
  const headers = { 'Content-Type': 'application/json', Cookie: `player=${player}` };
  // tag each call so its latency is reported on its own line
  const read: Params = { headers, tags: { name: 'GET /game' } };
  const create: Params = { headers, tags: { name: 'POST /game' } };
  const write: Params = { headers, tags: { name: 'POST /guess' } };

  // GET /game — resumes the round, or deals one on a VU's first visit. This is
  // the call we measure: it runs both un-indexed queries.
  let res = http.get(`${BASE}/game`, read);
  check(res, { 'game loaded': (r) => r.status === 200 });

  let status = 'playing';
  try {
    status = String(res.json('status'));
  } catch {
    /* non-JSON error body */
  }

  // when the previous round has finished, start a fresh one so the VU keeps going
  if (status !== 'playing') {
    res = http.post(`${BASE}/game`, null, create);
    try {
      status = String(res.json('status'));
    } catch {
      /* ignore */
    }
  }

  // one guess per iteration grows the guesses table without ending the round
  // too quickly (MaxMisses is 5). A 400/409 here is expected and fine.
  if (status === 'playing') {
    const body = JSON.stringify({
      guess: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'[__ITER % 26],
      word: __ITER % 5,
      position: __ITER % 4,
    });
    const g = http.post(`${BASE}/game/guess`, body, write);
    check(g, { 'guess handled': (r) => r.status === 200 || r.status === 400 || r.status === 409 });
  }

  sleep(0.1);
}
