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

Unzip the download, then:

- **Windows:** double click `Windows - wowfah Ledger.bat` and choose 1.
- **Mac:** double click `Mac - wowfah Ledger.command` and choose 1.

The installer finds World of Warcraft, copies the `WowfahLedger` folder into
`_forever_/Interface/AddOns/` and tells you what to do next. Both installers are plain text scripts.
Run it again and choose 2 to find your saved ledger file and open the upload page.

By hand: copy the `WowfahLedger` folder into `World of Warcraft/_forever_/Interface/AddOns/`,
then restart the game or type `/reload`.

## Use

- Click the wowfah button on the minimap to open the ledger. There is also a button on the auction house and the
  mailbox. `/wowfah` does the same.
- **Manual upload** in the ledger window shows a code to paste at wowfah.com/ledger/upload. It needs nothing else.
- **Save and sync** (or `/sync`) is for people who run the optional wowfah Sync app for Windows (wowfah.com/sync): it
  reloads the interface so the game saves your ledger, and the app uploads it a few seconds later. The button is
  greyed out until the app is set up on the computer.
- `/wowfah export` shows a code to paste at wowfah.com/ledger/upload.
- `/wowfah path` tells you which saved file to upload.
- `/wowfah share on` or `/wowfah share off` controls whether your uploads add anonymous sale prices to the site.
- `/wowfah debug` saves technical details that help with bug reports.

The game only writes the saved file when you log out or the interface reloads (`/reload`), so do one of those before uploading the
saved file by hand.

## Getting your data onto wowfah.com

An addon cannot use the internet, so nothing is sent automatically. Either upload
`WTF/Account/YOUR_ACCOUNT/SavedVariables/WowfahLedger.lua`, or paste the export code.

## Development

The addon's files are at the top of this repository, which is the layout the addon sites expect.

- `luajit tests/run.lua` runs the logic against a fake mailbox, auction house and loot window.
- `tools/package.sh` builds two zips: the addon alone, and the addon with the installers from `installer/`.
- Pushing a tag such as `v0.6.0` publishes a release (see `.github/workflows/release.yml`).
- `Libs/` holds four small standard libraries, unchanged; see `Libs/README.md`.

Licence: MIT. Not affiliated with Blizzard Entertainment.
