function responsive(small, large) {
  return mediaSize.sizeIndex <= 2 ? small : large;
}

function makeStoreEntry(term, counterparty) {
  return {
    term: term,
    counterparty: counterparty,
    timestamp: new Date().toISOString(),
    country: "USA",
  };
}

function lookupTermPolicy(term) {
  for (let i = 0; i < kleindorfersTerms.length; i++) {
    if (kleindorfersTerms[i].terms === term) return kleindorfersTerms[i].policy;
  }
  return "Reject";
}

function pulseReached(edgeLabel) {
  if (!pulse.active && pulse.currentEdge === "") return false;
  if (!pulse.active) return true;
  return (
    pulse.edges.indexOf(pulse.currentEdge) > pulse.edges.indexOf(edgeLabel)
  );
}

function pulseNotReached(edgeLabel) {
  return !pulseReached(edgeLabel);
}

function onPulseEdgeChange(change) {
  if (change.newValue === "proffers" && offeredTerm !== "") {
    agreementDecision =
      kleindorfersTerms.find(function (t) {
        return t.terms === offeredTerm;
      }) &&
      kleindorfersTerms.find(function (t) {
        return t.terms === offeredTerm;
      }).policy === "Accept"
        ? "yes"
        : "no";
  }
}

function nextStep() {
  if (phase === 0) delegate();
  else if (phase === 1) getTerms();
  else if (phase === 4) proffer();
  else if (phase === 5) applyPolicy();
  else if (phase === 6) agree();
  else if (phase === 7) startOver();
}

function delegate() {
  offeredTerm = "";
  agreementDecision = "";
  acceptedCount = 0;
  kleindorfersTerms = [
    { terms: "SD-BASE", policy: "Accept" },
    { terms: "PDC-AI", policy: "Reject" },
  ];
  window.__reactFlowCanvasApi.clearPulse();
  window.__reactFlowCanvasApi.pulseEdge("delegates agency", pulseDuration);
  window.__reactFlowCanvasApi.pulseEdge("delegates personal agency", pulseDuration);
  hasDelegated = true;
  phase = "delegating";
  buttonEnabled = false;
}

function getTerms() {
  phase = 2;
  phaseLabel = stepLabel(2);
  phaseMessage = 'Alice looks up terms';
  buttonEnabled = false;
  const api = window.__reactFlowCanvasApi;
  api.addEdge('e-p-ag', 'person', 'agreements', 'right-top', 'left-top', 'lookup');
  api.pulseEdgeRoundTrip('lookup', pulseDuration);
  roundTrip = 'lookup';
}

function sendTerm() {
  phase = 'sending';
  buttonEnabled = false;
  const api = window.__reactFlowCanvasApi;
  api.addEdge('e-p-pa-send', 'person', 'person-agent', 'bottom-right', 'top-right', 'send', false, { labelPosition: 60 });
  pulse = { active: true, edges: ['send'], step: 0, currentEdge: 'lookup' };
}

function cleanupSendEdge() {
  window.__reactFlowCanvasApi.removeEdge('e-p-pa-send');
}

function proffer() {
  phase = 'proffering';
  buttonEnabled = false;
  pulse = { active: true, edges: ['proffers'], step: 0, currentEdge: 'lookup' };
}

function applyPolicy() {
  phase = 'consulting';
  buttonEnabled = false;
  const api = window.__reactFlowCanvasApi;
  api.addEdge('e-ea-consult', 'entity-agent', 'entity', 'bottom-left', 'top-left', 'consults policy');
  api.pulseEdgeRoundTrip('consults policy', pulseDuration);
  roundTrip = 'consults policy';
}

function onRoundTripComplete() {
  if (roundTrip === 'lookup') {
    window.__reactFlowCanvasApi.removeEdge('e-p-ag');
    phase = 3;
    phaseLabel = stepLabel(3);
    phaseMessage = "Choose a term from Alice's list";
    buttonLabel = '';
    buttonEnabled = false;
  }
  if (roundTrip === 'consults policy') {
    window.__reactFlowCanvasApi.removeEdge('e-ea-consult');
    if (agreementDecision === 'yes') {
      phase = 6;
      phaseLabel = stepLabel(6);
      phaseMessage = "Kleindorfer's agent verifies agreement";
      buttonLabel = 'Verify';
      buttonEnabled = true;
    } else {
      alicePersonalDataStore = [...alicePersonalDataStore, makeStoreEntry(offeredTerm + ' (rejected)', "Kleindorfer's")];
      kleindorfersOrgDataStore = [...kleindorfersOrgDataStore, makeStoreEntry(offeredTerm + ' (rejected)', 'Alice')];
      phase = 7;
      phaseLabel = stepLabel(6);
      phaseMessage = 'Agreement rejected';
      buttonLabel = 'Start Over';
      buttonEnabled = true;
    }
  }
  if (roundTrip === 'verifies agreement') {
    window.__reactFlowCanvasApi.removeEdge('e-ea-verify');
    kleindorfersTerms = kleindorfersTerms.map(function(t) {
      return t.terms === offeredTerm ? { terms: t.terms, policy: agreementDecision === 'yes' ? 'Accept' : 'Reject' } : t;
    });
    status = agreementDecision === 'yes' ? 'accepted' : 'rejected';
    alicePersonalDataStore = [...alicePersonalDataStore, makeStoreEntry(offeredTerm + ' (' + status + ')', "Kleindorfer's")];
    kleindorfersOrgDataStore = [...kleindorfersOrgDataStore, makeStoreEntry(offeredTerm + ' (' + status + ')', 'Alice')];
    if (agreementDecision === 'yes') {
      acceptedCount = acceptedCount + 1;
      window.__reactFlowCanvasApi.addEdge('e-signed-' + acceptedCount, 'person', 'entity-agent', 'right-magnet', 'left-magnet', 'signed: ' + offeredTerm + ' \u2282\u2283', true);
    }
    phase = 7;
    phaseLabel = stepLabel(7);
    phaseMessage = agreementDecision === 'yes' ? 'Agreement signed and posted to ledger' : 'Agreement rejected';
    buttonLabel = 'Start Over';
    buttonEnabled = true;
  }
  roundTrip = '';
}

function agree() {
  phase = 'verifying';
  buttonEnabled = false;
  const api = window.__reactFlowCanvasApi;
  api.addEdge('e-ea-verify', 'entity-agent', 'entity', 'bottom-left', 'top-left', 'verifies agreement', false, { labelPosition: 30 });
  api.pulseEdge('verifies agreement', pulseDuration * 2);
  roundTrip = 'verifies agreement';
}

function startOver() {
  const api = window.__reactFlowCanvasApi;
  // Remove all signed edges
  for (let i = 1; i <= acceptedCount; i++) {
    api.removeEdge('e-signed-' + i);
  }
  offeredTerm = '';
  agreementDecision = '';
  acceptedCount = 0;
  kleindorfersTerms = [
    { terms: 'SD-BASE', policy: 'Accept' },
    { terms: 'PDC-AI', policy: 'Reject' },
  ];
  api.clearPulse();
  phase = 1;
  phaseLabel = stepLabel(2);
  phaseMessage = 'Alice looks up terms';
  buttonLabel = 'Lookup';
  buttonEnabled = true;
}

function saveLayout() {
  const json = JSON.stringify(window.__reactFlowCanvasApi.getLayout(), null, 2);
  const blob = new Blob([json], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'layout.json';
  a.click();
  URL.revokeObjectURL(url);
}

function makeNode(id, label, extra) {
  const n = layout.nodes[id];
  const data = { label: label };
  if (extra) {
    for (const k in extra) {
      data[k] = extra[k];
    }
  }
  return { id: id, position: { x: n.x, y: n.y }, data: data, width: n.width, height: n.height };
}

function getNodes() {
  return [
    makeNode("person", "Alice", { magnetY: "12%" }),
    makeNode("person-agent", "Alices Agent"),
    makeNode("agreements", "Agreements"),
    makeNode("entity-agent", "Kleindorfer's Agent", { magnetY: "22%" }),
    makeNode("entity", "Kleindorfer's"),
    makeNode("control", "Control", { chrome: false }),
  ];
}

function getEdges() {
  return [
    {
      id: "e-p-pa",
      source: "person",
      target: "person-agent",
      sourceHandle: "bottom-left",
      targetHandle: "top-left",
      data: { label: "delegates personal agency", labelPosition: 40 },
    },
    {
      id: "e-pa-ea",
      source: "person-agent",
      target: "entity-agent",
      sourceHandle: "right-top",
      targetHandle: "left-bottom",
      data: { label: "proffers" },
    },
    {
      id: "e-ea-e",
      source: "entity",
      target: "entity-agent",
      sourceHandle: "top-right",
      targetHandle: "bottom-right",
      data: { label: "delegates agency", labelPosition: 30 },
    },
  ];
}

var layout = null;
var status = '';
var hasDelegated = false;

function stepLabel(n) {
  return String(n - (hasDelegated ? 1 : 0));
}
