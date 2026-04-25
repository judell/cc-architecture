# Community Calendar Architecture Explainer

An interactive visualization of the [community-calendar](https://github.com/judell/community-calendar) data pipeline, built with [XMLUI](https://xmlui.org) and [ReactFlowCanvas](https://github.com/xmlui-org/xmlui/tree/main/packages/xmlui-react-flow).



https://github.com/user-attachments/assets/97da6355-912c-4f8f-a2ff-7a3a7b1740bd



## Live demo

[https://judell.github.io/cc-architecture/](https://judell.github.io/cc-architecture/)

Click through 7 pipeline phases to see how event data flows from ICS feeds, web scrapers, and curator picks through GitHub Actions, deduplication, AI classification, Supabase, and into the XMLUI frontend.

## Step Machine DSL

The diagram is driven by a declarative step machine. Each pipeline phase is an object in a step array:

```js
{
  id: 'collect',
  title: '1',
  message: 'Collect from sources',
  actionLabel: 'Collect',
  phase: 0,
  runningPhase: 'collecting',
  completeAfterMs: pulseDuration,
  run: [
    { type: 'pulse', edge: 'download feeds', durationMs: pulseDuration },
    { type: 'pulse', edge: 'run scrapers', durationMs: pulseDuration },
    { type: 'pulse', edge: 'collect picks', durationMs: pulseDuration },
  ],
}
```

A generic runtime in `Globals.xs` interprets these declarations, writes to XMLUI globals, and executes edge animation effects. A single Timer in the page markup handles step completion. Adding a step means adding an object to the array — no new functions, timers, or wiring needed.

See [StepMachineDSL.md](StepMachineDSL.md) for the full DSL reference.

## Companion project

This is paired with [MyTerms](https://github.com/judell/myterms), an explainer for IEEE Std 7012-2025. Both projects use the same step machine DSL and the same toolkit: XMLUI components rendered inside ReactFlowCanvas nodes, with animated edges showing data flow. MyTerms exercises the DSL's richer features: transient edges, round-trip animations, pulse sequences, conditional branching, node-driven step triggers, and partial restart.

## XMLUI components in canvas nodes

Canvas nodes aren't just labels — they're full XMLUI components. Each node can contain tables, text, icons, select dropdowns, buttons, and modal dialogs. The Supabase node shows the events table, the Classifier node shows category assignments, and the Frontend node renders simulated event cards.

This means a canvas node can be a live, interactive widget — not just a box in a diagram. The potential goes beyond explainers:

- **Dashboards** where each node is a live data view, connected by edges showing data dependencies
- **Workflow builders** where users drag and connect functional components
- **System monitors** where nodes show real-time status and edges show data flow between services

## Layout management

ReactFlowCanvas nodes are draggable, and a save button exports the current positions as `layout.json`. You can auto-generate an initial layout, then drag nodes into a clean arrangement by hand.
