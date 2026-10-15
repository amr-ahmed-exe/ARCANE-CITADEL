#!/usr/bin/env python3
import json, os, sys, time, urllib.request, urllib.error

API_KEY = os.environ.get("ROBLOX_OPEN_CLOUD_KEY", "")
GROUP_ID = os.environ.get("ROBLOX_GROUP_ID", "")
MANIFEST_PATH = "assets/asset_manifest.json"

def upload_fbx(asset_name: str, fbx_path: str):
    if not API_KEY or not GROUP_ID:
        sys.exit("ERROR: Missing ROBLOX_OPEN_CLOUD_KEY or ROBLOX_GROUP_ID env vars.")
    boundary = "----ArcaneCitadelBoundary7MA4YWxkTrZu0gW"
    req_json = json.dumps({
        "assetType": "Model",
        "displayName": asset_name,
        "description": "Arcane Citadel 3D Asset",
        "creationContext": {"creator": {"groupId": int(GROUP_ID)}}
    })
    with open(fbx_path, "rb") as f:
        fbx_bytes = f.read()

    body = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="request"\r\nContent-Type: application/json\r\n\r\n{req_json}\r\n'
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="fileContent"; filename="{os.path.basename(fbx_path)}"\r\nContent-Type: model/fbx\r\n\r\n'
    ).encode("utf-8") + fbx_bytes + f"\r\n--{boundary}--\r\n".encode("utf-8")

    req = urllib.request.Request(
        "https://apis.roblox.com/assets/v1/assets",
        data=body,
        headers={"x-api-key": API_KEY, "Content-Type": f"multipart/form-data; boundary={boundary}"},
        method="POST"
    )
    with urllib.request.urlopen(req) as resp:
        op_path = json.loads(resp.read().decode("utf-8")).get("path")

    for _ in range(30):
        time.sleep(2)
        poll = urllib.request.Request(f"https://apis.roblox.com/assets/v1/{op_path}", headers={"x-api-key": API_KEY})
        with urllib.request.urlopen(poll) as pr:
            data = json.loads(pr.read().decode("utf-8"))
            if data.get("done"):
                uri = f"rbxassetid://{data['response']['assetId']}"
                manifest = json.load(open(MANIFEST_PATH)) if os.path.exists(MANIFEST_PATH) else {}
                manifest[asset_name] = uri
                os.makedirs(os.path.dirname(MANIFEST_PATH), exist_ok=True)
                json.dump(manifest, open(MANIFEST_PATH, "w"), indent=2)
                print(f"SUCCESS: {asset_name} -> {uri}")
                return
    sys.exit("ERROR: Timed out waiting for Roblox Open Cloud processing.")

if __name__ == "__main__":
    upload_fbx(sys.argv[1], sys.argv[2])
