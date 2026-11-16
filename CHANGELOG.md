# Changelog

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
