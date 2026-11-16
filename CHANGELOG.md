# Changelog

## 0.4.0

- New, and off until you say yes: the addon can note what drops where. It asks once at login. If you agree it counts
  loot from creatures, gathering nodes, fishing, opened containers, what vendors sell and what quests reward, with the
  zone, and includes that when you upload. No character names are recorded. Turn it on or off with `/wowfah loot on`
  and `/wowfah loot off`, or the new checkbox in the ledger window.
- The saved file no longer grows for ever: it keeps your newest 20,000 records. The website keeps everything you
  have already uploaded.
- `/wowfah debug` reports which loot functions the game provides.

## 0.3.0

- A mail is now recorded when its gold or items have actually left it, not when you click. Before, a take
  that failed (full bags, a busy mail server) and was tried again could be counted twice.
- Large orders are recorded with the quantity on the invoice. Before, only the first stack in the mail
  was counted.
- Unsold auctions that come back in several stacks are recorded once, with the full quantity.
- A sale is matched to the posting at the same price, so a posting that sells in several lots keeps the
  right auction id, and the deposit lost on the unsold part is worked out from the quantity.
- The "posted" record carries the auction's id, so wowfah.com can tell which of your auctions are still up.

## 0.2.1

The installers accept the game folder under either name guides give for it (`_forever_` or `forever`).

## 0.2.0

The download now includes an installer for Windows and for Mac. It finds the game folder, copies the
addon in, and can find your saved ledger file and open the upload page. The addon itself is unchanged.

## 0.1.0

First version: sales, purchases, expired and cancelled auctions from mail, posting records, in-game
ledger window, export code, debug command.
