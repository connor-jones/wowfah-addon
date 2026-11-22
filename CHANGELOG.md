# Changelog

## 0.8.1

- New: a **Deals** view in the ledger window. It lists items on your auction house whose lowest listing is at least a
  quarter under the market price and that sell five or more a day, with the profit each after the cut. It needs the
  wowfah Sync app, and the list is as old as the last sync, so a deal may already be gone.
- The line beside the price box when you post no longer says which listing sells first.

## 0.8.0

- New: **market prices on every item tooltip**, for your own auction house, when the wowfah Sync app is running. Each
  tooltip shows the market price, the lowest listing and roughly how many sell a day. Prices come from wowfah.com and
  refresh about every half hour; type `/reload` to load the newest list.
- New: **"Vendor pays more"** appears on a tooltip when a vendor would pay at least as much as the auction house after
  its 5% cut.
- New: `/wowfah bags` adds up what your bags would fetch at the auction house and lists what is better sold to a vendor.
- The line beside the price box when you post now shows the market price and the lowest listing.

## 0.7.0

- New: **your own prices on item tooltips**. Hover any item to see what you sold it for, what you paid, and the lowest
  price you last saw for it at the auction house. Switch it off in Settings if you prefer a clean tooltip.
- New: the same figures appear **beside the price box when you post an auction**, so you can price without leaving the
  window. The addon only shows them. It never sets a price, posts, buys or cancels anything.
- New: the ledger window has six views: Recent, **Items** (profit per item), **Days**, **Characters**, **Holding** (bought
  and not sold again) and **My auctions**. Click one of the four profit cards to choose the period, and scroll the list
  for more rows.
- New: **My auctions** compares each of your auctions with the lowest price you last browsed for that item and marks the
  ones that have been beaten. You also get one line in chat when you open the auction house.
- New: the window tells you how many records are **not on wowfah.com yet** and when you last uploaded.
- New: your gold is noted at login and logout, so wowfah.com can show it over time once you upload.
- With the wowfah Sync app, tooltips can also show the wowfah market price for the items on your watchlist and in your
  ledger (needs a newer version of the app).

## 0.6.3

- First version published on CurseForge. The addon itself is the same as 0.6.2.

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
