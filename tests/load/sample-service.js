// Load test for GET /work of the sample service. Run with k6.
//
// Environment variables:
//   BASE_URL          Required. Address of the service, for example http://localhost:8080. No default.
//   SCENARIO          Required. One of: smoke, baseline, ramp.
//   RATE              baseline only. Requests per second. Default 20.
//   DURATION          baseline only. How long to hold the rate. Default 10m.
//   STEPS             ramp only. Comma separated rates in requests per second. Default 10,20,40,80,160.
//   STEP_DURATION     ramp only. How long each step is held. Default 3m.
//   PRE_ALLOCATED_VUS Virtual users that k6 starts with. Default 50.
//   MAX_VUS           Most virtual users that k6 may use. Default 200.
import http from 'k6/http';
import { check } from 'k6';

const env = __ENV;

if (!env.BASE_URL) {
  throw new Error('BASE_URL is not set. Set it to the address of the service, for example http://localhost:8080.');
}
const baseUrl = env.BASE_URL.replace(/\/+$/, '');

const vus = {
  preAllocatedVUs: Number(env.PRE_ALLOCATED_VUS || 50),
  maxVUs: Number(env.MAX_VUS || 200),
};

function rampStages() {
  const steps = (env.STEPS || '10,20,40,80,160').split(',').map((s) => Number(s.trim()));
  if (steps.some((s) => !Number.isFinite(s) || s <= 0)) {
    throw new Error('STEPS must be comma separated rates greater than 0, for example 10,20,40.');
  }
  const hold = env.STEP_DURATION || '3m';
  const stages = [];
  for (const rate of steps) {
    stages.push({ target: rate, duration: '30s' });
    stages.push({ target: rate, duration: hold });
  }
  return { steps, stages };
}

function scenarios() {
  switch (env.SCENARIO) {
    case 'smoke':
      return {
        smoke: { executor: 'constant-arrival-rate', rate: 5, timeUnit: '1s', duration: '10s', ...vus },
      };
    case 'baseline':
      return {
        baseline: {
          executor: 'constant-arrival-rate',
          rate: Number(env.RATE || 20),
          timeUnit: '1s',
          duration: env.DURATION || '10m',
          ...vus,
        },
      };
    case 'ramp': {
      const { steps, stages } = rampStages();
      return {
        ramp: { executor: 'ramping-arrival-rate', startRate: steps[0], timeUnit: '1s', stages, ...vus },
      };
    }
    default:
      throw new Error(`SCENARIO is "${env.SCENARIO || ''}". Valid names are: smoke, baseline, ramp.`);
  }
}

export const options = {
  scenarios: scenarios(),
  // These mirror the SLOs in docs/slos.md. They are reported and do not stop the run.
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<500'],
  },
};

export default function () {
  const res = http.get(`${baseUrl}/work`, { tags: { route: '/work' } });
  check(res, { 'status is 200': (r) => r.status === 200 });
}
