# Stored Research Counter

This addon counts your stored Cataloged Research, that is Cataloged Research sitting in your bag but not added to your Total Cataloged Research yet. It is exposed as an LDB data source feed, so you can display it with any addon that displays LDB data sources.

This is a first implementation, more options will be added later.

## Usage

Open the config panel with `/src config`

You can pick your format from a dropdown list. Configuration is saved in profiles. When selecting other formatting options, the output gets updated real time.

## Examples in LDB display addons
A few examples on how to add Stored Cataloged Research output to your LDB display addons.

### ElvUI example

* Go to `/ec` (ElvUI config panel)
* `DataTexts`
* `Panels`
* Pick a panel and click the dropdown of a `Position`
* Select `Stored Research`