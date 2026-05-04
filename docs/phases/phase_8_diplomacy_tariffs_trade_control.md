# World at War (WAW v1.0) — Phase 8
## Diplomacy, Tariffs & Trade Control

Phase 8 introduces the first secure diplomacy layer of World at War.

This phase connects diplomacy with:

- market purchases
- tariffs
- trade embargoes
- cross-user logistics
- audit history
- notification-ready diplomatic events

The implementation remains server-authoritative, deterministic, auditable and protected against common economic exploits.

---

# 1. Core diplomatic model

## DiplomaticRelation

Diplomatic relations are directed and exist between users.

A relation `source_user -> target_user` means how the source user treats the target user.

Important rules:

- the inverse relation is independent
- changes are not reciprocal
- the target player is notified through a diplomatic event
- cities inherit the diplomacy of their owning user

Implemented relation states:

- neutral
- friendly
- ally
- hostile
- enemy
- war

Implemented trade policies:

- open
- embargoed

---

# 2. Diplomatic state rules

If no explicit diplomatic relation exists between two users, the system treats it as:

- neutral
- open
- 10% tariff

No database row is created for this implicit default.

| State | Trade | Tariff | Embargo |
|---|---:|---:|---|
| ally | allowed | 0% | no |
| friendly | allowed | 5% | no |
| neutral | allowed | 10% | no |
| hostile | allowed unless manually embargoed | 25% | manual allowed |
| enemy | blocked | none | automatic |
| war | blocked | none | automatic |

---

# 3. Embargo rules

Embargo is user-to-user and affects all cities owned by those users.

Manual embargo is only valid when the relation state is:

- hostile
- enemy
- war

Manual embargo is invalid for:

- neutral
- friendly
- ally

Automatic embargo applies when relation state is:

- enemy
- war

---

# 4. Tariff rules

Tariffs are fixed by diplomatic state in Phase 8.

Players cannot manually choose tariff percentages yet.

| State | Tariff |
|---|---:|
| ally | 0% |
| friendly | 5% |
| neutral | 10% |
| hostile | 25% |
| enemy | blocked |
| war | blocked |

Market tariff calculation:

- base_price = price_per_unit * amount
- tariff_amount = base_price * tariff_rate_basis_points / 10_000
- total_buyer_cost = base_price + tariff_amount

The buyer pays base price plus tariff.

The seller receives only the base price.

In Phase 8, tariff money is destroyed as a money sink.

Future design:

- if the buyer builds a National Treasury or Central Bank
- tariff income may go to a sovereign locked treasury balance instead of being destroyed

This is not implemented in Phase 8.

---

# 5. Diplomacy::ResolveTradeContext

Central service used to resolve trade and logistics permissions between two users.

Responsibilities:

- validate both users are persisted
- bypass diplomacy for same-user interactions
- resolve implicit default relations
- detect effective embargo
- calculate applied tariff
- return structured result

Rules:

- same-user trade and logistics are always allowed and tariff-free
- cross-user interaction is blocked if either direction has effective embargo
- tariff is based on the importer relation toward the exporter

Blocked reasons:

- importer_embargo
- exporter_embargo
- mutual_embargo

---

# 6. Market integration

Updated service:

- Market::BuyListing

Market purchases now resolve diplomacy before mutating economic state.

Security flow:

1. validate input
2. authorize buyer city ownership
3. lock listing, seller city and buyer city
4. reload locked records
5. validate listing availability
6. resolve diplomacy
7. block if embargoed
8. validate logistics capacity
9. validate seller trucks
10. calculate base price
11. calculate tariff
12. check buyer money against total buyer cost
13. deduct total buyer cost
14. update listing amount and status
15. create logistic operation
16. create ledger event with diplomatic snapshot

Important preserved invariant:

- LogisticOperation.market_total_price continues to represent the base seller price only

This prevents the seller from receiving tariff money when market sale settlement happens later.

Buyer ledger records:

- base_price
- seller_receives_price
- tariff_rate_basis_points
- tariff_amount
- total_buyer_cost
- tariff_destination: money_sink
- diplomatic snapshot

---

# 7. Logistics integration

Updated service:

- City::TransportResource

Rules:

- actor must own the origin city
- actor cannot extract resources from cities they do not own
- same-user logistics bypasses diplomacy
- cross-user logistics resolves diplomacy
- if either side has effective embargo, logistics is blocked
- no tariff is applied to direct logistics because it is not a market purchase

---

# 8. Diplomatic audit and notification base

Created model:

- DiplomaticRelationEvent

Diplomatic changes now generate auditable events.

Events are also notification-ready for the affected player.

When user A changes relation toward user B:

- only A -> B changes
- B -> A remains unchanged
- user B receives an unread DiplomaticRelationEvent

No automatic reciprocity exists.

---

# 9. Diplomacy::UpsertRelation

Secure entry point for changing diplomatic relations.

Responsibilities:

- validate actor and target users
- forbid self-relations
- validate relation state
- validate trade policy
- create or update the directed relation
- preserve inverse relation
- create audit event only if something effectively changed
- wrap operation in a transaction

---

# 10. Database hardening

Phase 8 includes SQL constraints for security and consistency.

Diplomatic relations:

- unique directed pair
- no self-relation
- valid relation states only
- valid trade policies only
- embargo requires negative diplomatic state

Diplomatic relation events:

- actor must be source
- source and target must be different
- valid action types only
- foreign keys to users and relation
- indexed by target/read state for future notifications

---

# 11. Security notes

Phase 8 protects against:

- manual tariff tampering from frontend
- bypassing embargo through market
- bypassing embargo through logistics
- self-relations
- duplicate directed relations
- invalid diplomacy states
- invalid embargo combinations
- accidental deletion of diplomatic audit history
- seller receiving tariff money incorrectly
- unauthorized extraction from another player's city

All critical calculations are server-authoritative.

---

# 12. Test coverage

Phase 8 added tests for:

- DiplomaticRelation
- DiplomaticRelationEvent
- Diplomacy::ResolveTradeContext
- Diplomacy::UpsertRelation
- market purchase with tariffs
- market blocked by embargo
- logistics blocked by embargo
- end-to-end diplomacy system flow

Final suite result:

193 runs, 856 assertions, 0 failures, 0 errors, 0 skips

---

# 13. Phase 8 implementation summary

Implemented:

- directed user-to-user diplomacy
- diplomatic states
- trade policy
- fixed tariff system
- effective embargo logic
- diplomacy resolver
- market tariff integration
- tariff money sink
- diplomacy snapshot in ledger
- cross-user logistics embargo control
- diplomatic audit events
- notification-ready unread events
- upsert service for safe diplomatic changes
- final system flow hardening tests

Not implemented yet:

- UI for diplomacy
- commercial treaties
- custom tariffs
- right of passage agreements
- stationing cost agreements
- foreign military bases
- national treasury / central bank
- war combat mechanics

Recommended next phase:

Phase 9 — Commercial Treaties & Diplomatic Agreements
