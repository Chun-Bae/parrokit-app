#!/usr/bin/env python3
"""pubspec.yaml의 버전·빌드 번호가 Firebase App Distribution에 이미 있는지 확인한다.

빌드 번호는 pubspec.yaml 하나로 관리한다. 같은 버전·빌드 번호로 올리면 App
Distribution이 새 릴리스를 만들지 않고 기존 릴리스 파일을 조용히 덮어써서,
목록에도 안 뜨고 테스터 메일도 안 간다. 그래서 30분짜리 빌드를 돌리기 전에
여기서 먼저 멈춘다.

쓰는 법: check_build_number.py <서비스 계정 JSON 경로> <앱 ID>
pubspec.yaml은 현재 폴더에서 읽는다. 표준 라이브러리와 openssl만 쓴다.
"""
import base64
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request


def pubspec_version(path="pubspec.yaml"):
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = re.match(r"^version:\s*([0-9A-Za-z.\-]+)\+(\d+)\s*$", line)
            if m:
                return m.group(1), m.group(2)
    sys.exit("pubspec.yaml의 version에 '이름+빌드번호'가 없다 (예: 1.0.6+109)")


def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def access_token(sa):
    now = int(time.time())
    header = b64url(json.dumps({"alg": "RS256", "typ": "JWT"}).encode())
    claims = b64url(json.dumps({
        "iss": sa["client_email"],
        "scope": "https://www.googleapis.com/auth/cloud-platform",
        "aud": sa["token_uri"],
        "iat": now,
        "exp": now + 600,
    }).encode())
    unsigned = f"{header}.{claims}".encode()
    with tempfile.NamedTemporaryFile("w", delete=False) as key:
        key.write(sa["private_key"])
    try:
        signature = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", key.name],
            input=unsigned, capture_output=True, check=True,
        ).stdout
    finally:
        os.unlink(key.name)
    body = urllib.parse.urlencode({
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": f"{unsigned.decode()}.{b64url(signature)}",
    }).encode()
    with urllib.request.urlopen(sa["token_uri"], data=body, timeout=30) as res:
        return json.load(res)["access_token"]


def released_versions(app_id, token):
    """(displayVersion, buildVersion) 쌍을 모두 돌려준다."""
    project_number = app_id.split(":")[1]
    base = (f"https://firebaseappdistribution.googleapis.com/v1/projects/"
            f"{project_number}/apps/{app_id}/releases")
    found, page = set(), ""
    while True:
        query = {"pageSize": "100"}
        if page:
            query["pageToken"] = page
        req = urllib.request.Request(
            f"{base}?{urllib.parse.urlencode(query)}",
            headers={"Authorization": f"Bearer {token}"},
        )
        with urllib.request.urlopen(req, timeout=30) as res:
            data = json.load(res)
        for r in data.get("releases", []):
            found.add((r.get("displayVersion", ""), r.get("buildVersion", "")))
        page = data.get("nextPageToken", "")
        if not page:
            return found


def check(name, number, releases):
    """이미 있으면 안내 문구를, 없으면 None을 돌려준다."""
    if (name, number) not in releases:
        return None
    highest = max((int(b) for _, b in releases if b.isdigit()), default=int(number))
    return (f"{name} ({number})은 이미 App Distribution에 있다. 그대로 올리면 기존 "
            f"릴리스를 덮어써서 테스터에게 새 빌드로 안 보인다.\n"
            f"pubspec.yaml의 version을 올려서 커밋한 뒤 다시 실행한다 "
            f"(지금까지 가장 큰 빌드 번호: {highest}, 예: {name}+{highest + 1}).")


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    sa_path, app_id = sys.argv[1], sys.argv[2]
    name, number = pubspec_version()
    with open(sa_path, encoding="utf-8") as f:
        sa = json.load(f)
    releases = released_versions(app_id, access_token(sa))
    problem = check(name, number, releases)
    if problem:
        print(f"::error::{problem}")
        sys.exit(1)
    print(f"빌드 번호 확인: {name} ({number})은 아직 배포되지 않았다.")


if __name__ == "__main__":
    main()
