# ProcessFlowDiagram

Draft specification for a higher-level XMLUI component that sits above `xmlui-react-flow`.

The goal is not to replace `ReactFlowCanvas`. The goal is to extract the app-level mechanisms that both `myterms` and `cc-architecture` currently hand-wire around it:

- phase sequencing
- edge pulse choreography
- transient edge lifecycle
- control/header wiring
- layout hydration
- node state exposure to child templates

If this abstraction is correct, we should be able to rebuild both apps on top of it with much less custom `Globals.xs` and `ReactFlowPage.xmlui` code.

## What Exists Today

Both apps follow the same pattern:

- load `layout.json`
- build `nodes` and `edges` arrays in `Globals.xs`
- render a `ReactFlowCanvas`
- project XMLUI child components into canvas nodes by position in the child list
- drive the diagram with a phase machine
- use `Timer` plus `pulseEdge` / `pulseEdgeRoundTrip` to animate progress
- add and remove transient edges imperatively
- gate node UI with `phase`, pulse state, and app-specific globals

The main difference is complexity:

- `cc-architecture` is a linear pipeline with mostly fixed edges and one pulse per phase
- `myterms` is a branching negotiation with transient edges, round trips, repeated runs, and richer node-local state

Any useful generalization must handle both without making the simple case awkward.

## Proposed Role

`ProcessFlowDiagram` should be a declarative orchestration component for process diagrams whose visual substrate is `ReactFlowCanvas`.

It should own:

- phase progression
- animation scheduling
- transient edge declaration and cleanup
- layout loading and save integration
- control state such as current step label, message, and next action
- derived runtime context made available to node templates

It should not own:

- the low-level graph renderer
- SVG pulse implementation
- edge routing
- draggable/resizable canvas behavior
- node template contents

That split keeps `xmlui-react-flow` generic while making `ProcessFlowDiagram` opinionated about animated stepwise explainers and workflow demos.

## Mental Model

The author provides four declarations:

1. `nodes`
2. `edges`
3. `steps`
4. `templates`

The runtime turns those declarations into:

- the current graph passed to `ReactFlowCanvas`
- a step controller API
- derived state exposed to node templates
- pulse and transient-edge effects

Conceptually:

```xml
<ProcessFlowDiagram
  layoutUrl="layout.json"
  nodes="{diagramNodes}"
  edges="{diagramEdges}"
  steps="{diagramSteps}"
  state="{diagramState}"
  onStateChange="{(next) => { diagramState = next }}"
  titleTemplate="{`${$diagram.currentStep.index}. ${$diagram.currentStep.title}`}"
  subtitleTemplate="{$diagram.currentStep.message}">
  <NodeTemplate nodeId="person">
    <PersonNode />
  </NodeTemplate>
  <NodeTemplate nodeId="person-agent">
    <PersonAgentNode />
  </NodeTemplate>
</ProcessFlowDiagram>
```

This is illustrative, not final syntax. The important point is that the diagram becomes data-driven, while node interiors remain normal XMLUI components.

## Proposed Declaration

### Nodes

Nodes should be declared by stable semantic id, not implied by child order.

Minimum fields:

- `id`
- `label`
- `template`
- `layoutKey` or inline size/position fallback

Useful optional fields:

- `chrome`
- `magnetY`
- `width`
- `height`
- `className`
- `data`

Example:

```js
const nodes = [
  { id: "person", label: "Alice", template: "PersonNode", magnetY: "12%" },
  { id: "person-agent", label: "Alice's Agent", template: "PersonAgentNode" },
  { id: "control", label: "Control", template: "ControlNode", chrome: false }
];
```

### Edges

Edges should stay close to the current `ReactFlowCanvas` model because that part is already sound.

Minimum fields:

- `id`
- `source`
- `target`
- `label`

Optional fields:

- `sourceHandle`
- `targetHandle`
- `labelPosition`
- `labelOffsetX`
- `labelOffsetY`
- `noArrow`
- `data`
- `kind`

`kind` is new and useful:

- `persistent`
- `transient`
- `derived`

This lets the higher-level component manage edge lifecycle without the app having to call `addEdge` and `removeEdge` directly in most cases.

### Steps

`steps` are the core extraction. A step should declare:

- identity
- user-facing text
- entry effects
- completion policy
- next-step mapping
- state transitions

Example shape:

```js
const steps = [
  {
    id: "collect",
    title: "1",
    message: "Collect from sources",
    actionLabel: "Collect",
    run: [
      { type: "pulse", edge: "download feeds" },
      { type: "pulse", edge: "run scrapers" },
      { type: "pulse", edge: "collect picks" }
    ],
    completeAfter: { type: "duration", ms: pulseDuration },
    next: "combine"
  }
];
```

For `myterms`, the same model needs richer effects:

```js
{
  id: "lookup",
  title: "2",
  message: "Alice looks up terms",
  actionLabel: "Lookup",
  run: [
    {
      type: "transientEdge",
      edge: {
        id: "e-p-ag",
        source: "person",
        target: "agreements",
        sourceHandle: "right-top",
        targetHandle: "left-top",
        label: "lookup"
      }
    },
    { type: "pulseRoundTrip", edge: "lookup" }
  ],
  completeAfter: { type: "duration", ms: pulseDuration * 2 },
  cleanup: [{ type: "removeEdge", edgeId: "e-p-ag" }],
  next: "choose-term"
}
```

This should cover both apps better than a hardcoded finite-state implementation.

## Runtime Context Exposed To Templates

Node templates need more than raw app state. They need a standard diagram context.

Proposed context variable:

- `$diagram`

Suggested fields:

- `$diagram.step`
- `$diagram.stepId`
- `$diagram.stepIndex`
- `$diagram.stepTitle`
- `$diagram.stepMessage`
- `$diagram.actionLabel`
- `$diagram.actionEnabled`
- `$diagram.running`
- `$diagram.activeEdge`
- `$diagram.activeEdges`
- `$diagram.layout`
- `$diagram.nodes`
- `$diagram.edges`
- `$diagram.transientEdges`
- `$diagram.state`

This lets node templates use standard process state while still reading app-specific data from `$diagram.state`.

## Events And Effects

`ProcessFlowDiagram` should support a small effect vocabulary instead of raw imperative calls.

Core effects:

- `pulse`
- `pulseRoundTrip`
- `clearPulse`
- `showEdge`
- `hideEdge`
- `setState`
- `emit`
- `wait`

Likely also needed:

- `branch`
- `sequence`
- `parallel`

Why `parallel` matters:

- `cc-architecture` starts three pulses together in the collect phase
- future diagrams will want multi-edge fan-out without hand-managed timers

Why `branch` matters:

- `myterms` diverges on accept vs reject after policy evaluation

The component should schedule these effects and map them onto `xmlui-react-flow` APIs plus XMLUI state changes.

## Completion Model

Today completion is encoded with scattered `Timer` components and manual state transitions. `ProcessFlowDiagram` should absorb that.

The minimum supported completion modes should be:

- fixed duration
- pulse finished
- round trip finished
- explicit user action
- predicate on state

Examples:

- `cc-architecture`: mostly fixed duration or pulse finished
- `myterms`: explicit user action for term selection, predicate for branch resolution, duration for animations

## Control Surface

Both apps have the same control pattern:

- title showing current phase/step
- next button
- optional modals for edge info

This should be built in, but overridable.

Proposed slots:

- `headerTemplate`
- `controlTemplate`
- `edgeInfoTemplate`

Default behavior:

- render title and message
- render action button bound to `nextStep()`
- expose edge info events to a modal template

## Layout Model

The current layout loop is useful but awkward. `ProcessFlowDiagram` should own it.

Needed capabilities:

- load initial layout from `layout.json`
- merge saved width/height/position into declared nodes
- expose a `saveLayout()` helper
- optionally support a dev-mode save target later

This removes repeated `makeNode()` boilerplate from app code.

## What Stays In App Code

The abstraction should not try to absorb everything.

App code should still provide:

- node templates
- domain data
- domain-specific state
- custom modals
- step definitions
- domain-specific reducers or event handlers

For example:

- `cc-architecture` still owns sample event data and explanatory node copy
- `myterms` still owns offered term, policy lookup, agreement records, and acceptance logic

## What Needs To Change In xmlui-react-flow

`ProcessFlowDiagram` can be built on the current package, but a few improvements would make it cleaner.

### 1. Stable node-template mapping by node id

Right now child content is assigned to nodes by array position. That is brittle and makes a higher-level component awkward.

Need:

- a way to bind a rendered template to a node id explicitly

This is the biggest structural gap.

### 2. First-class transient edge support

Today transient edges are managed with imperative `addEdge` and `removeEdge` calls.

Need one of:

- keep the imperative API but document it as stable runtime support
- or add declarative transient-edge support driven by props/state

For `ProcessFlowDiagram`, declarative support is cleaner.

### 3. Animation completion hooks

`ProcessFlowDiagram` should not have to guess pulse duration with timers if the canvas can tell it when a pulse finished.

Need events or promises for:

- pulse complete
- round trip complete

### 4. Explicit active-edge reporting

`myterms` uses pulse progression as domain signal. That is valid, but the current mechanism is indirect.

Need:

- `onPulseStart`
- `onPulseStep`
- `onPulseComplete`

That would make pulse-driven UI state much less ad hoc.

### 5. Public layout API in XMLUI docs

This already exists technically via `getLayout()`, but it needs to be treated as a supported contract because `ProcessFlowDiagram` will depend on it.

### 6. Keep `_rc`-style rerender resilience

The current render-counter approach is useful and should remain available. Higher-level orchestration will trigger lots of prop changes; node rerender reliability matters.

## Minimal Viable API

A minimal first version should be able to express:

- fixed nodes and fixed edges
- transient edges
- pulse and round-trip animations
- step sequencing
- branching
- layout loading
- node templates keyed by id
- default header and next button

If that works, both demos can migrate without waiting for a larger framework.

## Acceptance Test

The acceptance test for `ProcessFlowDiagram` is not theoretical.

It should be able to reproduce both existing apps with similar behavior:

### `cc-architecture`

Must preserve:

- seven visible pipeline phases
- fan-out collect animation
- fixed pipeline edges
- current node content
- draggable layout persistence
- edge info dialog

### `myterms`

Must preserve:

- delegated/lookup/proffer/consult/verify flow
- transient send, lookup, consult, and verify edges
- round-trip animations
- accept/reject branch behavior
- repeated signed-edge accumulation
- current node-local interactive UI
- modal behavior for agreements, audit trail, and edge info

If either app requires large amounts of custom timer wiring after migration, the abstraction is too weak.

## Suggested Implementation Sequence

1. Add explicit node-id template binding to `xmlui-react-flow`.
2. Add pulse lifecycle events so step completion can stop depending on guessed timers.
3. Implement `ProcessFlowDiagram` as a new package layered on top of `xmlui-react-flow`.
4. Migrate `cc-architecture` first because it is the simpler linear case.
5. Migrate `myterms` second to force support for branching and transient-edge workflows.

## Current Status

We now have the first live harness running in `cc-architecture`.

What works today:

- `cc-architecture` keeps the old route at `/`
- a new route at `/process-flow` renders a first-cut `ProcessFlowDiagram`
- `ProcessFlowDiagram` currently wraps `ReactFlowCanvasRender`
- the wrapper owns the title/message/action overlay
- `xmlui-react-flow` now emits `onPulseStep` and `onPulseComplete`
- the package itself builds, and the live app can render it

What we changed in `xmlui` to get here:

- added `packages/xmlui-process-flow`
- added an initial `ProcessFlowDiagram` component
- exported `ReactFlowCanvasRender` from `xmlui-react-flow`
- added package export metadata to `xmlui-react-flow`
- fixed `xmlui build-lib` so standalone UMD bundles use `window.jsxRuntime` instead of guessing `window.react_jsx_runtime`

What is still temporary:

- `ProcessFlowDiagram` is not yet the workflow engine; `cc-architecture/components/ProcessFlowDiagramPage.xmlui` still owns the phase timers, step progression, `getNodes()`, and `getEdges()`
- the `cc-architecture` harness still loads a copied extension bundle rather than a smoother dev workflow
- the standalone harness still needs `window.process` and `window.require` shims in `index.html`

Why the harness still needs shims:

- even after the `jsxRuntime` fix, the generated `xmlui-process-flow.js` still contains Rolldown CJS interop paths that call `require("react")` and checks against `process.env.NODE_ENV`
- so the current blocker is no longer XMLUI routing or component registration syntax
- the remaining blocker is extension bundling/standalone compatibility

Debt to pay down next:

- move step sequencing and timer logic from app code into `ProcessFlowDiagram`
- add explicit node-template binding by node id so migration does not depend on child order
- eliminate the `window.require` and `window.process` shims by fixing the extension bundling path cleanly
- only after that start the `myterms` migration, because it will amplify every unresolved abstraction gap

## Later TODO

If the base `ProcessFlowDiagram` extraction works, add a higher-level authoring helper for graph declarations so authors do not have to hand-write verbose, error-prone edge objects with `source`, `target`, `sourceHandle`, and `targetHandle`.

The likely form is a small DSL or builder layer that compiles to `ReactFlowCanvas` graph objects, for example:

```js
edge("lookup").from("person.right-top").to("agreements.left-top")
```

or:

```js
connect("person", "agreements", "lookup", "right-top", "left-top")
```

This should be treated as a follow-on improvement, not part of the first extraction. First prove that the base `ProcessFlowDiagram` model can reproduce `cc-architecture` and `myterms`.

## Broader Scope

`ProcessFlowDiagram` should not be framed too narrowly as just an explainer tool.

Because nodes are full XMLUI components, they can:

- hold local state
- make API calls
- render live data views
- expose controls and dialogs
- react to shared diagram state
- communicate indirectly through shared state and diagram events

That means the real capability is closer to:

- a process-oriented orchestration layer for stateful XMLUI components on a graph

An explainer is one use case, but not the only one. The same abstraction could support:

- operational dashboards with dataflow semantics
- guided multi-agent or multi-service simulations
- workflow UIs where each node is an interactive tool surface
- live architecture views whose nodes both display and manipulate system state

So the right boundary is not "explainers only." The right boundary is:

- graph-oriented orchestration of interactive XMLUI node applications

## Non-Goals For V1

To keep the first cut focused, V1 should not try to solve:

- arbitrary graph editing
- visual step authoring tools
- auto-layout
- generic BPMN compatibility
- persistence of arbitrary runtime-added edges across reload

This is not a full process modeling suite or BPMN product. It is a higher-level orchestration component for interactive, stateful XMLUI applications arranged as a process graph.
