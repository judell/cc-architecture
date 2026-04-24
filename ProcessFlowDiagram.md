# ProcessFlowDiagram

A step-machine DSL for XMLUI apps that use `ReactFlowCanvas` to present animated process diagrams.

The goal: replace hand-written per-phase functions, completion callbacks, and scattered Timers with a declarative step array interpreted by a generic Globals.xs runtime.

## What Exists Today

Both `cc-architecture` and `myterms` follow the same pattern:

- load `layout.json`
- build `nodes` and `edges` arrays in `Globals.xs`
- render a `ReactFlowCanvas`
- drive the diagram with a phase machine
- use `Timer` plus `pulseEdge` / `pulseEdgeRoundTrip` to animate progress
- add and remove transient edges imperatively
- gate node UI with `phase`, pulse state, and app-specific globals

The main difference is complexity:

- `cc-architecture` is a linear pipeline with mostly fixed edges and one pulse per phase
- `myterms` is a branching negotiation with transient edges, round trips, repeated runs, and richer node-local state

## The DSL Approach

### Step declarations

Steps are declared as a data array in `getProcessFlowSteps()`:

```js
function getProcessFlowSteps() {
  return [
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
    },
    // ... more steps
    {
      id: 'done',
      title: '',
      message: 'Pipeline complete',
      actionLabel: 'Start Over',
      phase: 7,
      restartOnAction: true,
      clearPulseOnRestart: true,
    },
  ];
}
```

### Generic runtime

The runtime is ~40 lines in Globals.xs:

- `applyStep(index)` — writes step metadata to XMLUI globals (`phase`, `phaseLabel`, `phaseMessage`, `buttonLabel`, `buttonEnabled`)
- `nextStep()` — reads the current step, sets `running = true`, executes `run` effects via `window.__reactFlowCanvasApi`
- `completeCurrentStep()` — sets `running = false`, resolves next step, calls `applyStep`
- `resolveNextStep(step, currentIndex)` — follows `step.next` (by index or id) or defaults to currentIndex + 1

### Completion via Timer

A single Timer in the page markup handles all step completions:

```xml
<Timer
  enabled="{running}"
  interval="{pulseDuration}"
  onTick="{() => { completeCurrentStep() }}" />
```

### Effect types supported

The runtime currently handles:

- `pulse` — `api.pulseEdge(edge, durationMs)`
- `pulseRoundTrip` — `api.pulseEdgeRoundTrip(edge, durationMs)`
- `clearPulse` — `api.clearPulse()`
- `addEdge` — `api.addEdge(id, source, target, sourceHandle, targetHandle, label, noArrow, data)`
- `removeEdge` — `api.removeEdge(edgeId)`

## What This Replaced in cc-architecture

Before: ~120 lines of hand-written per-phase functions (`collect()`, `combine()`, etc.) and completion callbacks (`onCollectDone()`, `onCombineDone()`, etc.), plus 8 separate Timer components.

After: ~80 lines of step declarations + ~40 lines of generic runtime + 1 Timer.

Adding a step means adding an object to an array, not writing two new functions and a new Timer.

## What myterms Needs Beyond This

The cc-architecture pipeline is linear. myterms needs extensions:

1. **Cleanup effects** — remove transient edges on step completion (`cleanup` array)
2. **Round-trip completion** — advance step when a round trip finishes, not after fixed duration
3. **Node-driven step triggers** — advance when a global changes (e.g., `offeredTerm !== ''`)
4. **Conditional branching** — `next` based on a runtime predicate (e.g., `agreementDecision === 'yes'`)
5. **Partial restart** — reset position but keep accumulated state (signed edges, data stores)

Each extension is small — a few lines in the runtime, a new field in the step declaration.

## Failed Experiment: ProcessFlowDiagram Component

We attempted to build `ProcessFlowDiagram` as a React component in `xmlui-react-flow` that would own step orchestration, provide a `$diagram` context variable, and render node templates via `NodeTemplate` binding.

This hit a fundamental XMLUI architectural boundary: the component managed step/phase state as React `useState`, which is invisible to XMLUI's expression engine. Node templates could not react to `$diagram.phase` because XMLUI only re-evaluates expressions when XMLUI-visible variables change. We tried multiple approaches:

- MemoizedItem/Container pattern for context injection — correctly injected vars but didn't drive reactivity
- Adapter bridge (`onPhaseChange` mirroring state back to XMLUI globals) — worked but defeated the purpose
- Children-refresh effect to force node updates — caused infinite re-render loops
- Merged `xmlui-process-flow` into `xmlui-react-flow` to fix bundle duplication — fixed loading but not reactivity

The core lesson: **Globals.xs is the right place for state that XMLUI templates need to react to.** The step machine works naturally when it writes to XMLUI globals. Trying to hide state inside a React component and then bridge it back to XMLUI is unnecessary complexity.

The `ProcessFlowDiagram` component and `NodeTemplate` exist in `xmlui-react-flow` from this work but are not currently used by either app. They may be useful later as a pure rendering wrapper if the scoping issues in the `customRender`/`captureNativeEvents` path are resolved.

## Current Status

`cc-architecture` runs the step-machine DSL on its `/` route with the original `xmlui-react-flow` bundle. No custom bundles, no process-flow extensions, no adapter bridges.

What works:

- all 7 pipeline steps driven by `getProcessFlowSteps()` declarations
- parallel pulse effects (collect step fires 3 edges simultaneously)
- single generic Timer for all step completions
- step machine in Globals.xs writing to XMLUI globals
- node templates react to `phase` directly
- `restartOnAction` for the "Start Over" step
- traces show clean handler:start → state:changes → handler:complete for every step

Next: port the step machine to `myterms` and extend it to handle branching, transient edges, round trips, and node-driven events.
