# Animating a Network with ARIA Labels

## Live demo

https://judell.github.io/myterms/

## Repo

https://github.com/judell/myterms

## Animation

https://github.com/judell/myterms/blob/main/ARIA-Animation.md

## The question

The MyTerms demo models an IEEE 7012 contract negotiation: Alice selects a term, her agent proffers it, Kleindorfer's agent evaluates it, and if accepted, both parties store the signed agreement. The flow is represented as a React Flow network with five nodes connected by labeled edges like "delegates personal agency", "proffers", "evaluates", "delegates to", and "verifies agreement".

The question was simple: can we send an animated pulse through this network, a glowing dot that travels each edge in sequence so you can watch the contract negotiation unfold?

## First attempts: fighting React

The obvious approach was to drive the animation through React state. We tried three variations, and all failed for the same family of reasons.

**PulseContext.** A React context held the active edge ID. Edge components consumed it and conditionally rendered an SVG `<circle>` with `<animateMotion>`. Problem: React Flow memoizes edge components, and context changes didn't reliably trigger re-renders across all edges.

**Edge data stamps.** The pulse API stamped `_pulseTs` directly onto edge data via `setEdges()`. React Flow would detect the data change and re-render. Problem: `setEdges()` updaters are batched by React 18. The first call resolved edge labels to IDs, but the results weren't available synchronously for scheduling subsequent steps. Meanwhile, other `setEdges()` calls (from `canvas.addEdge()` during the contract signing flow) raced with the pulse, clobbering the timestamps.

**setTimeout scheduling.** Even when the state updates worked, the animation dots disappeared on two of the five edges. The trace revealed why: those two edges ("evaluates" and "verifies agreement") were the ones that triggered business logic, setting `agreementDecision` and updating data stores. The resulting React re-renders replaced the edge DOM elements, destroying the appended SVG dots.

Every approach that went through React's state system hit the same wall: the animation is a DOM-level concern, but React owns the DOM and will re-render it out from under you at unpredictable moments.

## The gist: ARIA as semantic infrastructure

A [gist on semantic tracing](https://gist.github.com/judell/b8d8922f2a33288e37df21cdb753c183) had argued that ARIA labels serve multiple constituencies simultaneously: screen readers for accessibility, Playwright for testing, AI systems for reasoning about app behavior, and developers for debugging. The question arose naturally: could ARIA labels also serve as stable hooks for animation?

The thesis was that if every edge in the network had a meaningful `aria-label`, then `document.querySelector` could find it by semantic name, bypassing React's rendering pipeline entirely. No state management, no batching, no race conditions. Just the DOM.

## Adding aria-labels

In the ReactFlowCanvas source (`ReactFlowCanvasRender.tsx`), each edge component was already rendered as a function receiving props like `id`, `data`, and the bezier path. The change was minimal: wrap the edge's return value in a `<g>` element with an aria-label derived from the edge's semantic label.

```tsx
return (
  <g aria-label={data?.label || id}>
    <BaseEdge ... />
    <path d={edgePath} fill="none" stroke="none" className="pulse-path" />
    ...
  </g>
);
```

The hidden `.pulse-path` element carries the bezier path data so the animation can find it later. Edge labels also got `aria-label` attributes for highlight effects.

The result: every edge in the network became addressable by its semantic name. You can open DevTools and run `document.querySelectorAll('g[aria-label]')` to see the full semantic map of the network.

## Off to the races

With aria-labels in place, the `pulseEdge` API became pure DOM manipulation:

```typescript
pulseEdge: (label: string, dur?: number) => {
  // Clear previous
  document.querySelectorAll(".pulse-active").forEach(el => el.classList.remove("pulse-active"));
  document.querySelectorAll(".pulse-dot").forEach(el => el.remove());

  // Find the edge by its semantic name
  const edgeGroup = document.querySelector(`g[aria-label="${label}"]`);
  if (!edgeGroup) return;

  edgeGroup.classList.add("pulse-active");

  // Create an animated dot that follows the edge's bezier path
  const pulsePath = edgeGroup.querySelector(".pulse-path");
  const pathD = pulsePath?.getAttribute("d");
  if (pathD) {
    const dot = document.createElementNS("http://www.w3.org/2000/svg", "circle");
    dot.setAttribute("r", "6");
    dot.setAttribute("fill", "#3b82f6");
    dot.setAttribute("class", "pulse-dot");

    const anim = document.createElementNS("http://www.w3.org/2000/svg", "animateMotion");
    anim.setAttribute("dur", `${dur}ms`);
    anim.setAttribute("path", pathD);

    dot.appendChild(anim);
    edgeGroup.appendChild(dot);
    anim.beginElement();
  }
}
```

No React state. No context. No batching. The dot travels the exact bezier path that React Flow computed, found via the aria-label that gives the edge its semantic identity.

The dots on the state-changing edges ("evaluates" and "verifies agreement") still got destroyed by React re-renders, but a reapply mechanism using `requestAnimationFrame` re-creates the dot after React settles, querying the fresh DOM element by the same aria-label.

## The async gap

The DOM animation worked. But choreographing the network, making nodes react when the pulse arrives, exposed a second problem.

The original pulse API used `setTimeout` to step through edges and emit events. The XMLUI framework has its own reactive system: globals, ChangeListeners, and expressions that re-evaluate when dependencies change. Setting a global like `pulseCurrentEdge = 'evaluates'` from inside a `setTimeout` callback didn't trigger XMLUI's reactive updates. The event fired, the callback executed, but the ChangeListener never saw the change.

The diagnostic was revealing. XMLUI's semantic tracing showed that the `onPulseStep` callback was being called for all five edges — the console confirmed the function existed and returned normally. But the ChangeListener on `pulseCurrentEdge` never fired for "evaluates" or "verifies agreement". Three edges worked, two didn't. The differentiating factor: the three that worked triggered no state changes, while the two that failed were the ones whose ChangeListener conditions matched and tried to set globals.

Here's the curated trace from the working Timer-based solution, showing the pulse stepping through all five edges with state changes triggered at the right moments:

```
select SD-BASE
  offeredTerm: "" → "SD-BASE"

pulse step 0
  pulseCurrentEdge: "" → "delegates personal agency"
  canvas.pulseEdge("delegates personal agency", 1200)

pulse step 1
  pulseCurrentEdge: "delegates personal agency" → "proffers"
  canvas.pulseEdge("proffers", 1200)

pulse step 2
  pulseCurrentEdge: "proffers" → "evaluates"
  agreementDecision: "" → "yes"                        ← KA reacts
  canvas.pulseEdge("evaluates", 1200)

pulse step 3
  pulseCurrentEdge: "evaluates" → "delegates to"
  canvas.pulseEdge("delegates to", 1200)

pulse step 4
  pulseCurrentEdge: "delegates to" → "verifies agreement"
  aliceDataStore: [] → [SD-BASE (accepted)]            ← data stores update
  kleindorfersDataStore: [] → [SD-BASE (accepted)]
  acceptedCount: 0 → 1
  canvas.addEdge("e-signed-1", "signed: SD-BASE ⊂⊃")  ← signed edge appears
  canvas.pulseEdge("verifies agreement", 1200)

pulse complete
  pulseActive: true → false
  canvas.clearPulse()
```

Each line is a semantic event extracted from the XMLUI trace. The key insight: "evaluates" triggers `agreementDecision` and "verifies agreement" triggers the data store updates — both synchronized to the pulse arrival, not fired immediately on term selection.

XMLUI's built-in `edgeInfoClick` handler worked fine because it fired synchronously from a user click. The pulse events fired asynchronously from `setTimeout`, outside the reactive transaction context.

The fix was to use XMLUI's own `Timer` component instead of `setTimeout`. Timer integrates with the reactive system the same way any other XMLUI component does. Its `onTick` handler runs inside the framework's event processing, so global assignments properly trigger ChangeListeners.

```xml
<Timer enabled="{pulse.active}" interval="{1200}" onTick="{() => {
  if (pulse.step < pulse.edges.length) {
    canvas.pulseEdge(pulse.edges[pulse.step], 1200);
    pulse = {
      active: true,
      edges: pulse.edges,
      step: pulse.step + 1,
      currentEdge: pulse.edges[pulse.step]
    }
  } else {
    canvas.clearPulse();
    pulse = { active: false, edges: pulse.edges, step: pulse.step, currentEdge: pulse.currentEdge }
  }
}}" />
```

The Timer drives the stepping. The component does the DOM animation. The reactive system handles everything else.

## Semantic choreography

With the Timer setting `pulse.currentEdge` at each step, the rest of the app can react to the pulse using semantic edge names. A `pulseReached` helper in `Globals.xs` encapsulates the check:

```javascript
function pulseReached(edgeLabel) {
  if (!pulse.active) return true;
  return pulse.edges.indexOf(pulse.currentEdge) > pulse.edges.indexOf(edgeLabel);
}
```

Components use it to gate their displays:

```xml
<!-- PersonAgentNode: show when "delegates personal agency" dot has arrived -->
<Text when="{offeredTerm !== '' && pulseReached('delegates personal agency')}">
  Received: {offeredTerm}
</Text>

<!-- EntityAgentNode: show when "evaluates" dot has arrived -->
<Text when="{offeredTerm !== '' && pulseReached('evaluates') && lookupTermPolicy(offeredTerm) === 'Accept'}">
  Accepted: {offeredTerm}
</Text>
```

The temporal sequence is just an array of edge labels:

```javascript
pulse.edges = [
  'delegates personal agency',
  'proffers',
  'delegates to',
  'evaluates',
  'verifies agreement'
]
```

Reorder the array and the animation, the choreography, and all the visibility gates adjust automatically. No step numbers, no timing calculations. The semantic names are the API.

The pulse state itself is a single atomic object to avoid intermediate render states where some fields are updated and others aren't:

```javascript
pulse = {
  active: true,
  edges: ['delegates personal agency', 'proffers', ...],
  step: 0,
  currentEdge: ''
}
```

## What ARIA labels turned out to be

The original gist argued that ARIA labels serve accessibility, testing, and AI reasoning. This experiment added a fourth use: animation targeting. But the deeper lesson is about what ARIA labels represent architecturally.

In a framework like React Flow where the library owns the DOM, ARIA labels are the one stable, semantic layer that survives re-renders. React will replace elements, reorder children, and reconcile virtual DOM trees. But the aria-label on a `<g>` element is a contract: this element means "evaluates", and when React recreates it, the new element will have the same label.

That makes aria-labels a reliable bridge between the reactive world (where state changes trigger re-renders) and the imperative world (where you need to find a specific SVG element and append a circle to it). `querySelector('[aria-label="evaluates"]')` works before the re-render, and it works after, because the semantic identity is preserved even when the DOM identity isn't.

The animation pulse travels the network by following semantic names, not DOM IDs or React refs. The business logic triggers when semantic edges are reached, not when timers expire. The visibility of each node's content is gated by whether a semantically-named edge has been passed. The whole system speaks in terms of what the edges mean, not how they're implemented.
