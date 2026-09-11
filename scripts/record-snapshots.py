"""Record UI attachments, then copy reviewed candidates out of the test sandbox."""
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
baselines = root / "app/Tests/XedLinkUITests/Snapshots"
with tempfile.TemporaryDirectory(prefix="source-link-snapshots-") as temporary:
    temporary = Path(temporary)
    result = temporary / "Recording.xcresult"
    subprocess.run([
        "make", "ui-test", "SOURCE_LINK_RECORD_SNAPSHOTS=1",
        f"RESULT_BUNDLE_ARGS=-resultBundlePath {result}",
    ], cwd=root, check=True)
    exported = temporary / "attachments"
    subprocess.run([
        "xcrun", "xcresulttool", "export", "attachments", "--path", str(result),
        "--output-path", str(exported),
    ], check=True)
    snapshots = {}
    for test in json.loads((exported / "manifest.json").read_text()):
        for attachment in test["attachments"]:
            name = attachment["suggestedHumanReadableName"]
            match = re.fullmatch(r"(.+)_\d+_[A-Fa-f0-9-]+\.png", name)
            if not match:
                continue
            name = match[1]
            if name in snapshots or Path(name).name != name:
                raise ValueError(f"Invalid or duplicate snapshot name: {name}")
            snapshots[name] = exported / attachment["exportedFileName"]
    if not snapshots:
        raise RuntimeError("No snapshot attachments were recorded")
    baselines.mkdir(parents=True, exist_ok=True)
    for name, source in snapshots.items():
        shutil.copyfile(source, baselines / f"{name}.png")
        print(f"Recorded {name}.png")
print("Review the PNG changes, then run make ui-test before committing.")
