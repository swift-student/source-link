# Settings snapshots

PNG baselines are stored in Git LFS. Run `git lfs install` once after cloning and
`git lfs pull` to download them before running `make ui-test`.

`make ui-test` compares every named settings capture against its baseline. Missing
baselines fail; normal test runs never update them. Dimensions must match exactly.
The comparison allows RGB channel differences up to 12 and at most 0.1% changed
pixels to accommodate minor rendering noise. Failures include actual and expected
images in the Xcode test result attachments.

To intentionally update baselines, run `make record-snapshots`, review every changed
PNG, then run `make ui-test` to verify. Commit the PNGs and `.gitattributes` together;
Git LFS stores image contents and Git stores their pointers.

These are native macOS window captures. Use the same macOS version, display scale,
appearance, accent color, and window size when comparing or updating. The initial
baselines were captured on macOS 26.6.2 with Xcode 27 beta 6 in light appearance.
Native window chrome and font rendering changes may require reviewed updates.
