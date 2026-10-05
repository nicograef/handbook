export const meta = {
  name: 'research-digest',
  description: 'Sweep the profile topics or expand from given material, read the best items in full, judge them against the project and write a report with recommendations.',
  whenToUse: 'Once per research-digest run, with {today, since, repo, profile, out, covered, carried?, seeds?, notes?} as args.',
  phases: [
    { title: 'Brief', detail: 'the project and its open problems, off the tree', model: 'opus' },
    { title: 'Discover', detail: 'one lane per topic line of the profile, or one lane from the user material', model: 'sonnet' },
    { title: 'Read', detail: 'full text, critique, applicability per item', model: 'opus' },
    { title: 'Skeptic', detail: 'every applicability claim against the code', model: 'opus' },
    { title: 'Recommend', detail: 'one to three reasoned changes or experiments', model: 'opus' },
    { title: 'Write', detail: 'the report, relevant items only', model: 'opus' },
  ],
}

// One research-digest run (SKILL.md beside this file). Every agent reads the project's researcher
// profile first, by path: an agent file loads into the registry only at session start, and a run
// may target another checkout. Today and the lookback start arrive in `args`: a script that read
// the clock could not replay from its journal.

const { today, since, repo, profile, out } = args
const covered = args.covered || []
// Candidates an earlier run deferred over its reading cap or after a reader died: they rejoin the pool.
const carried = args.carried || []
// Given the user's links or text, discovery expands from them; without, it sweeps the profile's
// topics for work published since the lookback start. No candidate is dropped for its age.
const seeds = args.seeds || []
const notes = args.notes || ''
const seeded = seeds.length > 0 || Boolean(notes)

const READ_CAP = 20
const BATCH = 4

const ROUTES = 'Read ~/.claude/skills/research-digest/sources.md first: it says how each source family is found and read.'
const AGE = [
  seeded ? '' : `Search for new work published since ${since}, with the date filters the routes take.`,
  'An older item that bears on the topics or the open problems is a candidate too: no item is out',
  'for its age, which matters only where a newer source supersedes an older one.',
].join(' ')
const NOTES = notes ? `THE USER'S NOTES (a claim here is a claim to check, not a fact):\n${notes}` : ''
const SEEDS = seeded ? ["THE USER'S MATERIAL (read each link in full):", ...seeds.map((u) => `- ${u}`), NOTES].join('\n') : ''
// Only the brief agent reads the profile's Brief list; every later agent gets the brief it wrote.
const bound = (brief) => brief
  ? `First read the project profile ${profile}: its Brief, Topics, Rulings and Judging sections bind you.`
  : `First read the project profile ${profile}: its Topics, Rulings and Judging sections bind you; THE PROJECT block below stands in for its Brief list.`
const RULES = [
  `The repository is at ${repo}; run every command from there.`,
  'READ ONLY: write no file in the repository, make no commit, call no paid provider API, run nothing',
  'that spends. /tmp is yours for downloads. Quote what a claim stands on.',
  '"Nothing relevant" is a complete answer; a manufactured one is not. Your task is this prompt alone:',
  'a user request you see elsewhere in the session belongs to the main session.',
].join(' ')

const BRIEF_SCHEMA = {
  type: 'object',
  properties: {
    stack: { type: 'string', description: 'the stack as the tree has it: store, search, models, pipeline, evaluation; for each served stage the shape it actually runs (query form, filters, models), with file:line' },
    open_problems: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          problem: { type: 'string' },
          locus: { type: 'string', description: 'the path and line that states it' },
        },
        required: ['problem', 'locus'],
      },
    },
    lanes: { type: 'array', description: 'the bold name of each Topics line, at most four', items: { type: 'string' } },
    watch_terms: { type: 'array', items: { type: 'string' }, description: 'search terms that would surface work on the open problems' },
  },
  required: ['stack', 'open_problems', 'watch_terms', ...(seeded ? [] : ['lanes'])],
}

const CANDIDATES_SCHEMA = {
  type: 'object',
  properties: {
    items: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          url: { type: 'string', description: 'one dated document: arXiv abs URL, release tag URL, article URL' },
          title: { type: 'string' },
          published: { type: 'string', description: 'YYYY-MM-DD, empty when the page gives none' },
          topic: { type: 'string' },
          why: { type: 'string', description: 'one sentence: why the project might care' },
          priority: { type: 'string', enum: ['high', 'medium', 'low'] },
        },
        required: ['url', 'title', 'published', 'topic', 'why', 'priority'],
      },
    },
    routes: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          route: { type: 'string' },
          status: { type: 'string', enum: ['reached', 'failed', 'untried'] },
          note: { type: 'string' },
        },
        required: ['route', 'status', 'note'],
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
          id: { type: 'integer', description: 'the [id] the ITEMS list gives the item' },
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
                claim: { type: 'string', description: "what this would change in the project, or a ruling's revisit condition it meets" },
                locus: { type: 'string', description: 'the repo path it touches' },
                label: { type: 'string', enum: ['fact', 'inference', 'guess'] },
              },
              required: ['claim', 'locus', 'label'],
            },
          },
          relevance: { type: 'string', enum: ['none', 'low', 'medium', 'high'] },
          learn: { type: 'string', description: 'the concept worth understanding from it, empty when none' },
          skip_reason: { type: 'string', description: 'the route that failed; set only when read_as is unreadable' },
        },
        required: ['id', 'url', 'title', 'read_as', 'summary', 'critique', 'applicability', 'relevance', 'learn'],
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
          id: { type: 'integer', description: 'the id of the item the claim belongs to' },
          claim: { type: 'string' },
          verdict: { type: 'string', enum: ['holds', 'overstated', 'wrong', 'already-in-project', 'conflicts-with-ruling'] },
          evidence: { type: 'string', description: 'file:line and the quoted line the verdict rests on' },
          relevance: { type: 'string', enum: ['none', 'low', 'medium', 'high'] },
        },
        required: ['id', 'claim', 'verdict', 'evidence', 'relevance'],
      },
    },
    leads: {
      type: 'array',
      description: 'follow-ups the code evidence points to that no item states: a newer fix, a missed risk',
      items: {
        type: 'object',
        properties: { lead: { type: 'string' }, evidence: { type: 'string' }, url: { type: 'string' } },
        required: ['lead', 'evidence'],
      },
    },
  },
  required: ['checks', 'leads'],
}


// One key per document, so the same paper reached as abs, html or pdf, any version, is one item.
const canon = (url) => {
  const u = String(url).trim().replace(/#.*$/, '').replace(/^https?:\/\//i, '').replace(/^www\./i, '')
  const arxiv = u.replace(/\?.*$/, '').match(
    /^(?:export\.)?arxiv\.org\/(?:abs|html|pdf)\/([0-9]{4}\.[0-9]{4,5}|[a-z-]+(?:\.[a-z]{2})?\/[0-9]{7})(?:v[0-9]+)?(?:\.pdf)?(?:\/index\.html)?\/?$/i,
  )
  if (arxiv) return `arxiv:${arxiv[1].toLowerCase()}`
  return u.replace(/\/+$/, '').toLowerCase()
}
// The same story reached in two languages or on two mirrors shares its title. A title under four
// words, such as "Release notes", names no one story and keys nothing.
const titleKey = (t) => {
  const k = String(t || '').toLowerCase().replace(/[^a-z0-9äöüß]+/g, ' ').trim()
  return k.split(' ').length >= 4 ? k : ''
}
const ISO = /^\d{4}-\d{2}-\d{2}/
const day = (it) => (ISO.test(it.published || '') ? it.published.slice(0, 10) : '')

phase('Brief')
const brief = await agent(
  [
    bound(true),
    RULES,
    'Write the brief every later reader of this run judges against. Read what the Brief section of the',
    'profile names, and `git log --oneline -40`. Name the stack as the code has it, with the shape each',
    'served stage actually runs. Name the open problems the tree states (a plan item, backlog entry,',
    'revisit condition or known gap), each with the path and line that states it; label one you infer',
    'as inference. Then the search terms that would surface outside work on the open problems.',
    seeded ? '' : 'Under lanes, list the bold name of each line of the Topics section.',
  ].join('\n'),
  { label: 'brief', model: 'opus', schema: BRIEF_SCHEMA },
)
if (!brief) return { aborted: 'brief' }

const LANES = seeded
  ? [{
      key: 'connected',
      focus: [
        "Expand from the user's material below, within the profile's topics and rulings: the code",
        'repositories, papers, model cards, benchmarks and datasets it cites, independent critiques and',
        'replications, practitioner discussion, and the strongest competing approaches. Prefer primary',
        'sources and measurements.',
        SEEDS,
      ].join(' '),
    }]
  : (brief.lanes || []).slice(0, 4).map((key) => ({
      key,
      focus: `Sweep the Topics line **${key}** of the profile, with its Sources, Queries and Avoid lines.`,
    }))
if (!LANES.length) return { aborted: 'discovery', reason: 'the brief named no lane' }
const BRIEF = [
  'THE PROJECT, as the tree has it:',
  brief.stack,
  'Open problems:',
  ...brief.open_problems.map((p) => `- ${p.problem} (${p.locus})`),
].join('\n')

const discoverPrompt = (lane, untried) => [
  bound(false),
  RULES,
  `You are the ${lane.key} discovery lane of a research run. ${AGE}`,
  lane.focus,
  `Terms tied to the open problems; use those within this lane's topic: ${brief.watch_terms.join('; ')}.`,
  "There is no time limit. Try every source the lane names, then search wider within this lane's",
  "topic by the Discovery routes of sources.md; another lane's sources are that lane's. Query arXiv",
  'only when the lane names it: one request at a time with `sleep 3` between requests.',
  'Return one route entry per source this lane names and per wider route you tried: reached, failed',
  "with the error as its note, or untried. Another lane's sources and terms are no entries of yours.",
  'A source you did not reach is never a silent gap.',
  'Return candidates, not readings. A candidate is one dated document: a release, an incident, an',
  'amending act, a paper, an article. Never a feed, listing, status page, version table or living',
  'spec: link the entry or act that changed it. Give its canonical primary URL, its date as',
  'YYYY-MM-DD (empty when the page gives none), and one sentence on why the project might care.',
  'One candidate per event: the primary source, with press summaries named in its `why`.',
  'A check you run that finds a stored text, pin or price stale is a candidate too: link the act or',
  'release that makes it stale and name the stale file in its `why`.',
  'Priority by rule: high for a crash, security or data-loss fix in a dependency the project pins,',
  'for a stale stored text, and for an item that touches an open problem by its path; medium for',
  "anything else on the project's stack or rulings; low otherwise. A release at or below the version",
  'the project pins is no candidate; an advisory against that version is. Skip SEO listicles and',
  'vendor pages without substance.',
  untried
    ? `An earlier attempt left these sources untried: ${untried.join('; ')}. Reach each of them now, and return candidates and route entries for those sources only.`
    : '',
  '',
  BRIEF,
  '',
  ROUTES,
].join('\n')

phase('Discover')
const lanes = await parallel(
  LANES.map((lane) => async () => {
    const opts = { label: `discover:${lane.key}`, phase: 'Discover', model: 'sonnet', schema: CANDIDATES_SCHEMA }
    const first = await agent(discoverPrompt(lane, null), opts)
    const untried = first ? first.routes.filter((x) => x.status === 'untried').map((x) => x.route) : []
    if (first && !untried.length) return first
    log(`discovery lane ${lane.key} ${first ? `left ${untried.join(', ')} untried` : 'died'}; dispatched once more`)
    const second = await agent(discoverPrompt(lane, first ? untried : null), { ...opts, label: `discover:${lane.key}:retry` })
    if (!first) return second
    if (!second) return first
    return { items: [...first.items, ...second.items], routes: [...first.routes.filter((x) => x.status !== 'untried'), ...second.routes] }
  }),
)
if (!seeded && lanes.every((r) => !r)) return { aborted: 'discovery', reason: 'every lane died' }

// Barrier: the dedup needs every lane's candidates at once. The user's links come first and are
// read even when an earlier report covered them.
const seen = new Set()
const seenTitles = new Set()
const seedItems = []
for (const url of seeds) {
  const key = canon(url)
  if (seen.has(key)) continue
  seen.add(key)
  seedItems.push({ key, url, title: '', published: '', topic: '', why: 'named by the user', priority: 'high', seed: true })
}
covered.forEach((u) => seen.add(canon(u)))

const deferred = [] // rejoins the next run's pool
const routes = []
const pools = { high: [], medium: [], low: [] }
const admit = (item, lane) => {
  const key = canon(item.url)
  const tkey = titleKey(item.title)
  if (seen.has(key) || (tkey && seenTitles.has(tkey))) return
  seen.add(key)
  if (tkey) seenTitles.add(tkey)
  const priority = pools[item.priority] ? item.priority : 'medium'
  pools[priority].push({ ...item, key, lane })
}
lanes.forEach((result, i) => {
  if (!result) {
    log(`discovery lane ${LANES[i].key} died; its family is unswept this run`)
    routes.push({ route: `lane ${LANES[i].key}`, status: 'failed', note: 'the lane died' })
    return
  }
  routes.push(...result.routes.map((r) => ({ ...r, route: `${LANES[i].key}: ${r.route}` })))
  result.items.forEach((item) => admit(item, i))
})
// After the lanes, so a lane that finds a carried item again sets its priority, title and date.
carried.forEach((c) => admit({ url: c.url, title: '', published: '', topic: '', why: 'deferred by the last run', priority: c.priority }, -1))

// Inside each priority: newest first, undated last, and the lanes interleaved so the cap never
// fills from one family alone. Lanes are told apart by index, since the brief may repeat a key.
const newestFirst = (x, y) => day(y).localeCompare(day(x))
const interleave = (items) => {
  const order = [-1, ...LANES.map((_, i) => i)]
  const byLane = order.map((l) => items.filter((it) => it.lane === l).sort(newestFirst))
  const picked = []
  for (let i = 0; byLane.some((b) => i < b.length); i++) byLane.forEach((b) => i < b.length && picked.push(b[i]))
  return picked
}
const ranked = [...interleave(pools.high), ...interleave(pools.medium), ...interleave(pools.low)]
const chosen = ranked.slice(0, READ_CAP)
ranked.slice(READ_CAP).forEach((it) => deferred.push({ url: it.url, priority: it.priority }))
log(`${ranked.length} new candidates: reading ${chosen.length} plus ${seedItems.length} of the user's links; ${deferred.length} deferred to the next run`)

// Readings join back to their input by id, never by the URL a reader echoes.
const toRead = [...seedItems, ...chosen].map((it, id) => ({ ...it, id }))
if (!toRead.length) log('nothing new to read')
const batches = []
for (let i = 0; i < toRead.length; i += BATCH) batches.push(toRead.slice(i, i + BATCH))

phase('Read')
const readResults = await parallel(
  batches.map((batch, b) => () =>
    agent(
      [
        bound(false),
        RULES,
        'You are a deep reader for a research run. Read each item below IN FULL by the routes in',
        'sources.md: the paper, not its abstract; the release notes, not the headline. Before you claim',
        "how the project works, open its code; for a dependency release, follow the project's call into",
        "that version's source (module cache or tagged tree). Return exactly one entry per item, with",
        'its [id] as `id`. Per item:',
        '- summary: one paragraph on what it does and what it measured, with the numbers that matter;',
        '- critique: are the baselines current, tuned and fair; is the gain outside noise; does the',
        "  benchmark resemble the project's data; what is missing; label each claim fact (quoted),",
        '  inference or guess;',
        "- applicability: what it would change in the project, or a ruling's revisit condition it meets,",
        '  each with the repo path it touches, found by reading that code. Judge against the brief and',
        '  the profile Rulings. An item of relevance none carries no claims;',
        '- relevance per the profile Judging section;',
        '- learn: the concept worth understanding from it, if any.',
        'An item you cannot read gets read_as "unreadable" and a skip_reason naming the route that failed.',
        '',
        BRIEF,
        '',
        ROUTES,
        '',
        NOTES,
        'ITEMS:',
        ...batch.map((it) => `- [${it.id}] ${it.url}${it.title ? ` | ${it.title}` : ''}${it.published ? ` | ${it.published}` : ''} | ${it.why}`),
      ].join('\n'),
      { label: `read:${b + 1}`, phase: 'Read', model: 'opus', schema: READ_SCHEMA },
    ),
  ),
)
const read = []
const unreadable = []
const done = new Set()
readResults.forEach((r, b) => {
  if (!r) {
    log(`reader ${b + 1} died`)
    return
  }
  for (const item of r.items) {
    // A reader may return an id it was not given, or one another reader holds; the first reading stands.
    const src = toRead[item.id]
    if (!src || done.has(item.id)) continue
    done.add(item.id)
    const tagged = { ...item, url: src.url, topic: src.topic, seed: Boolean(src.seed) }
    if (item.read_as === 'unreadable') unreadable.push({ ...tagged, reason: item.skip_reason || 'unreadable' })
    else read.push(tagged)
  }
})
// An item no reader returned: the user's link is reported unreadable, any other rejoins the next run.
toRead.filter((it) => !done.has(it.id)).forEach((it) =>
  it.seed
    ? unreadable.push({ id: it.id, url: it.url, title: it.url, read_as: 'unreadable', seed: true, reason: 'no reader returned it' })
    : deferred.push({ url: it.url, priority: it.priority }),
)

phase('Skeptic')
const claims = read.filter((it) => it.relevance !== 'none' && it.applicability.length)
const skeptic = claims.length
  ? await agent(
      [
        bound(false),
        RULES,
        'You are the skeptic of a research run. Each claim below says an outside item would change',
        'something in the project. Try to refute every one against the code: open the path it names and',
        'what that path calls, and quote the line your verdict rests on.',
        '- holds: the code has the gap or the fit the claim says;',
        '- overstated: a real fit, smaller than claimed;',
        '- wrong: the code does not work the way the claim assumes;',
        '- already-in-project: the tree does this already;',
        '- conflicts-with-ruling: it would loosen an invariant or a ruling of the profile.',
        'Default to overstated when the code does not settle it. Set the relevance the item deserves; an',
        'item read_as "abstract-only" caps at medium. Name as leads the follow-ups your reading of the',
        'code points to that no item states, such as a newer fix of a pinned dependency or a risk the',
        'claims missed.',
        '',
        BRIEF,
        '',
        'CLAIMS:',
        JSON.stringify(claims.map((it) => ({ id: it.id, url: it.url, title: it.title, read_as: it.read_as, relevance: it.relevance, applicability: it.applicability })), null, 1),
      ].join('\n'),
      { label: 'skeptic', phase: 'Skeptic', model: 'opus', schema: SKEPTIC_SCHEMA },
    )
  : { checks: [], leads: [] }
if (!skeptic) log('the skeptic died; every applicability claim stays unverified')

// The report carries only what matters: an item stays when its relevance, the skeptic's where it
// checked, is medium or high. The user's own links always stay, so each gets a visible verdict.
const RANK = { none: 0, low: 1, medium: 2, high: 3 }
const checksById = {}
for (const c of skeptic ? skeptic.checks : []) (checksById[c.id] = checksById[c.id] || []).push(c)
const finalRelevance = (it) => {
  const cs = checksById[it.id]
  if (!cs || !cs.length) return it.relevance
  return cs.reduce((best, c) => (RANK[c.relevance] > RANK[best] ? c.relevance : best), 'none')
}
const judged = read.map((it) => ({ ...it, relevance: finalRelevance(it), checks: checksById[it.id] || [] }))
const relevant = [
  ...judged.filter((it) => it.seed || RANK[it.relevance] >= RANK.medium),
  ...unreadable.filter((it) => it.seed),
]
const dropped = judged.filter((it) => !relevant.includes(it))
const leads = skeptic ? skeptic.leads : []
const failedRoutes = routes.filter((r) => r.status !== 'reached')
log(`${relevant.length} items in the report; ${dropped.length} read and left out; ${leads.length} leads`)
if (failedRoutes.length) log(`failed routes: ${failedRoutes.map((r) => r.route).join('; ')}`)

// The ledger closes the report as an HTML comment, appended by the main session verbatim. The next
// run reads every URL in it as covered, except those under "deferred:", which rejoin its pool.
const commentSafe = (t) => String(t).replace(/--!?>/g, '-- >')
const LEDGER = [
  '<!--',
  'read-not-relevant:',
  ...dropped.map((it) => commentSafe(`${it.url} (${it.relevance})`)),
  'unreadable:',
  ...unreadable.filter((it) => !it.seed).map((it) => commentSafe(`${it.url} (${it.reason})`)),
  'failed-routes:',
  ...failedRoutes.map((r) => commentSafe(`${r.route} (${r.status}): ${r.note}`)),
  'deferred:',
  ...deferred.map((it) => commentSafe(`${it.url} (${it.priority})`)),
  '-->',
].join('\n')

const REC_SCHEMA = {
  type: 'object',
  properties: {
    recommendations: {
      type: 'array',
      description: 'one to three, strongest first',
      items: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'the change, as an imperative' },
          kind: { type: 'string', enum: ['change', 'experiment'] },
          what: { type: 'string', description: 'what to change or measure, with the repo paths' },
          why: { type: 'string', description: 'the reasoning: which items, verdicts and leads carry it, and what in the code makes it apply' },
          gain: { type: 'string', description: 'the expected effect, and how sure that is' },
          cost: { type: 'string', description: 'effort, spend and risk, including what it could break' },
          verify: { type: 'string', description: 'how to tell it worked: the measurement or test' },
          rulings: { type: 'string', description: 'how it respects the profile rulings and invariants' },
          sources: { type: 'array', items: { type: 'string' } },
        },
        required: ['title', 'kind', 'what', 'why', 'gain', 'cost', 'verify', 'rulings', 'sources'],
      },
    },
  },
  required: ['recommendations'],
}

phase('Recommend')
const evidence = relevant.filter((it) => RANK[it.relevance] >= RANK.medium)
const recs = evidence.length || leads.length
  ? await agent(
      [
        bound(false),
        RULES,
        'Recommend one to three changes to the project that this research justifies, strongest first. Read',
        'the code each one touches before you write it. A recommendation names the change and its paths,',
        'reasons from the items, skeptic verdicts and leads below, and states gain, cost, risk and how to',
        'verify it. It respects every ruling and invariant of the profile. When no item justifies a code',
        'change, recommend the cheapest experiment that would settle the most promising item, as kind',
        '"experiment", and say why no change is due yet. Never recommend what the code already does.',
        '',
        BRIEF,
        '',
        NOTES,
        '',
        'RELEVANT ITEMS:',
        JSON.stringify(evidence, null, 1),
        '',
        'LEADS FROM THE SKEPTIC:',
        JSON.stringify(leads, null, 1),
      ].join('\n'),
      { label: 'recommend', phase: 'Recommend', model: 'opus', schema: REC_SCHEMA },
    )
  : null
const recList = recs ? recs.recommendations : []
const REC_NOTE = !evidence.length && !leads.length
  ? 'Write under "## Recommendations" exactly: "No recommendation: this run found nothing relevant to the project."'
  : !recs
    ? 'Write under "## Recommendations" exactly: "No recommendation: the recommendation step failed."'
    : !recList.length
      ? 'Write under "## Recommendations" exactly: "No recommendation: the recommendation step found no change worth making."'
      : ''

phase('Write')
const written = await agent(
  [
    `First read the project profile ${profile}. The repository is at ${repo}. Write exactly one file,`,
    `${out} (create its directory if absent), and touch nothing else. Commit nothing.`,
    '',
    "Write the report in English for the project's developer, who reads it to decide, keep up and learn.",
    'Short sentences; every claim links its source. Outside "## Learn" the report holds only the items',
    'below; add none and mention no other source. Structure, in this order:',
    seeded
      ? '1. "# Research: <a short name for the subject of the user\'s material>", then one line on what was read.'
      : `1. "# Research ${today}", then one line on what was swept for work since ${since}.`,
    '2. "## Recommendations": each recommendation below as "### <n>. <title>" with the paragraphs "What:",',
    '   "Why:", "Gain:", "Cost and risk:", "Verify:" and "Guardrails:", linking its sources. Mark an',
    '   experiment as "(experiment)" in its heading. Where a call path, data flow or state change explains',
    '   a recommendation, draw it after its "What:" paragraph as one ```mermaid block: flowchart LR or',
    '   sequenceDiagram, at most ten nodes, every label in double quotes, only what the evidence states.',
    '3. "## Findings": the user\'s material first, then the rest grouped by topic as "### <topic>" (name',
    '   one where an item has none). Per item "#### <title>", then one plain line with link, date, source',
    '   and "Relevance: high", "Relevance: medium" or "Relevance: low", or "Relevance: none" for a link',
    '   of the user\'s (never bold); a one-paragraph summary; "Critique:"; "For the project:" with each',
    '   claim, its path and the skeptic verdict and evidence (a claim the skeptic did not check reads',
    '   "unverified").',
    '4. "## Learn": the `learn` concept of each item, from foundations to frontier, each linked to the',
    '   item it comes from.',
    'Write nothing after "## Learn"; a ledger is appended later.',
    "Keep the readers' fact, inference and guess labels. Return the recommendation titles.",
    REC_NOTE,
    '',
    seeded ? ["THE USER'S MATERIAL (it names the subject; the ITEMS carry the readings):", ...seeds.map((u) => `- ${u}`), NOTES].join('\n') : '',
    '',
    'RECOMMENDATIONS:',
    JSON.stringify(recList, null, 1),
    '',
    'ITEMS (seed: true marks the user\'s own links; one with read_as "unreadable" gets its title, link and',
    'the reason it could not be read, nothing more):',
    JSON.stringify(relevant, null, 1),
  ].join('\n'),
  { label: 'writer', phase: 'Write', model: 'opus' },
)
if (!written) return { aborted: 'writer' }

return {
  recommendations: written,
  ledger: LEDGER,
  failedRoutes: failedRoutes.map((r) => r.route),
}
