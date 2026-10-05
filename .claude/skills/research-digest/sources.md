# Source routes

How each platform is searched and how a found item is read. Open it before discovery or reading. Routes tested on 2026-10-05 with curl; keyless means no login or key that day. Signal notes come from a measured month.

## How to search

- Query names, not topic words: product, project, model, statute and procedure names find news; topic words find tutorials and SEO.
- Pair a broad feed with a primary source. Press and blogs are leads; the fact comes from the paper, the changelog or the statute.
- Fetch with curl. WebFetch shares an egress that arXiv rate-limits, and its small model misreads pages.
- On HTTP 429, wait a minute and retry once before you call the route failed.
- Call the GitHub API through `gh api` where `gh` is logged in: keyless calls share 60 an hour per address.

## Discovery: research and engineering

| Platform | How | Signal |
| --- | --- | --- |
| arXiv export API | `https://export.arxiv.org/api/query?search_query=(cat:cs.IR+OR+cat:cs.CL)+AND+abs:%22<phrase>%22+AND+submittedDate:%5B<since>0000+TO+<today>2359%5D&sortBy=submittedDate&sortOrder=descending&max_results=100`. Dates go in without dashes (`20260921`). Atom with abstracts. One request at a time, 3 s apart (arXiv API terms); parallel lanes earn HTTP 429. | High with phrase queries. German terms find nothing on arXiv. |
| arXiv listing | `https://arxiv.org/list/<cat>/<YYYY-MM>?show=2000`: one page per category and month; `pastweek` covers seven days only. | Best density for a small category such as cs.IR; query large ones such as cs.CL by phrase instead. |
| Hugging Face papers | `https://huggingface.co/api/daily_papers?date=<YYYY-MM-DD>`, one call per day. | Low for retrieval; upvotes rank attention. |
| Semantic Scholar | `/graph/v1/paper/search/bulk?query=<q>&publicationDateOrYear=<since>:` | Lookups of venue and citations; noisy as a sweep. Keyless calls hit HTTP 429 after a few requests. |
| GitHub releases | `https://github.com/<owner>/<repo>/releases.atom`, or `tags.atom` for repos that only tag. No auth. | The primary record of a dependency's change. |
| GitHub advisories | `https://api.github.com/advisories?ecosystem=<eco>&affects=<pkg>`, one call per pinned package: without `affects`, the newest 100 advisories of an ecosystem span only days. | A security fix outranks a release. |
| Package registries | `pypi.org/pypi/<pkg>/json`, `registry.npmjs.org/<pkg>` (dates under `time`), `go.dev/doc/devel/release` | Versions and dates. |
| Provider changelogs | The model and API changelogs of every provider the project calls. Most have no RSS; curl the page. | The primary record of a model's launch, change or retirement. |
| Vendor engineering blogs | RSS of the vendors in the stack and their direct rivals; keep those that publish measurements. | Measured posts beat news. |
| Benchmarks | Release or commit Atom of the leaderboard repos the project's tasks map to. | Shows new entries before papers do. |
| Hacker News | `https://hn.algolia.com/api/v1/search_by_date?query=%22<name>%22&tags=story&typoTolerance=false&restrictSearchableAttributes=title&numericFilters=created_at_i%3E<since epoch>` | Good on product names, noise on topic words ("RAG" matches "rage"). Comments carry the critique. |
| Curated weeklies | Language and database weeklies (Postgres Weekly, Golang Weekly, React Status) via their RSS. | Cheap, curated, dated. |
| Lobsters | `https://lobste.rs/t/<tag>.rss` | Good for languages (Go); low for AI. |
| Medium | `https://medium.com/feed/tag/<tag>`: latest posts only. | Low: keep only posts with measurements. |
| Reddit | No keyless route: curl gets 403, and `site:reddit.com` searches returned nothing. | Read a thread only when another source links it. |
| Browser platforms | `webkit.org/feed/`; Safari notes `developer.apple.com/tutorials/data/documentation/safari-release-notes.json`; `chromestatus.com/api/v0/features?q=<q>` | The primary record for PWA behaviour. |
| Security guidance | OWASP cheat sheets: `github.com/OWASP/CheatSheetSeries/commits/master/cheatsheets/<file>.md.atom`; IETF drafts: `datatracker.ietf.org/feed/document-changes/<draft>/` | Changes land here first. |
| Vendor status and help | Statuspage `status.<vendor>.com/history.rss`; Zendesk `support.<vendor>.com/api/v2/help_center/articles.json?sort_by=updated_at` | Maintenance, deprecations, quiet API changes. |

## Discovery: news, markets and regulation

| Platform | How | Signal |
| --- | --- | --- |
| Web search | WebSearch with names and the lookback's months, in each language the project works in. A session has 200 calls, shared by every agent in it: take the curl routes first and spend a few calls per lane where no route reaches. | Topic words bring SEO pages. |
| Google News | `https://news.google.com/rss/search?q=<q>%20when%3A30d&hl=<lang>&gl=<CC>&ceid=<CC>:<lang>`; `after:<date>` also works. Exclude noise words with `-<word>`. | High recall for press, regulators and vendors. Test each query for ambiguous terms. |
| EU Have Your Say | `https://ec.europa.eu/info/law/better-regulation/brpapi/searchInitiatives?text=<q>&language=EN&size=30` | The pipeline of delegated and implementing acts, with consultation dates. |
| EU Publications Office | SPARQL at `publications.europa.eu/webapi/rdf/sparql`, filtered on `cdm:work_date_document` and a title pattern. | Adopted acts and national transpositions. |
| Commission press corner | `https://ec.europa.eu/commission/presscorner/api/search?language=en&text=<q>&pagesize=50` | Infringements, adoptions. |
| Bundesgesetzblatt | `recht.bund.de/rss/feeds/rss_bgbl-1.xml`: titles only; an omnibus law can amend a statute its title does not name. | Tripwire. |
| German statute status | The `Stand` line of `gesetze-im-internet.de/<law>/` names the latest amending act. | One fetch shows whether a stored text is stale. |
| BMF | RSS: `bundesfinanzministerium.de/SiteGlobals/Functions/RSSFeed/DE/Steuern/RSSSteuern.xml` and `.../Pressemitteilungen/RSSPressemitteilungen.xml`. HTML pages sit behind a bot wall even with a browser user agent; PDFs load with `?__blob=publicationFile`. | Primary for tax letters and bills. |
| Bundesrat, Bundestag | `bundesrat.de` search for Drucksachen. The DIP API rejects the key printed in its own OpenAPI file: search the web for the procedure. | Bill stages. |
| Lobbyregister | `lobbyregister.bundestag.de` searches for Regelungsvorhaben and Stellungnahmen. | The only public trace of drafts sent to associations. |
| Federal agencies | Version pages of BZSt and BSI name versions without change dates: compare against the stored version. | Version check. |
| Ministries, NGOs, associations | RSS where offered (`bundesumweltministerium.de/meldungen.rss`, `repair.eu/feed/`, `dfka.net/feed/`). | Leads; members-only statements are skipped. |

## Reading

| Source | How |
| --- | --- |
| arXiv paper | `curl -sL https://arxiv.org/html/<id>` with tags stripped; numbers set as math sit in MathML `alttext`. No HTML: `curl -sL -o /tmp/<id>.pdf https://arxiv.org/pdf/<id>`, then `pdftotext -layout /tmp/<id>.pdf -`. Both keep tables. The HTML ends in arXiv's feedback boilerplate. |
| Any PDF | Download, then `pdftotext -layout`, or the Read tool with a page range. |
| Web page | `curl -sL -A "Mozilla/5.0"` with tags stripped. WebFetch is triage only. |
| German law page | HTML in ISO-8859-1 at `gesetze-im-internet.de/<law>/__<nr>.html`. |
| Video | No transcript route. Read a companion post or paper, else skip with the reason. |
| Login, lead form, bot wall, paywall | Never log in or submit a form. Find the same content elsewhere, else skip with the reason. |
