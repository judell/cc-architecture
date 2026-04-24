// --- Step machine runtime ---
// Interprets step declarations from getProcessFlowSteps() and writes to XMLUI globals.


function applyStep(index) {
  const steps = getProcessFlowSteps();
  const step = steps[index];
  stepIndex = index;
  phase = step.phase;
  phaseLabel = step.title;
  phaseMessage = step.message;
  buttonLabel = step.actionLabel;
  buttonEnabled = step.actionEnabled !== false;
}

function nextStep() {
  const steps = getProcessFlowSteps();
  const step = steps[stepIndex];

  if (step.restartOnAction) {
    window.__reactFlowCanvasApi.clearPulse();
    applyStep(0);
    return;
  }

  phase = step.runningPhase || step.phase;
  buttonEnabled = false;
  running = true;

  const api = window.__reactFlowCanvasApi;
  if (api) {
    const effects = step.run || [];
    for (let i = 0; i < effects.length; i++) {
      const effect = effects[i];
      if (effect.type === 'pulse' && effect.edge) {
        api.pulseEdge(effect.edge, effect.durationMs || pulseDuration);
      } else if (effect.type === 'pulseRoundTrip' && effect.edge) {
        api.pulseEdgeRoundTrip(effect.edge, effect.durationMs || pulseDuration);
      } else if (effect.type === 'clearPulse') {
        api.clearPulse();
      } else if (effect.type === 'addEdge') {
        api.addEdge(effect.id, effect.source, effect.target,
          effect.sourceHandle, effect.targetHandle, effect.label,
          effect.noArrow, effect.data);
      } else if (effect.type === 'removeEdge') {
        api.removeEdge(effect.edgeId);
      }
    }
  }
}

function completeCurrentStep() {
  running = false;
  const steps = getProcessFlowSteps();
  const step = steps[stepIndex];
  const nextIndex = resolveNextStep(step, stepIndex);
  applyStep(nextIndex);
}

function resolveNextStep(step, currentIndex) {
  const steps = getProcessFlowSteps();
  if (typeof step.next === 'number') {
    return step.next;
  }
  if (typeof step.next === 'string') {
    for (let i = 0; i < steps.length; i++) {
      if (steps[i].id === step.next) return i;
    }
  }
  return Math.min(currentIndex + 1, steps.length - 1);
}

// --- Node & edge builders ---

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
    {
      id: 'combine',
      title: '2',
      message: 'Combine per-city ICS files',
      actionLabel: 'Combine',
      phase: 1,
      runningPhase: 'combining',
      completeAfterMs: pulseDuration,
      run: [
        { type: 'pulse', edge: 'per-city .ics', durationMs: pulseDuration },
      ],
    },
    {
      id: 'convert',
      title: '3',
      message: 'Convert to JSON & cluster',
      actionLabel: 'Convert',
      phase: 2,
      runningPhase: 'converting',
      completeAfterMs: pulseDuration,
      run: [
        { type: 'pulse', edge: 'combined.ics', durationMs: pulseDuration },
      ],
    },
    {
      id: 'classify',
      title: '4',
      message: 'Classify with Claude AI',
      actionLabel: 'Classify',
      phase: 3,
      runningPhase: 'classifying',
      completeAfterMs: pulseDuration,
      run: [
        { type: 'pulse', edge: 'events.json', durationMs: pulseDuration },
      ],
    },
    {
      id: 'load',
      title: '5',
      message: 'Load events to Supabase',
      actionLabel: 'Load',
      phase: 4,
      runningPhase: 'loading',
      completeAfterMs: pulseDuration,
      run: [
        { type: 'pulse', edge: 'classified JSON', durationMs: pulseDuration },
      ],
    },
    {
      id: 'refresh',
      title: '6',
      message: 'Upsert to database',
      actionLabel: 'Upsert',
      phase: 5,
      runningPhase: 'refreshing',
      completeAfterMs: pulseDuration,
      run: [
        { type: 'pulse', edge: 'upsert events', durationMs: pulseDuration },
      ],
    },
    {
      id: 'display',
      title: '7',
      message: 'Query & render in frontend',
      actionLabel: 'Display',
      phase: 6,
      runningPhase: 'displaying',
      completeAfterMs: pulseDuration,
      run: [
        { type: 'pulse', edge: 'REST query', durationMs: pulseDuration },
      ],
    },
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

function makeNode(id, label, chrome) {
  const n = layout.nodes[id] || { x: 0, y: 0, width: 200, height: 150 };
  const data = chrome === false ? { label: label, chrome: false } : { label: label };
  return { id: id, position: { x: n.x, y: n.y }, data: data, width: n.width, height: n.height };
}

function getNodes() {
  return [
    makeNode('ics-feeds', 'ICS Feeds'),
    makeNode('scrapers', 'Scrapers'),
    makeNode('curator', 'Curator Picks'),
    makeNode('github-actions', 'GitHub Actions'),
    makeNode('combine', 'combine_ics'),
    makeNode('ics-to-json', 'ics_to_json'),
    makeNode('classifier', 'Claude AI'),
    makeNode('load-events', 'load-events'),
    makeNode('supabase', 'Supabase'),
    makeNode('frontend', 'Frontend'),
    makeNode('control', 'Control', false),
  ];
}

function getEdges() {
  return [
    {
      id: 'e-ics-gh',
      source: 'ics-feeds',
      target: 'github-actions',
      sourceHandle: 'right-top',
      targetHandle: 'left-top',
      data: { label: 'download feeds' },
    },
    {
      id: 'e-scr-gh',
      source: 'scrapers',
      target: 'github-actions',
      sourceHandle: 'right-top',
      targetHandle: 'left-bottom',
      data: { label: 'run scrapers' },
    },
    {
      id: 'e-cur-gh',
      source: 'curator',
      target: 'github-actions',
      sourceHandle: 'right-top',
      targetHandle: 'left-bottom',
      data: { label: 'collect picks' },
    },
    {
      id: 'e-gh-combine',
      source: 'github-actions',
      target: 'combine',
      sourceHandle: 'right-top',
      targetHandle: 'left-top',
      data: { label: 'per-city .ics' },
    },
    {
      id: 'e-combine-json',
      source: 'combine',
      target: 'ics-to-json',
      sourceHandle: 'right-top',
      targetHandle: 'left-top',
      data: { label: 'combined.ics' },
    },
    {
      id: 'e-json-classify',
      source: 'ics-to-json',
      target: 'classifier',
      sourceHandle: 'right-top',
      targetHandle: 'left-top',
      data: { label: 'events.json' },
    },
    {
      id: 'e-classify-load',
      source: 'classifier',
      target: 'load-events',
      sourceHandle: 'bottom-left',
      targetHandle: 'top-left',
      data: { label: 'classified JSON' },
    },
    {
      id: 'e-load-supa',
      source: 'load-events',
      target: 'supabase',
      sourceHandle: 'right-top',
      targetHandle: 'left-top',
      data: { label: 'upsert events' },
    },
    {
      id: 'e-supa-front',
      source: 'supabase',
      target: 'frontend',
      sourceHandle: 'right-top',
      targetHandle: 'left-top',
      data: { label: 'REST query' },
    },
  ];
}

// --- Helpers ---

function saveLayout() {
  window.saveLayout();
}

function responsive(small, large) {
  return mediaSize.sizeIndex <= 2 ? small : large;
}
