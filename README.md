# wowfah Ledger

An addon for World of Warcraft: Forever that records your auction house sales, purchases, expired and
cancelled auctions, so you can see your profit and loss in game and on [wowfah.com](https://wowfah.com/ledger).

## What it records

| Event | Where it comes from | What is kept |
|---|---|---|
| Sale | Auction house mail | Item, quantity, sale price, auction house cut |
| Purchase | Auction house mail | Item, quantity, price paid |
| Expired or cancelled | Auction house mail | Item and the deposit you lost |
| Posted | When you post an auction | Item, quantity, asking price, deposit |

It also notes the ids of your own auctions and the prices you browse past while the auction house is open.
Other players' names are never stored.

## Install

1. Copy the `WowfahLedger` folder into `World of Warcraft/_forever_/Interface/AddOns/`.
2. Restart the game or type `/reload`.

## Use

- `/wowfah` opens the ledger window.
- `/wowfah export` shows a code to paste at wowfah.com/ledger/upload.
- `/wowfah path` tells you which saved file to upload.
- `/wowfah share on` or `/wowfah share off` controls whether your uploads add anonymous sale prices to the site.
- `/wowfah debug` saves technical details that help with bug reports.

The game only writes the saved file when you log out or type `/reload`, so do that before uploading.

## Getting your data onto wowfah.com

An addon cannot use the internet, so nothing is sent automatically. Either upload
`WTF/Account/YOUR_ACCOUNT/SavedVariables/WowfahLedger.lua`, or paste the export code.

## Development

`luajit tests/run.lua` runs the logic against a fake mailbox and auction house. `tools/package.sh` builds
the zip. The code is plain Lua with no libraries.

Licence: MIT. Not affiliated with Blizzard Entertainment.
