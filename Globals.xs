function responsive(small, large) {
  return mediaSize.sizeIndex <= 2 ? small : large;
}

function makeStoreEntry(term, counterparty) {
  return { term: term, counterparty: counterparty, timestamp: new Date().toISOString(), country: 'USA' };
}

function lookupTermPolicy(term) {
  for (let i = 0; i < kleindorfersTerms.length; i++) {
    if (kleindorfersTerms[i].terms === term) return kleindorfersTerms[i].policy;
  }
  return 'Reject';
}

function pulseReached(edgeLabel) {
  if (!pulse.active && pulse.currentEdge === '') return false;
  if (!pulse.active) return true;
  return pulse.edges.indexOf(pulse.currentEdge) > pulse.edges.indexOf(edgeLabel);
}

function pulseNotReached(edgeLabel) {
  return !pulseReached(edgeLabel);
}

var layout = null;
