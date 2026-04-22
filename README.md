# Community Calendar Architecture Explainer

An interactive visualization of the [community-calendar](https://github.com/judell/community-calendar) data pipeline, built with [XMLUI](https://xmlui.org) and [ReactFlowCanvas](https://github.com/xmlui-org/xmlui/tree/main/packages/xmlui-react-flow).

## Live demo

[https://judell.github.io/cc-architecture/](https://judell.github.io/cc-architecture/)

Click through 7 pipeline phases to see how event data flows from ICS feeds, web scrapers, and curator picks through GitHub Actions, deduplication, AI classification, Supabase, and into the XMLUI frontend.

## Second use of a raw capability

This is the second project built with this approach. The first was [MyTerms](https://github.com/judell/myterms), an explainer for IEEE Std 7012-2025. Both projects use the same toolkit: XMLUI components rendered inside ReactFlowCanvas nodes, with animated edges showing data flow between them. The fact that it's been done twice suggests a capability that wants to be extracted and refined so that visualizations like this can be made in a more principled, more easily declarative way.

## How this was built

An AI assistant (Claude) studied the MyTerms explainer — its Globals.xs state machine, its ReactFlowPage.xmlui canvas wiring, its node components — then pattern-copied the structure to build this community-calendar version. XMLUI Inspector traces were essential for debugging: when nodes didn't render or the state machine stalled, the trace showed exactly which phase transitions fired, which timers ticked, and which data bindings updated.

The process worked, but it was rough:

- **Trial and error with the xs engine.** The XMLUI scripting language (xs) has constraints that differ from standard JavaScript — no `var` declarations (use `global.*` on the App tag or `const` in function bodies), no `for...in` loops, no `window` access from expressions. These are documented and were available via the xmlui-mcp server, but the AI assistant failed to look them up before writing code and instead discovered them one error at a time. The tooling was there; the discipline to use it wasn't.

- **Undocumented ReactFlowCanvas API.** The canvas component lives in a separate package without standard XMLUI docs. Edge handle names (`right-top`, `left-bottom`, etc.), the node/child mapping convention, `pulseEdge` / `pulseEdgeRoundTrip` / `addEdge` / `removeEdge` — all of this was reverse-engineered from the working MyTerms code. Documenting the canvas API would make this kind of project far more accessible.

- **Manual state machine wiring.** Each phase requires a function in Globals.xs, a Timer in ReactFlowPage.xmlui, and corresponding `when` guards in node components. This is boilerplate that could be generated from a simpler declaration — something like a list of phases with their edge animations and node state changes.

## Layout management

ReactFlowCanvas nodes are draggable, and a save button exports the current positions as `layout.json`. This is genuinely useful: you can auto-generate an initial layout, then drag nodes into a clean arrangement by hand. But the handoff is awkward — you click save, a file downloads to ~/Downloads, and you have to copy it back into the project and commit it. A tighter loop (e.g., saving directly to the project, or a dev mode that auto-persists positions) would make iterating on layout much more pleasant.

## XMLUI components in canvas nodes

The most powerful aspect of this approach is that canvas nodes aren't just labels — they're full XMLUI components. Each node can contain tables, text, icons, select dropdowns, buttons, and modal dialogs. In the MyTerms demo, Alice's node has a `Select` for choosing privacy terms and a `Table` showing her data store. In this demo, the Supabase node shows the events table and deduplicated view, the Classifier node shows category assignments, and the Frontend node renders simulated event cards.

This means a canvas node can be a live, interactive widget — not just a box in a diagram. The potential goes well beyond explainers:

- **Dashboards** where each node is a live data view, connected by edges showing data dependencies
- **Workflow builders** where users drag and connect functional components
- **System monitors** where nodes show real-time status and edges show data flow between services
- **Interactive tutorials** where each node is a step with embedded exercises

The combination of a Visio-like canvas with reactive, data-bound components inside each node is unusual. Most diagramming tools give you shapes and arrows; this gives you shapes and arrows where each shape is a mini-application.

## A better method

What would a more principled version look like? Probably a declarative format that specifies:

1. **Nodes** — id, label, component name, initial position/size
2. **Edges** — source, target, handles, label
3. **Phases** — ordered list, each declaring which edges animate, which node states change, what the button says
4. **Data** — sample data that populates nodes at each phase

From that declaration, the framework would generate the Globals.xs state machine, the ReactFlowPage timers, and the phase-gated `when` expressions automatically. The author would only write the node component templates and supply the data. Layout could be declared initially and refined by dragging, with a save-in-place workflow.

This would turn a multi-day AI-assisted build into something a person could sketch out in an afternoon.
