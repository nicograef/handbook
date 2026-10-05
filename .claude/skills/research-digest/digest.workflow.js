export const meta = {
  name: 'research-digest',
  description: 'Sweep the web since the last issue, read the best items in full, judge them against the project and write the issue.',
  whenToUse: 'Once per issue of the research-digest skill, with {today, since, repo, agent, out, covered, urls?} as args.',
  phases: [
    { title: 'Brief', detail: 'the project and its open problems, off the tree', model: 'opus' },
    { title: 'Discover', detail: 'one lane per topic line of the project agent', model: 'sonnet' },
    { title: 'Read', detail: 'full text, critique, applicability per item', model: 'opus' },
    { title: 'Skeptic', detail: 'every applicability claim against the code', model: 'opus' },
    { title: 'Write', detail: 'the issue file', model: 'opus' },
  ],
}

// One issue of the research digest (SKILL.md beside this file). Every agent runs as the project's
// researcher agent, whose definition carries the topics, rulings and brief sources. Today and the
// window arrive in `args`: a script that read the clock could not replay from its journal.

const { today, since, repo, agent: agentType, out } = args
const covered = args.covered || []
const ownerUrls = args.urls || []

// Reading is the expensive stage, so discovery is cut to a cap and the cut is logged and listed
// in the issue's skipped section. Owner URLs are exempt from the cap.
const READ_CAP = 12
const BATCH = 4

const ROUTES = 'Read ~/.claude/skills/research-digest/sources.md first: it says how each source family is found and read.'
const WINDOW = `The window is ${since} to ${today}: an item published or released before ${since} is out of it.`
const READ_ONLY = [
  `The repository is at ${repo}; run every command from there.`,
  'READ ONLY: write no file in the repository, make no commit, call no paid provider API, run nothing',
  'that spends. /tmp is yours for downloads. Quote what a claim stands on.',
  '"Nothing relevant" is a complete answer; a manufactured one is not.',
].join(' ')

const BRIEF_SCHEMA = {
  type: 'object',
  properties: {
    stack: { type: 'string', description: 'the stack as the tree has it: store, search, models, pipeline, evaluation' },
    open_problems: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          problem: { type: 'string' },
          locus: { type: 'string', description: 'the doc, plan or module path where it stands' },
        },
        required: ['problem', 'locus'],
      },
    },
    lanes: {
      type: 'array',
      description: 'one per topic line of your agent definition, at most four',
      items: {
        type: 'object',
        properties: { key: { type: 'string' }, focus: { type: 'string', description: 'what this lane sweeps and where' } },
        required: ['key', 'focus'],
      },
    },
    watch_terms: { type: 'array', items: { type: 'string' }, description: 'search terms that would surface work on the open problems' },
  },
  required: ['stack', 'open_problems', 'lanes', 'watch_terms'],
}

const CANDIDATES_SCHEMA = {
  type: 'object',
  properties: {
    items: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          url: { type: 'string', description: 'the canonical page: arXiv abs URL, release URL, article URL' },
          title: { type: 'string' },
          published: { type: 'string', description: 'YYYY-MM-DD, empty when the page gives none' },
          kind: { type: 'string', enum: ['paper', 'release', 'blog', 'news', 'market', 'docs'] },
          topic: { type: 'string' },
          why: { type: 'string', description: 'one sentence: why the project might care' },
          priority: { type: 'string', enum: ['high', 'medium', 'low'] },
        },
        required: ['url', 'title', 'published', 'kind', 'topic', 'why', 'priority'],
      },
    },
    routes: {
      type: 'array',
      items: {
        type: 'object',
        properties: { route: { type: 'string' }, worked: { type: 'boolean' }, note: { type: 'string' } },
        required: ['route', 'worked', 'note'],
      },
    },
  },
  required: ['items', 'routes'],
}

const READ_SCHEMA = {
  type: 'object',
  properties: {
    items: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          url: { type: 'string' },
          title: { type: 'string' },
          published: { type: 'string' },
          source: { type: 'string', description: 'authors, lab or vendor' },
          read_as: { type: 'string', enum: ['full-html', 'full-pdf', 'full-page', 'abstract-only', 'unreadable'] },
          summary: { type: 'string', description: 'one paragraph: what it does and what it measured' },
          critique: { type: 'string', description: 'baselines, noise, benchmark fit, what is missing; each claim labelled fact, inference or guess' },
          applicability: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                claim: { type: 'string', description: 'what this would change or confirm in the project' },
                locus: { type: 'string', description: 'the repo path it touches' },
                label: { type: 'string', enum: ['fact', 'inference', 'guess'] },
              },
              required: ['claim', 'locus', 'label'],
            },
          },
          relevance: { type: 'string', enum: ['none', 'low', 'medium', 'high'] },
          learn: { type: 'string', description: 'the concept worth understanding from it, empty when none' },
          skip_reason: { type: 'string', description: 'set when unreadable or out of scope' },
        },
        required: ['url', 'title', 'read_as', 'summary', 'critique', 'applicability', 'relevance', 'learn'],
      },
    },
  },
  required: ['items'],
}

const SKEPTIC_SCHEMA = {
  type: 'object',
  properties: {
    checks: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          url: { type: 'string' },
          claim: { type: 'string' },
          verdict: { type: 'string', enum: ['holds', 'overstated', 'wrong', 'already-in-project', 'conflicts-with-ruling'] },
          evidence: { type: 'string', description: 'file:line and the quoted line the verdict rests on' },
          relevance: { type: 'string', enum: ['none', 'low', 'medium', 'high'] },
        },
        required: ['url', 'claim', 'verdict', 'evidence', 'relevance'],
      },
    },
  },
  required: ['checks'],
}

// One key per document, so the same paper reached as abs, html or pdf, any version, is one item.
const canon = (url) => {
  const u = String(url).trim().replace(/#.*$/, '').replace(/^https?:\/\//i, '').replace(/^www\./i, '')
  const arxiv = u.match(/^(?:export\.)?arxiv\.org\/(?:abs|html|pdf)\/([0-9]{4}\.[0-9]{4,5})(?:v[0-9]+)?(?:\.pdf)?\/?$/i)
  if (arxiv) return `arxiv:${arxiv[1]}`
  return u.replace(/\/+$/, '').toLowerCase()
}

phase('Brief')
const brief = await agent(
  [
    READ_ONLY,
    'Write the brief every later reader of this digest judges against. Read what the Brief section of',
    'your agent definition names, and `git log --oneline -40`. Name the stack as the code has it and',
    'the open problems with the path where each stands. Turn each line of your Topics section into a',
    'discovery lane. Then the search terms that would surface outside work on the open problems.',
  ].join('\n'),
  { label: 'brief', model: 'opus', agentType, schema: BRIEF_SCHEMA },
)
if (!brief) return { aborted: 'brief' }

const LANES = brief.lanes.slice(0, 4)
const BRIEF = [
  'THE PROJECT, as the tree has it:',
  brief.stack,
  'Open problems:',
  ...brief.open_problems.map((p) => `- ${p.problem} (${p.locus})`),
].join('\n')

phase('Discover')
const lanes = await parallel(
  LANES.map((lane) => () =>
    agent(
      [
        READ_ONLY,
        `You are the ${lane.key} discovery lane of a research digest. ${WINDOW}`,
        lane.focus,
        `Terms tied to the open problems: ${brief.watch_terms.join('; ')}.`,
        'Search widely: the routes in sources.md, WebSearch in every language the project works in, the',
        'pages they link. Return candidates, not readings: the canonical URL, its date, and one sentence',
        'on why the project might care. Priority high means it bears on an open problem or the stack',
        'directly. Skip SEO listicles, vendor pages without substance and anything outside the window.',
        'Report each route you tried and whether it answered.',
        '',
        BRIEF,
        '',
        ROUTES,
      ].join('\n'),
      { label: `discover:${lane.key}`, phase: 'Discover', model: 'sonnet', agentType, schema: CANDIDATES_SCHEMA },
    ),
  ),
)

// Barrier: the dedup needs every lane's candidates at once.
const seen = new Set(covered.map(canon))
const owner = []
for (const url of ownerUrls) {
  const key = canon(url)
  if (owner.some((o) => o.key === key)) continue
  owner.push({ key, url, title: '', published: '', kind: 'owner', topic: 'owner', why: 'named by the owner', priority: 'high' })
}
owner.forEach((o) => seen.add(o.key))

const skipped = []
const routes = []
const pools = { high: [], medium: [], low: [] }
lanes.forEach((result, i) => {
  if (!result) {
    log(`discovery lane ${LANES[i].key} died; its family is unswept this issue`)
    routes.push({ route: `lane ${LANES[i].key}`, worked: false, note: 'the lane died' })
    return
  }
  routes.push(...result.routes.map((r) => ({ ...r, route: `${LANES[i].key}: ${r.route}` })))
  for (const item of result.items) {
    const key = canon(item.url)
    if (seen.has(key)) continue
    seen.add(key)
    if (item.published && item.published < since) {
      skipped.push({ url: item.url, title: item.title, reason: `published ${item.published}, before the window` })
      continue
    }
    pools[item.priority].push({ ...item, key, lane: LANES[i].key })
  }
})

// Interleave the lanes inside each priority so the cap never fills from one family alone.
const interleave = (items) => {
  const byLane = LANES.map((l) => items.filter((it) => it.lane === l.key))
  const picked = []
  for (let i = 0; byLane.some((b) => i < b.length); i++) byLane.forEach((b) => i < b.length && picked.push(b[i]))
  return picked
}
const ranked = [...interleave(pools.high), ...interleave(pools.medium), ...interleave(pools.low)]
const chosen = ranked.slice(0, READ_CAP)
const capped = ranked.slice(READ_CAP)
capped.forEach((it) => skipped.push({ url: it.url, title: it.title, reason: `over the reading cap (priority ${it.priority}); pass it as an owner URL to read it` }))
log(`discovered ${ranked.length} new candidates; reading ${chosen.length} plus ${owner.length} owner URLs; ${capped.length} over the cap, ${skipped.length - capped.length} outside the window`)

const toRead = [...owner, ...chosen]
if (!toRead.length) log('nothing new to read; the issue reports an empty window')
const batches = []
for (let i = 0; i < toRead.length; i += BATCH) batches.push(toRead.slice(i, i + BATCH))

phase('Read')
const readResults = await parallel(
  batches.map((batch, b) => () =>
    agent(
      [
        READ_ONLY,
        'You are a deep reader for a research digest. Read each item below IN FULL by the routes in',
        'sources.md: the paper, not its abstract; the release notes, not the headline. Then, per item:',
        '- summary: one paragraph on what it does and what it measured, with the numbers that matter;',
        '- critique: are the baselines current, tuned and fair; is the gain outside noise; does the',
        "  benchmark resemble the project's data; what is missing; label each claim fact (quoted),",
        '  inference or guess;',
        '- applicability: what it would change or confirm in the project, each with the repo path it',
        '  touches, found by reading that code. Judge against the brief and your Rulings section;',
        '- relevance per your Judging section;',
        '- learn: the concept worth understanding from it, if any.',
        'An item you cannot read gets read_as "unreadable" and a skip_reason naming the route that failed.',
        '',
        BRIEF,
        '',
        ROUTES,
        '',
        'ITEMS:',
        ...batch.map((it) => `- ${it.url}${it.title ? ` | ${it.title}` : ''}${it.published ? ` | ${it.published}` : ''} | ${it.why}`),
      ].join('\n'),
      { label: `read:${b + 1}`, phase: 'Read', model: 'opus', agentType, schema: READ_SCHEMA },
    ),
  ),
)
const read = []
readResults.forEach((r, b) => {
  if (!r) {
    log(`reader ${b + 1} died; its items go to skipped`)
    batches[b].forEach((it) => skipped.push({ url: it.url, title: it.title, reason: 'the reader died' }))
    return
  }
  for (const item of r.items) {
    if (item.read_as === 'unreadable') skipped.push({ url: item.url, title: item.title, reason: item.skip_reason || 'unreadable' })
    else read.push(item)
  }
})

phase('Skeptic')
const claims = read.filter((it) => it.relevance !== 'none' && it.applicability.length)
const skeptic = claims.length
  ? await agent(
      [
        READ_ONLY,
        'You are the skeptic of a research digest. Each claim below says an outside item would change or',
        'confirm something in the project. Try to refute every one against the code: open the path it',
        'names and what that path calls, and quote the line your verdict rests on.',
        '- holds: the code has the gap or the fit the claim says;',
        '- overstated: a real fit, smaller than claimed;',
        '- wrong: the code does not work the way the claim assumes;',
        '- already-in-project: the tree does this already;',
        '- conflicts-with-ruling: it would loosen an invariant or a ruling of your agent definition.',
        'Default to overstated when the code does not settle it. Set the relevance the item deserves.',
        '',
        'CLAIMS:',
        JSON.stringify(claims.map((it) => ({ url: it.url, title: it.title, relevance: it.relevance, applicability: it.applicability })), null, 1),
      ].join('\n'),
      { label: 'skeptic', phase: 'Skeptic', model: 'opus', agentType, schema: SKEPTIC_SCHEMA },
    )
  : { checks: [] }
if (!skeptic) log('the skeptic died; the issue marks every applicability claim unverified')

phase('Write')
const written = await agent(
  [
    `The repository is at ${repo}. Write exactly one file, ${out} (create its directory if absent;`,
    'overwrite a file of the same day), and touch nothing else. Commit nothing.',
    '',
    `Write issue ${today} of the research digest, a newsletter for the project's developer, who reads it`,
    `to keep up and to learn. Window: ${since} to ${today}. English; short sentences; every item links its source.`,
    'Structure, in this order:',
    `1. "# Research digest — ${today}", then one line: the window and what was swept.`,
    '2. "## What matters": at most five bullets, highest verified relevance first, each one sentence,',
    '   its next step and a link to its entry below. Only items whose claims the skeptic let stand.',
    '3. "## Items", grouped by topic: per item "### <title>", then the link, date, source, how it was',
    '   read, relevance; a one-paragraph summary; "Critique:"; "For the project:" with each claim, its',
    '   path and the skeptic verdict and evidence (a claim the skeptic did not check reads',
    '   "unverified"). Use the skeptic relevance where it differs from the reader.',
    '4. "## Learn": a reading path from foundations to frontier, each concept with its best link.',
    '5. "## Skipped": every skipped URL with its reason.',
    '6. "## Sources health": routes that failed or answered oddly, one line each.',
    'Keep the fact, inference and guess labels the readers gave. Add nothing the material below does',
    'not carry. Return the path and the headline bullets.',
    '',
    'READ ITEMS:',
    JSON.stringify(read, null, 1),
    '',
    'SKEPTIC:',
    JSON.stringify(skeptic ? skeptic.checks : 'the skeptic died: every claim is unverified', null, 1),
    '',
    'SKIPPED:',
    JSON.stringify(skipped, null, 1),
    '',
    'ROUTES:',
    JSON.stringify(routes.filter((r) => !r.worked || r.note), null, 1),
  ].join('\n'),
  { label: 'writer', phase: 'Write', model: 'opus', agentType },
)

return { path: out, headlines: written, read: read.length, skipped: skipped.length }
