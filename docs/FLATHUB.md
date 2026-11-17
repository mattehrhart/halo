# Publishing on Flathub

Bazaar is a Flatpak store that shows Flathub's catalog, so once Halo is on Flathub it appears in
Bazaar with no separate submission.

## Already done

- App ID `io.github.mattehrhart.Halo` (the `io.github.<user>.<App>` form Flathub accepts for
  GitHub-hosted projects; it requires the repository to be `github.com/mattehrhart/halo`).
- Manifest builds with no network: OpenLinkHub from a release tarball with a checksum, Go modules
  from `packaging/openlinkhub-go-sources.json`.
- Metadata (`packaging/*.metainfo.xml`) with description, screenshots, release notes, license and
  content rating; desktop file; scalable icon.
- GPL-3.0-or-later license; the OpenLinkHub patch is installed beside its license.

## Still to do before submitting

1. **Tag a release** and point the manifest at it. Flathub builds from a fixed tag or commit, not
   from a folder: replace the `dir` source of the `halo` module with
   `{"type": "git", "url": "https://github.com/mattehrhart/halo.git", "tag": "v0.3.0", "commit": "<sha>"}`.
   The patch, module list and Go sources then need to come from that same checkout or be copied
   into the Flathub repository next to the manifest.
2. **Run the linter** and fix what it reports:
   ```sh
   flatpak install flathub org.flatpak.Builder
   flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest io.github.mattehrhart.Halo.json
   flatpak run --command=flatpak-builder-lint org.flatpak.Builder repo repo
   ```
3. **Permissions review.** These will be questioned and need a justification in the pull request:
   - `--device=all`: needed to open the devices' hidraw nodes; there is no narrower permission.
   - `--share=network`: Halo talks to the bundled service over localhost.
4. **The udev rule.** Flathub apps cannot install udev rules. Halo shows the user a command.
   Reviewers generally accept this for hardware apps, but say so in the pull request.
5. **Naming and trademarks.** "Halo" is also a well-known game title; Flathub may ask for a more
   distinctive name or summary. Screenshots show product names; keep the "not affiliated" line.
6. **Screenshots.** Flathub prefers captures of the real window with its frame and shadow, on the
   default light or dark theme. The current ones are frameless captures.
7. **Real-hardware testing** beyond two devices, or say plainly in the description what is tested.

## Submitting

1. Fork <https://github.com/flathub/flathub> and branch from `new-pr`.
2. Add `io.github.mattehrhart.Halo.json` (and the files it references) at the top level.
3. Open a pull request against `new-pr`, fill in the checklist, and answer review comments.
   A bot builds the app; `bot, build` in a comment re-runs it.
4. When approved, Flathub creates `github.com/flathub/io.github.mattehrhart.Halo` and gives you
   write access. Updates are pull requests there (bump the tag and commit).
5. Optional: verify the app on flathub.org (GitHub login as `mattehrhart`) for the verified badge.
