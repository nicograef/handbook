# Agentic Coding — Theorie

Dieses Dokument ist ein theoretisches Nachschlagewerk für Agentic Coding — Softwareentwicklung mit LLM-Agenten, die selbstständig Dateien lesen und ändern, Kommandos ausführen und ihre Ergebnisse verifizieren. Es erklärt, wie Agenten technisch funktionieren, und entwickelt daraus die drei Engineering-Disziplinen Prompt Engineering, Context Engineering und Harness Engineering sowie die Prinzipien für Multi-Agent-Orchestrierung und die langfristige Pflege eines Agenten-Setups. Ziel ist ein haltbares mentales Modell — konkrete Tool-Details (Frontmatter-Felder, Dateipfade, Limits) stehen bewusst nicht hier, sondern im [Research-Dokument](../research/agentic-coding-insights.md).

---

## Inhaltsverzeichnis

1. [Was ist Agentic Coding?](#1-was-ist-agentic-coding)
2. [Wie LLM-Agenten arbeiten](#2-wie-llm-agenten-arbeiten)
3. [Prompt Engineering für aktuelle Modelle](#3-prompt-engineering-für-aktuelle-modelle)
4. [Context Engineering](#4-context-engineering)
5. [Harness Engineering](#5-harness-engineering)
6. [Multi-Agent-Orchestrierung](#6-multi-agent-orchestrierung)
7. [Wartungsdisziplin](#7-wartungsdisziplin)
8. [Referenzen](#8-referenzen)

---

## 1. Was ist Agentic Coding?

### 1.1 Vom Autocomplete zum Agenten

Die erste Generation von KI-Coding-Tools war **Autocomplete**: Das Modell sah einen Ausschnitt der aktuellen Datei und schlug die nächsten Tokens vor. Der Mensch tippte, prüfte jeden Vorschlag und blieb für jede Iteration selbst verantwortlich — das Modell hatte weder Handlungsfähigkeit noch Feedback über die Wirkung seiner Vorschläge.

**Agentic Coding** kehrt dieses Verhältnis um: Das Modell operiert in einer Schleife mit Werkzeugen. Es liest Dateien, editiert sie, führt Tests und Builds aus, beobachtet die Ergebnisse und entscheidet selbst über den nächsten Schritt — so lange, bis das Ziel erreicht ist oder es den Menschen um eine Entscheidung bittet. Der fundamentale Unterschied ist nicht die Modellqualität, sondern die **Rückkopplung mit der Realität**: Ein Agent kann seine eigene Arbeit gegen Compiler, Testsuite und Linter prüfen, bevor ein Mensch sie je sieht.

| Aspekt              | Autocomplete-Ära                  | Agentic Coding                                 |
| ------------------- | --------------------------------- | ---------------------------------------------- |
| Arbeitseinheit      | Token-Vervollständigung           | Aufgabe („Fixe den Bug", „Baue das Feature")   |
| Kontext             | Ausschnitt der aktuellen Datei    | Repository, Dateisystem, Kommandoausgaben      |
| Feedback-Schleife   | Mensch akzeptiert oder verwirft   | Tool-Ergebnisse (Tests, Builds, Diffs)         |
| Fehlerkorrektur     | Mensch                            | Verifikationsschleife des Agenten              |
| Rolle des Menschen  | Schreibt Code, Modell assistiert  | Spezifiziert, reviewt, baut die Umgebung       |

### 1.2 Die neue Aufgabenteilung

Mit dem Agenten verschiebt sich die Arbeit des Entwicklers um eine Ebene nach oben. Statt Code Zeile für Zeile zu schreiben, spezifiziert er Aufgaben, reviewt Pläne und Diffs — und baut vor allem die **Umgebung**, in der der Agent zuverlässig arbeiten kann: Instruktionsdateien, Prüfkommandos, Berechtigungen, Isolation. Diese Umgebung heißt **Harness** (Geschirr, Gespann — das, was um das Modell herum gebaut wird).

Der Review-Schwerpunkt wandert dabei nach vorne: Eine schlechte Zeile in einem Plan führt zu hunderten schlechten Zeilen Code. Es ist deshalb effizienter, 200 Zeilen Plan zu prüfen als tausende Zeilen Diff — das Gate liegt auf Research und Plan, nicht erst auf dem Ergebnis.

### 1.3 Drei Disziplinen

Agentic Coding zerfällt in drei komplementäre Engineering-Disziplinen, die dieses Dokument nacheinander behandelt:

| Disziplin               | Frage                                                        | Abschnitt |
| ----------------------- | ------------------------------------------------------------ | --------- |
| **Prompt Engineering**  | Wie formuliere ich eine einzelne Anweisung wirksam?          | → 3       |
| **Context Engineering** | Was steht zu welchem Zeitpunkt im Context Window — und was nicht? | → 4       |
| **Harness Engineering** | Welche Umgebung (Regeln, Checks, Rechte) umgibt das Modell?  | → 5       |

---

## 2. Wie LLM-Agenten arbeiten

### 2.1 Die agentische Schleife

Ein Agent ist konzeptionell einfach: ein LLM, das in einer Schleife Werkzeuge aufruft.

```
┌────────────────────────────────────────────────────────┐
│                    Agentische Schleife                  │
│                                                        │
│  Prompt ──▶ Modell entscheidet ──▶ Tool Call            │
│                 ▲                    (Read, Edit,       │
│                 │                     Bash, Grep, …)    │
│                 │                        │              │
│                 └── Ergebnis wird an ◀───┘              │
│                     den Kontext angehängt               │
│                                                        │
│  Abbruch: Ziel erreicht, Rückfrage nötig, oder Limit    │
└────────────────────────────────────────────────────────┘
```

Jede Iteration hängt den Tool-Aufruf und sein Ergebnis an den Gesprächskontext an. Das Modell sieht also die vollständige Historie seiner bisherigen Aktionen — und genau daraus entsteht das zentrale Ressourcenproblem (→ 2.3).

### 2.2 Tools

Tools sind die Hände des Agenten: strukturierte Funktionsaufrufe (Datei lesen, editieren, Shell-Kommando, Suche), die der Harness ausführt und deren Ergebnis als Text zurück in den Kontext fließt. Die Qualität der Tools bestimmt die Qualität des Agenten:

- **Wenige, konsolidierte Tools** mit klar abgegrenzten Zwecken schlagen viele überlappende — jede Tool-Definition kostet Kontext und jede Mehrdeutigkeit kostet Entscheidungen.
- **Token-effiziente Antworten:** Kompakte Antwortformate brauchen in der Praxis etwa ein Drittel der Tokens ausführlicher Formate; Pagination und Truncation gehören in den Default.
- **Konkrete, handlungsleitende Fehlermeldungen:** Ein Tool, das „Fehler 1" zurückgibt, zwingt den Agenten zum Raten; eines, das sagt, was fehlte und wie der Aufruf korrekt aussieht, macht die nächste Iteration produktiv.

### 2.3 Das Context Window als endliche Ressource

Das Context Window ist der Arbeitsspeicher des Agenten — und es ist eine **knappe, endliche Ressource mit abnehmendem Grenznutzen**. Alles konkurriert um dasselbe Budget: System-Prompt, Instruktionsdateien, Tool-Definitionen, Skill-Beschreibungen, Gesprächshistorie und sämtliche Tool-Ausgaben. Die Zielgröße ist nicht „möglichst kurz", sondern: **die kleinste Menge von High-Signal-Tokens, die das gewünschte Ergebnis maximal wahrscheinlich macht.**

Zwei physikalische Eigenschaften folgen daraus:

1. **Position zählt.** Anfang und Ende des Kontexts werden stärker gewichtet als die Mitte. Bei langen Kontexten gehört umfangreiches Material an den Anfang und die eigentliche Frage bzw. Instruktion ans Ende — das allein bringt messbare Qualitätsgewinne (bis ~30 %).
2. **Jedes Token verdrängt Aufmerksamkeit.** Ein Absatz, der nichts zur Aufgabe beiträgt, ist nicht neutral — er verdünnt das Signal für alles andere. Die Grundannahme moderner Modelle lautet: Das Modell ist bereits sehr kompetent; jede Erklärung muss ihre Token-Kosten rechtfertigen.

### 2.4 Context Rot

Mit wachsender Kontextlänge degradiert die Abrufgenauigkeit — das Modell „vergisst" zunehmend, was in der Mitte eines langen Kontexts steht. Dieses Phänomen heißt **Context Rot**, und Agenten sind besonders anfällig dafür, weil jede Schleifeniteration Tool-Ausgaben anhäuft. Ein einziges 4.000-Zeilen-Log eines erfolgreichen Testlaufs kann das Fenster fluten und die eigentlichen Instruktionen entwerten. Daraus folgt eine Designregel für alle Prüfkommandos: **Erfolg ist stumm, Fehler sind gesprächig** — ein Check gibt bei Erfolg nichts aus und bei Fehlschlag nur die relevanten Zeilen.

Die naheliegende Gegenmaßnahme — automatische Kompaktierung (Zusammenfassen der Historie) — ist verlustbehaftet: Es lässt sich nicht vorhersagen, welche Tokens spätere Schleifendurchläufe brauchen werden. Die robustere Antwort ist, dauerhaften Zustand **außerhalb des Fensters** zu halten, im Dateisystem (→ 4.4).

---

## 3. Prompt Engineering für aktuelle Modelle

Prompt Engineering hat sich mit den aktuellen Frontier-Modellen spürbar verschoben. Viele Techniken, die für ältere Generationen notwendig waren, sind heute wirkungslos oder aktiv schädlich. Drei Verschiebungen prägen das Bild.

### 3.1 Wörtliche Instruktionsbefolgung

Aktuelle Modelle folgen Anweisungen **wörtlich** — sie generalisieren eine Instruktion nicht mehr stillschweigend von einem Fall auf den nächsten. Das hat zwei praktische Konsequenzen:

- **Geltungsbereich explizit machen.** „Wende das auf jede Sektion an, nicht nur auf die erste" — sonst wird genau eine Sektion bearbeitet.
- **Qualitative Maßstäbe durch konkrete ersetzen.** Weiche Filter wie „nur wichtige Probleme melden" oder „nicht kleinlich sein" unterdrücken bei wörtlicher Auslegung Findings und senken den Recall. Wirksam ist ein konkretes Kriterium: „Melde jeden Bug, der zu falschem Verhalten, einem Testfehler oder einem irreführenden Ergebnis führen kann; reine Stil-Nits weglassen."

Positive Anweisungen („schreibe fließende Prosa") wirken zuverlässiger als negative („kein Markdown verwenden") — das Modell braucht ein Ziel, kein Verbot.

### 3.2 De-Eskalation

Ältere Modelle brauchten Nachdruck; aktuelle übersteuern bei Nachdruck. Formulierungen wie „CRITICAL: You MUST use this tool when…" oder „If in doubt, use X" führen heute zu **Overtriggering** — das Tool wird auch dann benutzt, wenn es nicht passt. Die wirksame Form ist der schlichte Konditional: „Use this tool when…". Dieselbe Logik gilt für Anti-Faulheits-Prompting („sei gründlich!", „gib nicht auf!"): Es gehört heruntergeregelt, nicht verstärkt. Umgekehrt padden aktuelle Modelle nicht mehr von sich aus — wer eine über das Minimum hinausgehende Lösung will, muss die Qualitätslatte explizit benennen.

### 3.3 Vertrags- vs. Kompensations-Scaffolding

Die wichtigste Unterscheidung beim Aufräumen alter Prompts:

| Typ                          | Zweck                                                            | Beispiele                                                             | Bei Modellwechsel      |
| ---------------------------- | ---------------------------------------------------------------- | --------------------------------------------------------------------- | ----------------------- |
| **Kompensations-Scaffolding** | Gleicht eine Schwäche aus, die das Modell *früher* hatte          | Micro-Step-Zerlegung, „fasse nach 3 Tool-Calls zusammen", defensive Selbstprüf-Schleifen, redundante Few-Shot-Beispiele | **Löschen** — degradiert heute die Qualität |
| **Vertrags-Scaffolding**      | Erzwingt eine Garantie, unabhängig von der Modellstärke           | Output-Schemas, Policy-Guardrails, Idempotenzregeln, Berichtsformate  | **Behalten**            |

Anleitungen, die für ältere Modelle geschrieben wurden, sind für aktuelle oft zu präskriptiv und verschlechtern das Ergebnis messbar. Die Frage an jede Zeile lautet: Beschreibt sie eine *Garantie, die gelten muss* — oder einen *Workaround für eine Lücke, die es nicht mehr gibt*?

### 3.4 Was stabil bleibt

Einige Grundtechniken überdauern Modellgenerationen: der **Kollegen-Test** (wäre ein neuer Kollege von der Anweisung verwirrt, ist es das Modell auch), 3–5 *diverse* Beispiele statt vieler ähnlicher, konsistente XML-Tags zur Strukturierung, nummerierte Listen, wenn Reihenfolge oder Vollständigkeit zählen. Role-Prompting dagegen ist auf einen einzigen funktionalen Satz geschrumpft — ausgeschmückte Persona-Blöcke („Weltklasse-Experte mit 20 Jahren Erfahrung…") sind Ballast.

Für wiederkehrende Problemklassen (Overengineering, Halluzination, erfundene Statusberichte, ungewollte autonome Aktionen) existieren offizielle, getestete Formulierungsblöcke — die konkreten Texte stehen im [Research-Dokument](../research/agentic-coding-insights.md).

### 3.5 Migrationsdisziplin

Widersprüchliche Anweisungen sind bei wörtlich folgenden Modellen aktiv schädlich: Das Modell verbrennt Reasoning-Kapazität damit, den Widerspruch aufzulösen — und entscheidet dann willkürlich. Über eine geschichtete Instruktionsfläche (globale + projektweite + pfadbezogene Regeln + Skills) hinweg braucht es deshalb regelmäßige **Widerspruchs-Audits**; bewährt ist Metaprompting: die zusammengeführten Regeln dem Modell selbst vorlegen und nach Konflikten fragen. Bei einem Modellwechsel gilt: erst ohne Prompt-Änderungen wechseln, Baseline messen, dann eine Änderung nach der anderen.

---

## 4. Context Engineering

Context Engineering ist die Disziplin, die entscheidet, **was** zu welchem Zeitpunkt im Context Window steht. Die Leitidee aus Abschnitt 2.3 — kleinste Menge an High-Signal-Tokens — wird hier zu vier konkreten Prinzipien.

### 4.1 Die richtige Flughöhe

Instruktionen können auf zwei Arten scheitern:

| Fehlermodus     | Symptom                                                                 | Problem                                              |
| --------------- | ----------------------------------------------------------------------- | ---------------------------------------------------- |
| **Zu niedrig**  | Hartkodierte Pseudo-Logik: „Wenn X, dann Schritt 1, dann Schritt 2, …"  | Brüchig; bricht beim ersten nicht vorhergesehenen Fall |
| **Zu hoch**     | Vage Plattitüden: „Schreibe sauberen, wartbaren Code"                    | Setzt geteilten Kontext voraus, der nicht existiert   |

Die richtige Flughöhe sind **starke Heuristiken**: konkret genug, um Verhalten zu ändern, allgemein genug, um Situationen abzudecken, die der Autor nicht vorhergesehen hat. Dazu gehören wenige, bewusst *unterschiedliche* kanonische Beispiele — keine Wäscheliste aller Edge Cases. Und die wichtigste Meta-Regel: **minimal starten und Regeln nur als Reaktion auf beobachtete Fehler hinzufügen**, nie prophylaktisch.

### 4.2 Progressive Disclosure

Nicht alles Wissen muss permanent geladen sein. Progressive Disclosure staffelt Inhalte in Ebenen: Eine immer geladene Ebene enthält nur Name und Trigger-Beschreibung („wann ist das relevant?"); der eigentliche Inhalt wird erst bei Bedarf geladen; umfangreiches Referenzmaterial liegt in eigenen Dateien, die **null Kontext kosten, bis sie gelesen werden**. Damit das funktioniert, müssen Verweise flach bleiben (eine Ebene tief — verschachtelte Verweisketten führen zu partiellen Reads) und der kritische Inhalt am Dateianfang stehen, weil bei Kompaktierung der Anfang überlebt.

### 4.3 Just-in-time Retrieval statt Vorab-Laden

Statt Referenzmaterial vorab in den Kontext zu kippen, hält der Agent **leichtgewichtige Identifikatoren** — Pfade, Dateinamen, Links — und lädt Inhalte erst, wenn er sie braucht. Dateinamen, Ordnerhierarchie und Namenskonventionen bilden dabei den Retrieval-Index: Ein Skript namens `setup-server.sh` in `scripts/` erklärt sich selbst; `doc2.md` erklärt nichts.

Für Referenzwissen ist ein **kompakter, immer geladener Index**, der auf Dateien zeigt, empirisch die stärkste Form: In einer Vercel-Evaluation erreichte ein passiver Dokumentations-Index 100 % Erfolgsquote gegenüber 79 % für einen abrufbaren Skill (der in über der Hälfte der Fälle gar nicht aufgerufen wurde) und 53 % Baseline. Abrufbare Anleitungen lohnen sich für explizit ausgelöste Workflows — nicht für Wissen, das der Agent von selbst finden müsste.

### 4.4 Dateien als Gedächtnis

Das Dateisystem ist das Langzeitgedächtnis des Agenten — es überlebt Kompaktierung, Session-Ende und Modellwechsel. Daraus ergeben sich etablierte Techniken:

- **Strukturierte Notizen:** Plan- und Fortschrittsdateien mit Checklisten (`plan.md`, `NOTES.md`), die der Agent selbst abhakt. Für Zustand, den der Agent *nicht umschreiben* soll, ist JSON robuster als Markdown — Modelle formulieren Markdown eher ungefragt um.
- **Re-Orientierungs-Ritual:** Jede Session beginnt mit Bestandsaufnahme — Git-Log und Fortschrittsdateien lesen, bevor neue Arbeit beginnt. Die Anweisung dazu sollte präskriptiv sein („Lies progress.txt und die Git-Historie"), nicht generisch.
- **Frischer Kontext schlägt Kompaktierung:** Für lange Arbeiten ist es besser, eine neue Session zu starten, die ihren Zustand aus dem Dateisystem rekonstruiert, als eine alte Session immer weiter zu verdichten. Aktuelle Modelle sind ausgesprochen gut darin, Zustand aus dem lokalen Dateisystem wiederzuentdecken.

### 4.5 Sitzungshygiene

Zwischen inhaltlich unabhängigen Aufgaben gehört der Kontext geleert — Reste der letzten Aufgabe sind Rauschen für die nächste. Und eine bewährte Faustregel für festgefahrene Sessions: Nach zwei erfolglosen Korrekturversuchen nicht weiter argumentieren, sondern neu starten und den *ursprünglichen Prompt* besser formulieren. Der Agent, der zweimal falsch abgebogen ist, trägt beide Irrwege als Kontext mit sich.

---

## 5. Harness Engineering

Der Harness ist alles, was das Modell umgibt: Instruktionsdateien, Skills, Hooks, Prüfkommandos, Berechtigungen, Isolation. Das zentrale Denkwerkzeug dafür: **Jede Harness-Komponente kodiert eine Annahme darüber, was das Modell nicht alleine kann.** Diese Annahmen veralten mit jeder Modellgeneration (→ 7.4).

### 5.1 Instruktionsdateien

Instruktionsdateien (`AGENTS.md` als toolübergreifender Standard, `CLAUDE.md` und Verwandte als toolspezifische Einstiegspunkte) sind das projektweite Grundgesetz des Agenten. Zwei Eigenschaften bestimmen ihre Gestaltung:

1. **Sie sind advisorisch.** Der Inhalt wird als Prosa in den Kontext injiziert — das Modell *sollte* folgen, muss aber nicht. Alles, was garantiert passieren muss, gehört in einen Hook (→ 5.3).
2. **Sie konkurrieren um das Aufmerksamkeitsbudget.** Aufgeblähte Instruktionsdateien führen dazu, dass die tatsächlich wichtigen Regeln ignoriert werden. Als Richtwert gelten unter 200 Zeilen; der Test für jede Zeile lautet: *Würde ihr Fehlen zu Fehlern führen?* Wenn nein, streichen.

Hinein gehört nur, was der Agent nicht selbst herausfinden kann: Kommandos, die sich nicht erraten lassen, Stilregeln, die von Defaults abweichen, Repo-Etikette, Umgebungsfallen. Nicht hinein gehört, was aus dem Code ableitbar ist, Standardkonventionen, API-Dokumentation oder Datei-für-Datei-Beschreibungen der Codebasis. Mehrschrittige Abläufe gehören in Skills, verzeichnisspezifische Konventionen in pfadbezogene Regeln — die Wurzeldatei bleibt schlank.

Die empirische Warnung dazu: Eine ETH-Zürich-Studie fand, dass Repo-Kontextdateien die Erfolgsquote von Agenten **im Mittel nicht verbessern**, die Inferenzkosten aber um über 20 % erhöhen; LLM-*generierte* Kontextdateien senkten die Erfolgsquote sogar, während handgeschriebene ~4 % Verbesserung brachten — konzentriert auf schlecht dokumentierte Repos. Konsequenz: Instruktionsdateien von Hand schreiben, strikt auf unverzichtbare operative Constraints begrenzen und niemals generieren-und-vergessen. Und: nie zwei divergierende Instruktionssätze für verschiedene Tools pflegen — eine kanonische Datei, auf die alle Einstiegspunkte verweisen.

### 5.2 Skills

Skills sind paketierte, bei Bedarf geladene Playbooks — die richtige Heimat für wiederkehrende, mehrschrittige Workflows („Release durchführen", „Review nach Schema X"). Konzeptionell sind sie Progressive Disclosure in Reinform: Nur die Trigger-Beschreibung ist permanent geladen; der Inhalt kostet erst beim Aufruf Kontext.

Zwei Gestaltungsprinzipien tragen die Praxis:

- **Freiheitsgrade bewusst wählen.** Offene Aufgaben bekommen Heuristiken (hohe Freiheit), Aufgaben mit bevorzugtem Muster bekommen Templates (mittlere), fragile Sequenzen bekommen exakte Kommandos mit „nicht abwandeln" (niedrige). Ein Default plus eine explizite Ausweichoption — keine Menüs von Alternativen.
- **Evaluieren vor Dokumentieren.** Vor dem Ausformulieren eines Skills gehören Testszenarien definiert (inklusive einer Baseline ohne Skill) — sonst optimiert man Prosa statt Verhalten. Beobachten, welche Dateien der Agent tatsächlich liest: Immer-Gelesenes inline ziehen, Nie-Gelesenes löschen.

Die Abgrenzung zu 4.3 gilt auch hier: Skills für explizit ausgelöste vertikale Workflows, ein passiver Index für Referenzwissen.

### 5.3 Hooks — Durchsetzung statt Bitte

Prosa-Regeln sind Bitten. Eine Anweisung wie „niemals `.env` editieren" in einer Instruktionsdatei ist **a request, not a guarantee** — das Modell kann sie übersehen, vergessen oder wegpriorisieren. Hooks sind das Gegenstück: deterministische Programme, die der Harness an Lebenszykluspunkten ausführt (vor einem Tool-Aufruf, bei Session-Ende, …) und die Aktionen **blockieren** können, bevor sie stattfinden.

Daraus folgt eine saubere Arbeitsteilung:

| Regeltyp                                                       | Mechanismus              |
| -------------------------------------------------------------- | ------------------------ |
| Durchsetzbar und muss immer gelten (kein Force-Push, kein Commit ohne Freigabe, Schutz sensibler Dateien) | **Hook** (blockierend)   |
| Urteilsabhängig (Stil, Architektur, Angemessenheit)             | **Prosa** (Instruktionen) |

Jede „must/never"-Zeile in einer Instruktionsdatei, die sich mechanisch prüfen lässt, ist ein Kandidat für die Umwandlung in einen Hook — danach kann die Prosazeile gestrichen werden und gibt Budget frei.

### 5.4 Verifikationsschleifen — das wirksamste Feature

Die höchste Hebelwirkung im gesamten Harness hat eine simple Frage: **Woran erkennt der Agent selbst, dass seine Arbeit korrekt ist?** Ohne maschinelles Pass/Fail-Signal (Tests, Build-Exit-Code, Linter, Link-Checker, Diff gegen Fixture) wird der Mensch zur Feedback-Schleife — und damit zum Flaschenhals, der jede Iteration selbst prüfen muss. Mit einem solchen Signal iteriert der Agent eigenständig, bis der Check grün ist.

Für die Härte der Verifikation gibt es eine Eskalationsleiter:

1. **Check im Prompt** — „führe X aus, bevor du fertig meldest" (advisorisch)
2. **Ziel-Bedingung**, die der Harness jede Runde erneut prüft
3. **Blockierender Stop-Hook** — die Session darf nicht enden, solange der Check rot ist
4. **Verifizierer mit frischem Kontext** — eine getrennte Instanz prüft das Ergebnis, denn Selbstbenotung fällt systematisch zu positiv aus

Zwei flankierende Regeln: **Evidenz statt Behauptung** — ein Erfolgsbericht zählt nur mit vorzeigbarem Kommando und Output aus dieser Session; und die Ausgabedisziplin aus 2.4 — Checks sind bei Erfolg stumm. Auch Nicht-Code-Repos brauchen einen synthetischen Check (Beispiel dieses Handbuch: `make check` = Link-Check + Shellcheck + README-Index-Konsistenz + Sprachregel). Standardisierte Kommandos (`make test`, `make lint`, `make check`) sind dabei die Schnittstelle zwischen Repo und Agent: Der Agent muss nicht raten, wie man dieses Projekt prüft. In industriellen Setups geht das bis zu automatisch aktivierten Verifizierern je nach Repo-Inhalt und einem LLM-Judge, der Scope-Creep gegen den ursprünglichen Auftrag prüft.

### 5.5 Sandboxing

Ein Agent, der Shell-Kommandos ausführt, ist ein Programm mit den Rechten seines Benutzers — und sein Verhalten wird von jedem Text beeinflusst, den er liest (Prompt Injection über Repo-Inhalte, Issues, Webseiten). Die Antwort ist dieselbe wie bei jedem nicht vertrauenswürdigen Programm: **Least Privilege**, durchgesetzt vom Betriebssystem, nicht von Prosa.

- **Dateisystem:** Schreibrechte auf das Arbeitsverzeichnis begrenzen; Konfigurations- und Credential-Pfade explizit verweigern.
- **Netzwerk:** Default-deny mit expliziter Domain-Freigabe statt offenem Egress.
- **Autonomie nur in Isolation:** Vollautonome Modi (ohne Berechtigungs-Rückfragen) gehören in Container oder VMs mit Egress-Filter. Die eiserne Regel dort: niemals SSH-Keys oder Cloud-Credentials hineinmounten — ein bösartiges Repo kann alles exfiltrieren, was der Agent lesen kann.

---

## 6. Multi-Agent-Orchestrierung

### 6.1 Orchestrator-Worker

Das Grundmuster für Mehr-Agenten-Arbeit: Ein **Orchestrator** zerlegt die Aufgabe, delegiert Teilaufgaben an **Worker** mit jeweils frischem Kontext und synthetisiert deren Ergebnisse. Der Gewinn liegt in zwei Dingen — Parallelität und **Kontext-Isolation**: Jeder Worker verbraucht sein eigenes Fenster; seine Tool-Ausgaben fluten nicht den Kontext des Orchestrators, bei dem nur das destillierte Ergebnis ankommt.

### 6.2 Die Ökonomie: ein 15x-Einsatz

Multi-Agent ist teuer. Als Größenordnung: Ein einzelner Agent verbraucht etwa das Vierfache einer Chat-Interaktion, ein Multi-Agent-System etwa das **Fünfzehnfache**. Das lohnt sich nur für hochwertige, stark parallelisierbare Arbeit oder wenn die Informationsmenge ein einzelnes Context Window übersteigt. Als Faustskala: einfache Faktenfragen = ein Agent mit wenigen Tool-Calls; Vergleiche = 2–4 Worker; erst komplexe, breit zerlegbare Aufgaben rechtfertigen zweistellige Agentenzahlen. Und: wenige fokussierte Worker schlagen viele verzettelte.

### 6.3 Wann Multi-Agent schadet

Die wichtigste Gegenposition (Cognition: „Don't Build Multi-Agents"): Parallel arbeitende Agenten treffen **widersprüchliche implizite Entscheidungen**, weil ihnen der geteilte Kontext fehlt — Worker A wählt Konvention X, Worker B Konvention Y, und die Synthese erbt beide Inkonsistenzen. Gerade Coding-Aufgaben enthalten weniger echt parallelisierbare Teile, als es scheint: Das meiste hängt sequenziell zusammen. Für den Normalfall ist ein einzelner Agent mit gutem Kontext-Management die bessere Wahl; Multi-Agent ist das Spezialwerkzeug, nicht der Default. Der sichere Einstieg: **Lesen parallelisieren, Schreiben serialisieren** — parallele Recherche und Reviews sind konfliktfrei, parallele Edits an denselben Dateien enden in Überschreibungen. Wenn parallel geschrieben werden muss: Datei-Eigentümerschaft vorab partitionieren oder Worker in isolierten Arbeitskopien (Worktrees) laufen lassen.

### 6.4 Der Delegationsvertrag

Worker starten ohne Gesprächshistorie — sie sehen nichts von dem, was der Orchestrator weiß, teils nicht einmal die Projektregeln. Jede Delegation muss deshalb **selbstständig lesbar** sein und vier Dinge enthalten:

1. **Ziel** — was genau soll herauskommen?
2. **Output-Format** — in welcher Form wird berichtet?
3. **Werkzeug- und Quellen-Hinweise** — wo suchen, was benutzen?
4. **Grenzen** — was ist ausdrücklich *nicht* Teil der Aufgabe?

Unterspezifizierte Delegationen sind die häufigste Multi-Agent-Fehlerquelle: Der Worker füllt die Lücken mit eigenen Annahmen — und die sind mit denen des Orchestrators nicht abgestimmt (→ 6.3).

### 6.5 Paralleles Review und adversariale Verifikation

Das dankbarste Multi-Agent-Muster ist Review, weil es rein lesend ist. Die Bausteine:

- **Generator ≠ Evaluator.** Die Session, die den Code geschrieben hat, benotet ihn nicht selbst — Selbstbewertung lobt zuverlässig auch mittelmäßige Arbeit. Der Reviewer bekommt frischen Kontext.
- **Eine Linse pro Reviewer.** Parallele Reviewer mit je einem Fokus (Security, Performance, Testabdeckung), danach ein einzelner Synthese- und Dedupe-Schritt.
- **Reviewer begrenzen, sonst erfinden sie Arbeit.** Ein Reviewer, der nach Lücken gefragt wird, findet welche — auch wenn keine da sind. Der Prompt muss definieren, was als Finding zählt („melde Lücken, keine Stilpräferenzen") und was explizit ausgeschlossen ist (Noise-Liste).
- **Adversariale Verifikation.** Jedes Finding wird vor dem Bericht von einer *anderen* Instanz geprüft und dreiwertig klassifiziert: bestätigt / widerlegt / unverifiziert. Der Agent, der ein Problem gefunden hat, darf es nicht selbst bestätigen — sonst reproduziert er nur seinen eigenen Bias.

Dieselbe Denkweise hilft beim Debugging konkurrierender Hypothesen: pro plausibler Ursache ein Investigator, dessen Auftrag lautet, die *anderen* Hypothesen zu widerlegen — die überlebende Theorie gewinnt. Das kontert den Ankereffekt der ersten Vermutung.

### 6.6 Der Standard-Workflow

Für die einzelne größere Aufgabe hat sich ein vierphasiger Ablauf etabliert: **Explore → Plan → Implement → Commit.** Erst Kontext sammeln (rein lesend), dann einen Plan schreiben, der vom Menschen editiert wird, dann implementieren, dann committen. Die Skip-Heuristik: Lässt sich der Diff in einem Satz beschreiben, braucht es keinen Plan. Der Plan ist der Punkt maximaler menschlicher Hebelwirkung (→ 1.2); größere Features bekommen eine eigene Spezifikation und werden in einer frischen Session umgesetzt.

Für lange, unbeaufsichtigte Arbeit kommen die Techniken aus 4.4 zusammen: ein Feature pro Session, ein Commit pro Session, testbare Fertig-Kriterien *vor* Beginn der Ausführung definiert, Re-Orientierungs-Ritual am Sessionstart. Das verhindert die beiden typischen Ausfälle langer Läufe — verfrühte Erfolgsmeldungen und undokumentierter kaputter Zwischenzustand.

---

## 7. Wartungsdisziplin

Ein Agenten-Setup ist kein Artefakt, sondern ein Bestand, der gepflegt werden muss — mit denselben Degenerationsrisiken wie jede Codebasis: Bloat, Drift, tote Regeln.

### 7.1 Das Instruktionsbudget

Frontier-Modelle folgen grob 150–200 Instruktionen mit verlässlicher Konsistenz — und der System-Prompt des Harness verbraucht davon bereits einen erheblichen Teil (bei Claude Code ~50). Alle Instruktionsflächen — globale Regeln, Projektdatei, pfadbezogene Regeln, Skill-Beschreibungen — schöpfen aus **demselben Pool**. Jede neue Regel verdrängt also potenziell die Befolgung einer bestehenden. Instruktionen sind kein Gratis-Speicher, sondern ein Budget, das aktiv verwaltet wird.

### 7.2 Jede Regel braucht einen Beleg

Die Disziplin gegen Bloat: **Jede Zeile in einer Instruktionsdatei muss auf einen konkreten Fehler zurückführbar sein, der tatsächlich passiert ist.** Regeln, deren Anlass niemand mehr kennt, werden gestrichen. Das schließt den Kreis zu 4.1 (minimal starten, nur auf beobachtete Fehler reagieren) und macht das Regelwerk zu einer **Ratsche**: Nach jedem echten Fehlschlag kommt genau die Regel hinzu, die ihn verhindert hätte — und nichts sonst.

Die Ratsche hat eine Kehrseite: Lässt man den Agenten selbst Erkenntnisse anhängen (Selbstverbesserungs-Schleife), wächst die Datei unkontrolliert und driftet. Deshalb: agentengeschriebene Regeln vor dem Committen von Menschen reviewen (die ETH-Befunde aus 5.1 gelten hier direkt), Veraltetes archivieren, periodisch frisch aufsetzen. Sinnvoll ist ein definierter **Beförderungspfad**: Wiederkehrende Beobachtungen aus dem Sitzungsgedächtnis werden geprüft und in committete Regeln oder Skills befördert — oder verworfen.

### 7.3 Ein Mechanismus pro Inhaltstyp

Jedes Stück Agenten-Inhalt sollte genau einem Mechanismus zugeordnet sein — Doppelablage erzeugt Drift und verbrennt Budget:

| Situation                                             | Mechanismus                        |
| ----------------------------------------------------- | ---------------------------------- |
| Konvention wurde zweimal falsch gemacht               | Zeile in der Instruktionsdatei     |
| Derselbe mehrschrittige Ablauf wird wiederholt gebraucht | Skill                              |
| Muss ausnahmslos jedes Mal passieren                  | Hook                               |
| Referenzwissen, das der Agent selbst finden soll      | Kompakter Index + Dateien (→ 4.3)  |
| Lärmige, abgrenzbare Nebenaufgabe                     | Subagent mit eigenem Kontext       |

### 7.4 Re-Audit bei jedem Modellwechsel

Weil jede Harness-Komponente eine Annahme über eine Modellschwäche kodiert (→ 5), veraltet der Harness mit jeder Modellgeneration — und zwar in Richtung *Überregulierung*: Was gestern eine notwendige Krücke war, ist heute Kompensations-Scaffolding, das Qualität kostet (→ 3.3). Das Audit-Vorgehen ist dasselbe wie bei jedem Refactoring unter Unsicherheit: Baseline messen, **eine Komponente nach der anderen entfernen**, erneut messen. Datumsgebundene Aussagen und modellspezifische Workarounds gehören von vornherein nicht in langlebige Regeln, sondern — wenn überhaupt — an eine Stelle, die bei jedem Modellwechsel ohnehin geprüft wird.

---

## 8. Referenzen

### Projekt-intern

- [Agentic Coding Setup — Research Reference](../research/agentic-coding-insights.md) — die verifizierte Faktenbasis dieses Kapitels (Stand 2026-07-09) mit allen Quellen je Aussage sowie den Tool-Details, die dieses Kapitel bewusst auslässt: Frontmatter-Felder, Dateipfade, Limits, Copilot-Interop und die offiziellen Copy-Ready-Prompt-Blöcke.

### Primärquellen (Auswahl)

- [Anthropic Engineering: Effective Context Engineering for AI Agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) — Attention Budget, Context Rot, richtige Flughöhe, Just-in-time Retrieval
- [Anthropic Engineering: Multi-Agent Research System](https://www.anthropic.com/engineering/multi-agent-research-system) — Orchestrator-Worker, Token-Ökonomie, Delegationsvertrag
- [Anthropic Engineering: Effective Harnesses for Long-Running Agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) — Dateien als Gedächtnis, Session-Rituale
- [Claude Code Best Practices](https://code.claude.com/docs/en/best-practices) — Verifikationsschleifen, Eskalationsleiter, Explore-Plan-Implement-Commit
- [Claude Prompting Best Practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) — wörtliche Instruktionsbefolgung, De-Eskalation, kanonische Prompt-Blöcke
- [agents.md](https://agents.md/) — AGENTS.md als toolübergreifender Standard
- [ETH Zürich / LogicStar: Evaluating AGENTS.md (arXiv 2602.11988)](https://arxiv.org/abs/2602.11988) — empirische Wirkung von Repo-Kontextdateien
- [Cognition: Don't Build Multi-Agents](https://cognition.com/blog/dont-build-multi-agents) — Shared-Context-Argument gegen parallele Agenten
- [HumanLayer: Writing a Good CLAUDE.md](https://www.humanlayer.dev/blog/writing-a-good-claude-md) — Instruktionsbudget, Regel-Rückverfolgbarkeit
- [Vercel: AGENTS.md Outperforms Skills](https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals) — passiver Index vs. Skill für Referenzwissen
- [Spotify Engineering: Feedback Loops for Background Coding Agents](https://engineering.atspotify.com/2025/12/feedback-loops-background-coding-agents-part-3) — deterministische Verifizierer, Scope-Creep-Judge
- [Addy Osmani: Self-Improving Agents](https://addyosmani.com/blog/self-improving-agents/) — die Ratsche und ihre Drift-Risiken

### Verwandte Theorie-Dokumente

- [DevOps & Infrastructure](devops.md) — CI/CD-Pipelines als deterministische Verifikationsschicht
- [Software Architecture](architecture.md) — Architekturprinzipien, auf die Review-Agenten geeicht werden
