# WeakAurasForever distribution credits

WeakAurasForever is an independent fork of WeakAuras by the WeakAuras Team and
contributors. The upstream source is <https://github.com/WeakAuras/WeakAuras2>.
The initial fork used commit `91c52bc92f86ae4a5232913039225a0032aca048`;
subsequent upstream changes retain their original history and notices.

WeakAurasForever is distributed under GNU GPL version 2. The complete license
is included as `WAF/LICENSE`. Original copyright notices and in-addon credits
are retained. Source and change history are available at
<https://github.com/Jared-Mac/WeakAurasForever>.

## Fork changes

Changes made from 2026-09-20 through 2026-09-23 add the Forever trigger system,
native displays, presets, editor compatibility, WAF package identity, standalone
saved data, media relocation, and branding. `WAF/FOREVER.md` describes the
behavior and validation limits; `WAF/MIGRATION.md` describes save handling.

Modified source files carry dated fork notices. The package builder also adds
a notice to each addon-owned Lua, XML, or TOC file whose media paths it relocates.
These notices were completed for distribution on 2026-09-27. Embedded libraries
are copied without modification.

## Libraries and media

Embedded libraries come from the official WeakAuras 5.22.0 release archive,
verified against the pinned SHA-256 in `tools/build_forever.py`. Their original
copyright, license headers, and accompanying license files are retained under
`WAF/Libs` and `WAFOptions/Libs`. Each library retains its own license.

Original WeakAuras media remains bundled with its existing notices. The Fira
and PT Sans font licenses are included in `WAF/Media/Fira License.txt` and
`WAF/Media/PT Sans License.txt`.

The WAF infinity-aura logo is original artwork generated for this fork on
2026-09-23 without a reference image or upstream logo. It is distributed under
GPLv2. Its source and generation details are in `assets/branding` in the source
repository; the addon uses `WAF/Media/Textures/WAF.tga`.
