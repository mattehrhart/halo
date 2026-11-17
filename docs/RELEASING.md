# Making a release

1. Pick the version, for example `0.4.0`.
2. Set it in `CMakeLists.txt` (`project(halo VERSION ...)`).
3. Add a `## 0.4.0 - YYYY-MM-DD` section at the top of `CHANGELOG.md`. Write what changed for users.
4. Add a matching `<release>` entry to `packaging/io.github.mattehrhart.Halo.metainfo.xml`.
   Software stores show this text.
5. Commit, then tag and push:
   ```sh
   git tag -a v0.4.0 -m "Halo 0.4.0"
   git push origin main v0.4.0
   ```

CI builds `halo.flatpak`, runs the tests, and publishes a GitHub release with the changelog section
as its notes. The release fails if the changelog has no section for the tag, or if the version in
`CMakeLists.txt` does not match the tag.

To preview the notes: `tools/release-notes.py 0.4.0`.
