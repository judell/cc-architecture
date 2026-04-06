# Animating a Contract Negotiation

## Live demo

https://judell.github.io/myterms/

## Repo

https://github.com/judell/myterms

## The story

The MyTerms demo models an IEEE 7012 contract negotiation. Alice wants to establish a service delivery agreement with Kleindorfer's. The flow involves five entities — Alice, her agent, a public agreements registry, Kleindorfer's agent, and Kleindorfer's — connected by arrows that represent the relationships and actions between them.

The demo walks a viewer through this negotiation step by step, with animated arrows showing data flowing between the entities. A viewer clicks buttons to advance through the phases, watching the negotiation unfold.

## Phased flow

The negotiation is broken into numbered phases, each with a descriptive message and (usually) a button to advance:

1. **Delegate** — Alice and Kleindorfer's delegate agency to their software agents. Both delegation arrows animate simultaneously.

2. **Lookup** — Alice looks up available terms from the public agreements registry. A single arrow animates out to the registry and back (round trip).

3. **Choose a term** — Alice's pick list appears. No button — the selection itself advances the flow.

4. **Proffer** — Alice's agent sends the selected term to Kleindorfer's agent. A transient "send" arrow appears, animates, and disappears.

5. **Consult Policy** — Kleindorfer's agent consults Kleindorfer's policy database. A transient arrow animates down to Kleindorfer's and back (round trip), then disappears.

6. If the policy says **Accept**: a "Verify" button appears and Kleindorfer's agent verifies the agreement. A transient arrow animates, data stores update, and the signed agreement appears. If the policy says **Reject**: the flow goes straight to "Agreement rejected."

7. **Start Over** — reset everything and run again with a different term.

## What makes this work

The demo runs on [XMLUI](https://xmlui.org) with a [ReactFlowCanvas](https://github.com/xmlui-org/xmlui/tree/main/packages/xmlui-react-flow) component that wraps React Flow. The key architectural decisions:

### ARIA labels as animation targets

Every edge in the React Flow diagram has an `aria-label` matching its semantic name ("proffers", "delegates agency", etc.). Animation is pure DOM manipulation: find the edge by `querySelector('[aria-label="proffers"]')`, append an SVG circle with `animateMotion` along the edge's bezier path. This bypasses React's rendering pipeline entirely — no state management, no batching, no race conditions.

### Transient edges

Some arrows only appear during their animation. The canvas API supports `addEdge` and `removeEdge`, so edges like "lookup", "send", "consults policy", and "verifies agreement" are added just before animation, animated, then removed. This keeps the diagram clean between steps.

### Round trips

The `pulseEdgeRoundTrip` API animates a dot forward along an edge then back, swapping the arrow direction between legs. This represents request/response patterns (looking up terms, consulting policy) with a single labeled edge instead of two.

### Concurrent pulses

Multiple edges can animate simultaneously. The delegation phase fires both "delegates to" and "delegates personal agency" at the same time, showing that both parties delegate independently.

### XMLUI components on the canvas

The phase label, step message, and action buttons live on the canvas itself as a chromeless node — no border, no handles, just the content. This means they pan and zoom with the diagram. The buttons call global functions defined in `Globals.xs` using XMLUI's `onClick="delegate()"` pattern.

### Canvas API from child nodes

Components rendered inside the canvas can't reference the canvas by its XMLUI id. The wrapper exposes the canvas API on `window.__reactFlowCanvasApi`, so buttons inside canvas nodes can trigger animations directly.

### Phase-gated UI

Each entity's display is gated on the current phase number, not on which edge has been pulsed. This is more reliable than tracking pulse state, which changes across phases. Alice's Agent shows "Waiting for term..." until phase 4, then "Received: SD-BASE". Kleindorfer's Agent shows "No term offered yet" until phase 6, then "Received", then "Accepted" or "Rejected".

### Reactive dependency injection

XMLUI tracks reactive dependencies automatically through function calls — but the `nodes` prop passes through a function (`getNodes()`) that hides the dependency chain from XMLUI's tracker. The comma operator explicitly lists the reactive globals so XMLUI knows to re-evaluate:

```xml
nodes="{(phase, phaseLabel, phaseMessage, pulse.active, ..., getNodes())}"
```

### Layout management

Node positions are defined in `layout.json`. A save button in the header exports the current positions (after dragging) as a downloadable `layout.json` file. The `getLayout()` API returns positions from the live canvas.

## The co-evolution

The demo and the ReactFlowCanvas component co-evolved. Features like transient edges, round trip animation, concurrent pulses, chromeless nodes, and the canvas API for child nodes were all driven by the demo's needs. The [package README](https://github.com/xmlui-org/xmlui/tree/main/packages/xmlui-react-flow) documents the full API.
