# Board

## DOING

- [/] T-006 priority:P1 title:Wire Square UI to FeedRepository (replace mock service) or Nexus UI blocs — awaiting user pick verify:user decision

## TODO

- [ ] T-004b priority:P2 title:Nexus test suite (repository + datasource + UI, in-memory drift) verify:flutter test PASS
- [ ] T-003 priority:P2 title:go_router shell + drawer routes for Vault/Nexus activation verify:app runs on target platform

## DONE

- [x] T-004 priority:P1 title:The Nexus — domain entities + NexusRepository contract, drift schema v2 (nexus_channels, channel_posts w/ retention, nexus_groups, group_messages, member_roles), local datasource, MockNexusRepository (tickers + setOnline + outbox), DI wiring, UI slice (Channels/Groups tabs, channel posts, group chat w/ outbox ticks); module unlocked in rail + drawer verify:dart analyze clean
- [x] T-007 priority:P1 title:Desktop polish pass — NavigationRail >=600px, centered 640px feed column, 1280x800 window, Vault master-detail, feed keyboard shortcuts (arrows/L) verify:dart analyze clean (test run deferred per user: no builds)
- [x] T-001 priority:P1 title:Data-layer contracts + drift schema + mock repos (Square & Vault) verify:dart analyze clean
- [x] T-002 priority:P1 title:Square vertical slice UI (model, mock service, shell+drawer, feed view) verify:dart analyze clean
- [x] T-005 priority:P1 title:Widget test suite — 12 tests PASS (model, mock service, feed UI, drawer, recycling persistence) verify:flutter test 12/12 PASS

## BLOCKED
