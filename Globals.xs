// --- Phase machine ---

function nextStep() {
  if (phase === 0) collect();
  else if (phase === 1) combine();
  else if (phase === 2) convert();
  else if (phase === 3) classify();
  else if (phase === 4) load();
  else if (phase === 5) refresh();
  else if (phase === 6) display();
  else if (phase === 7) startOver();
}

function collect() {
  phase = 'collecting';
  buttonEnabled = false;
  window.__reactFlowCanvasApi.pulseEdge('download feeds', pulseDuration);
  window.__reactFlowCanvasApi.pulseEdge('run scrapers', pulseDuration);
  window.__reactFlowCanvasApi.pulseEdge('collect picks', pulseDuration);
}

function combine() {
  phase = 'combining';
  buttonEnabled = false;
  window.__reactFlowCanvasApi.pulseEdge('per-city .ics', pulseDuration);
}

function convert() {
  phase = 'converting';
  buttonEnabled = false;
  window.__reactFlowCanvasApi.pulseEdge('combined.ics', pulseDuration);
}

function classify() {
  phase = 'classifying';
  buttonEnabled = false;
  window.__reactFlowCanvasApi.pulseEdge('events.json', pulseDuration);
}

function load() {
  phase = 'loading';
  buttonEnabled = false;
  window.__reactFlowCanvasApi.pulseEdge('classified JSON', pulseDuration);
}

function refresh() {
  phase = 'refreshing';
  buttonEnabled = false;
  window.__reactFlowCanvasApi.pulseEdge('upsert events', pulseDuration);
}

function display() {
  phase = 'displaying';
  buttonEnabled = false;
  window.__reactFlowCanvasApi.pulseEdge('REST query', pulseDuration);
}

function startOver() {
  window.__reactFlowCanvasApi.clearPulse();
  phase = 0;
  phaseLabel = '1';
  phaseMessage = 'Collect from sources';
  buttonLabel = 'Collect';
  buttonEnabled = true;
}

function onCollectDone() {
  phase = 1;
  phaseLabel = '2';
  phaseMessage = 'Combine per-city ICS files';
  buttonLabel = 'Combine';
  buttonEnabled = true;
}

function onCombineDone() {
  phase = 2;
  phaseLabel = '3';
  phaseMessage = 'Convert to JSON & cluster';
  buttonLabel = 'Convert';
  buttonEnabled = true;
}

function onConvertDone() {
  phase = 3;
  phaseLabel = '4';
  phaseMessage = 'Classify with Claude AI';
  buttonLabel = 'Classify';
  buttonEnabled = true;
}

function onClassifyDone() {
  phase = 4;
  phaseLabel = '5';
  phaseMessage = 'Load events to Supabase';
  buttonLabel = 'Load';
  buttonEnabled = true;
}

function onLoadDone() {
  phase = 5;
  phaseLabel = '6';
  phaseMessage = 'Upsert to database';
  buttonLabel = 'Upsert';
  buttonEnabled = true;
}

function onRefreshDone() {
  phase = 6;
  phaseLabel = '7';
  phaseMessage = 'Query & render in frontend';
  buttonLabel = 'Display';
  buttonEnabled = true;
}

function onDisplayDone() {
  phase = 7;
  phaseLabel = '';
  phaseMessage = 'Pipeline complete';
  buttonLabel = 'Start Over';
  buttonEnabled = true;
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

function diagramPhase(diagram, fallbackPhase) {
  if (diagram && diagram.phase !== undefined) {
    return diagram.phase;
  }
  return fallbackPhase;
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
