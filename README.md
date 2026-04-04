# MyTerms

An interactive demo of [IEEE Std 7012-2025](https://myterms.info/), the IEEE Standard for Machine Readable Personal Privacy Terms.

[![MyTerms Overview](myterms-overview.png)](https://myterms.info/)

## What is IEEE 7012?

IEEE 7012 (aka "MyTerms," much as IEEE 802.11 is nicknamed "Wi-Fi") defines how individuals can proffer their own privacy terms to organizations they interact with online. Published in January 2026 by the IEEE Society on Social Implications of Technology, the standard is freely available through the [IEEE GET Program](https://myterms.info/).

Today's internet runs on "notice and consent" -- organizations present take-it-or-leave-it terms of service, and individuals can only agree or walk away. IEEE 7012 reverses this dynamic. It gives individuals the role of *first party* in contractual agreements, enabling them to:

- **Choose** standard-form privacy agreements from a public roster maintained by a neutral nonprofit
- **Proffer** those terms to organizations via a software agent
- **Record** signed agreements in their own data store, with identical copies kept by both sides

This is analogous to how Creative Commons lets artists choose standard licenses for their work -- except here, individuals choose standard privacy terms for their personal data.

## What this demo shows

This interactive visualization walks through the core IEEE 7012 workflow:

1. **Alice** (the person) selects a privacy term to proffer -- either SD-BASE (a base-level service delivery agreement) or PDC-AI (controlling use of personal data for AI training)
2. **Alice's Agent** receives the chosen term and proffers it to the entity's agent
3. **Possible MyTerms Agreements** lists the available standard-form agreements from the public roster
4. **Kleindorfers Agent** (the entity's agent) evaluates the proffered term against Kleindorfers' policies and accepts or rejects it
5. **Kleindorfers** (the entity) maintains its own policy table showing which terms it will accept
6. When both sides agree, the signed agreement is recorded in both parties' data stores

The flow of arrows shows delegation of agency (person to agent), proffering of terms, evaluation, and verification -- the key interactions defined in Section 5 of the standard.

## Live demo

**https://judell.github.io/myterms/**

## Layout

Node positions are defined in `layout.json` for easy adjustment without changing application code.
