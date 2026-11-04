# Build a Workshop package

This source tree includes the Lua runtime and Workshop bootstrap. It omits
account-specific publishing state and the original listing's Steam file ID.

From the repository root, build a new upload folder:

```powershell
python tools/package_workshop.py --output dist/workshop-next --preview workshop/preview.png
```

Use a new output directory each time. Update VERSION and the info.txt version
fields together for a new release. The package contains Lua source, the
Workshop bootstrap, README, license, preview and file hashes. It contains no
game files, saves or native binaries.

For upload through the game, copy the generated world-bridge directory into
the game's mods/mod_upload directory, then use Mods on the title screen.
Steam credits the signed-in uploading account. The AUTHOR field does not
change that attribution.

After the first upload, preserve the STEAM_FILE_ID in your local upload copy
and future updates to that same item. Keep account credentials and publishing
state outside the repository. Test a new package without a manual installation
before publishing it, and verify the downloaded Workshop files afterward.

References: [DFHack mod packaging](https://docs.dfhack.org/en/53.16-r3/docs/guides/modding-guide.html)
and [Bay 12 mod upload guide](https://www.bay12games.com/dwarves/modding_guide.html).
