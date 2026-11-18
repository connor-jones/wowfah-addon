# Changelog

## 0.6.2

- New: a **Save and sync** button in the ledger window, and the command `/sync`, for people who run the optional
  wowfah Sync app for Windows (wowfah.com/sync). The game only saves an addon's data when you log out or the interface
  reloads, so this reloads it for you and the app uploads your ledger a few seconds later, without logging out.
- The button is greyed out until wowfah Sync is set up on the computer, and it will not reload while you are in combat.
- **Upload to wowfah.com** is now called **Manual upload**: it shows a code to paste on the site and needs nothing else
  installed.

## 0.6.0

- A cleaner look: flat dark panels with thin borders in the ledger, upload and settings windows, and coin icons on
  the headline profit figures.
- The minimap button now uses the standard minimap button library, so it sits correctly on reskinned or square
  minimaps and works with button collectors. Its position and your hide setting are kept.
- Bar addons such as Titan Panel and ElvUI can show wowfah Ledger: the text is today's profit.
- wowfah Ledger has a page in the game's own Options window with the same three settings.
- The game's addon list by the minimap shows today's profit when you hover over wowfah Ledger.
- Faster: the saved records are read once and reused instead of on every refresh.

## 0.5.0

- No commands needed any more. A wowfah button on the minimap opens your ledger (drag it to move it, right-click for an
  upload code), and there is a wowfah Ledger button on the auction house and on the mailbox.
- The ledger window is redrawn: profit for today, 7 days, 30 days and all time as four cards, a tidy list of recent
  activity, an Upload button and a Settings panel with the sharing options.
- A "This character only" tick box in the window.
- `/wowfah minimap` hides or shows the minimap button.

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
