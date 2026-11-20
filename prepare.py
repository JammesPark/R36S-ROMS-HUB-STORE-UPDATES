import hashlib
import json
import re
import shutil
from pathlib import Path
from zipfile import ZipFile

version = Path("distribution/version.txt").read_text().strip()
if not re.fullmatch(r"\d+\.\d+\.\d+(?:-beta)?", version):
    raise ValueError("Versão inválida")
prefix = f"R36S_ROMS_STORE_{version}"
out = Path("out")
out.mkdir(exist_ok=True)
installer = out / f"{prefix}.zip"
ota = out / f"{prefix}_OTA.zip"
shutil.copyfile("distribution/installer.zip", installer)
with ZipFile(installer) as src, ZipFile(ota, "w") as dst:
    manifest = json.loads(src.read("update_manifest.json"))
    assert manifest["version"] == version and manifest["type"] == "full"
    dst.writestr(src.getinfo("update_manifest.json"), src.read("update_manifest.json"))
    for entry in manifest["files"]:
        path = entry["path"]
        assert path == "R36S ROMS STORE.sh" or path.startswith("r36sromsstore/")
        assert ".." not in path.split("/") and path != "r36sromsstore/catalog.json"
        data = src.read(path)
        assert len(data) == entry["size"] and hashlib.sha256(data).hexdigest() == entry["sha256"]
        dst.writestr(src.getinfo(path), data)
    assert "r36sromsstore/game.love" in dst.namelist()
with ZipFile(ota) as check:
    assert check.testzip() is None
base = f"https://github.com/JammesPark/R36S-ROMS-HUB-STORE-UPDATES/releases/download/store-v{version}"
feed = dict(version=version, url=f"{base}/{ota.name}", size=ota.stat().st_size,
            sha256=hashlib.sha256(ota.read_bytes()).hexdigest(),
            notes="\n".join(manifest.get("changes") or [manifest["description"]]))
(out / "update.json").write_text(json.dumps(feed, ensure_ascii=False, indent=2) + "\n")
