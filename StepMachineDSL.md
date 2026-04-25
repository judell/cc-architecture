# Step Machine DSL

A declarative step machine for XMLUI apps that use `ReactFlowCanvas` to present animated process diagrams.

Instead of writing per-phase functions and completion callbacks, you declare steps as data. A generic runtime in `Globals.xs` interprets the declarations and writes to XMLUI globals that your templates react to.

## Quick Start

Define your steps in `Globals.xs`:

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
  ];
}
```

Add completion triggers in your page markup:

```xml
<Timer
  enabled="{running}"
  interval="{pulseDuration}"
  onTick="{() => { completeCurrentStep() }}" />
```

Wire the button to the step machine:

```xml
<Button
  label="{buttonLabel}"
  enabled="{buttonEnabled}"
  when="{buttonLabel !== ''}"
  onClick="nextStep()" />
```

## Step Properties

### Required

| Property | Type | Description |
|----------|------|-------------|
| `id` | string | Unique step identifier. Used by `next` and `nextIf` for branching. |
| `phase` | number or string | Value written to the `phase` global when this step is active. Templates use `phase` to gate visibility (e.g., `when="{phase >= 1}"`). |

### Display

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `title` | string | `''` | Written to `phaseLabel`. Typically the step number. |
| `message` | string | `''` | Written to `phaseMessage`. Describes what happens in this step. |
| `actionLabel` | string | `''` | Written to `buttonLabel`. If empty, no button is shown. |
| `actionEnabled` | boolean | `true` | Written to `buttonEnabled`. Set to `false` to hide the button for steps that advance automatically. |

### Effects

| Property | Type | Description |
|----------|------|-------------|
| `run` | array | Effects to execute when the user clicks the action button. See [Effect Types](#effect-types). |
| `runningPhase` | any | If set, `phase` is changed to this value while effects are running, then reverts on completion. Useful for gating animations (e.g., `phase === 'collecting'`). |
| `cleanup` | array | Effects to execute when the step completes, before advancing. Typically `removeEdge` calls. |

### Completion

| Property | Type | Description |
|----------|------|-------------|
| `completeAfterMs` | number | Complete the step after this many milliseconds. Requires a Timer in the page markup with `enabled="{running}"`. |
| `restartOnAction` | boolean | If `true`, clicking the button resets the flow to the beginning instead of advancing. |
| `clearPulseOnRestart` | boolean | If `true` (with `restartOnAction`), clears all pulse animations on restart. |

### Navigation

| Property | Type | Description |
|----------|------|-------------|
| `next` | number or string | The next step after completion. Can be a step index (number) or step id (string). If omitted, advances to the next step in array order. |

### Callbacks

| Property | Type | Description |
|----------|------|-------------|
| `onEnter` | function | Called when the step becomes active (via `applyStep`). Use for state initialization. |

## Effect Types

Effects are objects in the `run` or `cleanup` arrays.

| Type | Fields | Description |
|------|--------|-------------|
| `pulse` | `edge`, `durationMs` | Pulse-animate a named edge. Multiple pulses in the same `run` array fire in parallel. |
| `clearPulse` | — | Clear all active pulse animations. |

### Example

```js
{
  id: 'collect',
  run: [
    { type: 'clearPulse' },
    { type: 'pulse', edge: 'download feeds', durationMs: pulseDuration },
    { type: 'pulse', edge: 'run scrapers', durationMs: pulseDuration },
    { type: 'pulse', edge: 'collect picks', durationMs: pulseDuration },
  ],
}
```

## Runtime Globals

The step machine writes to these XMLUI globals (declare them in `Main.xmlui`):

| Global | Type | Description |
|--------|------|-------------|
| `phase` | any | Current phase value from the active step. |
| `phaseLabel` | string | Title text from the active step. |
| `phaseMessage` | string | Message text from the active step. |
| `buttonLabel` | string | Action button label from the active step. |
| `buttonEnabled` | boolean | Whether the action button is enabled. |
| `running` | boolean | `true` while a step's effects are executing. |
| `stepIndex` | number | Index of the current step in the array. |
| `pulseDuration` | number | Default pulse duration in milliseconds. |

## Runtime Functions

These are defined in `Globals.xs` and available to your markup and code:

| Function | Description |
|----------|-------------|
| `nextStep()` | Called by the action button. Executes the current step's `run` effects and sets `running = true`. |
| `completeCurrentStep()` | Called by completion triggers. Runs `cleanup`, resolves next step, calls `applyStep`. |
| `applyStep(index)` | Sets all display globals from the step at the given index. |

## Page Markup

Your page needs completion triggers. For `cc-architecture` (linear pipeline with fixed durations), one Timer is sufficient:

```xml
<Timer
  enabled="{running}"
  interval="{pulseDuration}"
  onTick="{() => { completeCurrentStep() }}" />
```

## Adding a Step

1. Add an object to the `getProcessFlowSteps()` array.
2. Set `id`, `phase`, `title`, `message`, `actionLabel`.
3. Add `run` effects if the step triggers animations.
4. Set `completeAfterMs` or rely on an existing completion trigger.
5. Add `cleanup` if the step creates transient edges.
6. Set `next` if the step doesn't advance sequentially.

No new functions, Timers, or ChangeListeners needed.
