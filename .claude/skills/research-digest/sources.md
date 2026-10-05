# Source routes

How each source family is found and read. Open it before discovery or reading. Routes tested on 2026-10-05; keyless means no login or key that day.

| Route | Use | How |
| --- | --- | --- |
| arXiv export API | Discovery over a window; metadata by id | `https://export.arxiv.org/api/query?search_query=cat:cs.IR+AND+abs:%22knowledge+graph%22+AND+submittedDate:%5B<since>0000+TO+<today>2359%5D&sortBy=submittedDate&sortOrder=descending&max_results=50`. Named papers: `?id_list=<id>,<id>`. Atom with full abstracts, keyless, https only. At most one request per 3 s, one connection (arXiv API terms). |
| arXiv RSS | The latest announcement day | `https://rss.arxiv.org/rss/<cat>` with abstracts and `announce_type`. No weekend issues, so useless for a window. |
| arXiv full text | The reading of record | `curl -sL https://arxiv.org/html/<id>` with tags stripped; numbers set as math sit in MathML `alttext`. No HTML: `curl -sL -o /tmp/<id>.pdf https://arxiv.org/pdf/<id>`, then `pdftotext -layout /tmp/<id>.pdf -`. Both keep tables. The HTML ends in arXiv's feedback boilerplate, which is not paper text. |
| WebFetch | Triage only | A small model answers over the page. It dropped captions and misquoted papers in testing. Fetch raw pages with curl for the reading. |
| Hugging Face papers | What the field reads | `https://huggingface.co/api/daily_papers?date=<YYYY-MM-DD>`, one call per day; `/api/papers/search?q=<q>`. Keyless. Upvotes measure attention, not quality. |
| Semantic Scholar | Citations, venue, follow-ups | `/graph/v1/paper/search/bulk?query=<q>&publicationDateOrYear=<since>:` is keyless. The relevance search answers 429 without a key. |
| GitHub | Releases of named repos | `gh api repos/<owner>/<repo>/releases/latest`. Repos that only tag: `.../tags` plus their `CHANGELOG.md`. |
| Vendor blogs | Announcements | Most serve static HTML with post links and no RSS; curl the index. JavaScript-rendered blogs: WebSearch `site:<domain>`. |
| OpenRouter | Model and price changes | `https://openrouter.ai/api/v1/models`: per model `created` (epoch) and `pricing`. Keyless. |
| Press, Substack | News, essays | Atom or RSS where offered (`heise.de/rss/heise-atom.xml`, `<blog>/feed`). Paywalled bodies are skipped with the reason. |
| LinkedIn Pulse | Practitioner essays | Public articles read in full via `curl -sL -A "Mozilla/5.0"`, tags stripped. |
| YouTube | Talks | oEmbed yields the title only; no transcript route. Read a companion page or skip with the reason. |
| Login, lead form, Cloudflare wall | — | Never log in or submit a form. Search for the same content elsewhere, else skip with the reason. |
