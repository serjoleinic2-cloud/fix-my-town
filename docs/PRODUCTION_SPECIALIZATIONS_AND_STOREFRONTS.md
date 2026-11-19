# Production specializations and distinct storefronts — implementation contract

Status: DESIGN APPROVED FOR IMPLEMENTATION; NOT YET IMPLEMENTED IN GAME.
Target branch: fix/traffic-backoff. Keep existing saves and installed Android package compatible.

## Gameplay goals
A building must offer an actual gameplay choice, not just a decorative upgrade. Specialization changes outputs, demand, logistics traffic, city incidents, appearance, and unlocks. Avoid adding tall towers; preserve visibility on portrait phones.

## Phase 1 — four village production chains
All four buildings need a portrait-safe detail panel: base level, specialization tree, current input/output per cycle, logistics connection, risks, upgrade cost, and one confirm action. Display locked branches and their prerequisites. Never silently change a selected branch.

| Building | Base output | Branch A | Branch B | Branch C |
| --- | --- | --- | --- | --- |
| Farm | crops | Field crops: grain for mill | Livestock: food for shops, veterinarian incidents | Greenhouse: premium produce, electricity demand |
| Sawmill | lumber | Boards: faster building supply | Furniture: residential comfort | Structural timber: bridge and infrastructure contracts |
| Mill | flour | Bakery supply: feeds cafes/shops | Animal feed: farm productivity | Wholesale: higher income, more truck traffic |
| Warehouse | storage | Cold chain: perishables | Construction hub: materials and repair supply | Distribution: longer reach, extra delivery vehicles |

Initial specialization unlock at building level 2; advanced perk at level 3. One active specialization per building. Reassignment costs money and pauses production, but never deletes a building. Existing saves default to 'basic' until a player chooses; never infer a branch from old level.

## City demand and missions
Village bridge -> first farm -> sawmill -> mill -> warehouse -> village market -> tourism. The bridge should require a construction supply contract, but never softlock an existing save. Each production chain has at least one shortage, breakdown, fire, road obstruction, and service dispatch scenario. Provide player-visible cause and actionable service call. Preserve emergency-vehicle priority and road safety.

## Balance requirements
Production is deterministic per tick with bounded offline progress; inputs and outputs cannot become negative. Missing input stops output and shows a shortage warning. Logistics distance and capacity affect deliveries; no instant teleport. Upgrades increase throughput at a corresponding maintenance, energy, traffic or incident risk. Ensure recovery from budget 0 remains possible.

## Visual variety: cafes and shops MUST NOT share one design
Current asset_catalog.gd maps supermarket to cafe.tscn — replace with distinct supermarket scene and unique icon. Also provide at least three recognizably different cafe exteriors (corner coffee shop, terrace bakery, roadside diner) and three shop exteriors (grocery, minimarket, village general store). Variants should use different footprint details, rooflines, signage, facade palette, awnings and props — not only recolors. Choose deterministic variant by stable building ID/seed; persist it so appearance does not change on reload. Keep shops/cafes 1–2 floors and readable from top-down/isometric portrait camera. No giant signage blocking nearby structures.

## UI and save compatibility
Keep existing building IDs and types, avoid replacing a cafe with a supermarket or vice versa. Store specialization ID, production state and visual variant in versioned save data. Unknown or missing fields fall back safely. Provide RU/EN strings. Do not create unscrollable cards: test on 360px and 540px widths, Android safe areas, and touch targets.

## Required verification before APK
- Existing city save loads unchanged and can be saved/reloaded.
- Different cafe and supermarket meshes/scenes are visibly distinguishable.
- Every branch can be selected, affects actual production, and survives reload.
- Production starvation, supply delivery, incident dispatch and bridge contract have tests.
- All existing tests pass, plus Android S21+ smoke test.
- Do not delete app data; install with adb install -r only if signature matches.

## Implementation sequencing
1. Unique supermarket scene and icon; cafe/shop variants; visual screenshots.
2. Versioned specialization state + four building panels + RU/EN labels.
3. Production and logistics simulation + event hooks + tests.
4. Village river/bridge unlock, missions and Android smoke test.

This document is a spec, not evidence of feature completion.
