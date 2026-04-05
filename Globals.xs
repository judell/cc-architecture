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

function onPulseEdgeChange(change) {
  if (change.newValue === 'proffers' && offeredTerm !== '') {
    agreementDecision = (kleindorfersTerms.find(function(t) { return t.terms === offeredTerm }) && kleindorfersTerms.find(function(t) { return t.terms === offeredTerm }).policy === 'Accept') ? 'yes' : 'no';
  }
  if (change.newValue === 'verifies agreement' && agreementDecision !== '') {
    kleindorfersTerms = kleindorfersTerms.map(function(t) {
      return t.terms === offeredTerm ? { terms: t.terms, policy: agreementDecision === 'yes' ? 'Accept' : 'Reject' } : t;
    });
    aliceDataStore = [...aliceDataStore, makeStoreEntry(offeredTerm + ' (' + (agreementDecision === 'yes' ? 'accepted' : 'rejected') + ')', 'Kleindorfers')];
    kleindorfersDataStore = [...kleindorfersDataStore, makeStoreEntry(offeredTerm + ' (' + (agreementDecision === 'yes' ? 'accepted' : 'rejected') + ')', 'Alice')];
    if (agreementDecision === 'yes') {
      acceptedCount = acceptedCount + 1;
      canvas.addEdge('e-signed-' + acceptedCount, 'person', 'entity-agent', 'right-magnet', 'left-magnet', 'signed: ' + offeredTerm + ' \u2282\u2283', true);
    }
    phase = 0;
  }
}

var layout = null;
