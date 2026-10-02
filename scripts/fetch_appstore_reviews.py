#!/usr/bin/env python3
"""App Store 리뷰를 공개 RSS 로 모아 마크다운으로 출력한다 (인증 불필요).

App Store Connect 웹은 한 화면에 일부만 보여 주고 내보내기가 없다. 공개 RSS 는
최신순 50건/페이지, 최대 10페이지(500건)까지 준다.

사용:
    scripts/fetch_appstore_reviews.py                     # 전체, 표준 출력
    scripts/fetch_appstore_reviews.py --since 2026-09-01  # 이 날짜 이후만
    scripts/fetch_appstore_reviews.py --version 2.2.2     # 특정 버전만
    scripts/fetch_appstore_reviews.py --out docs/appstore/reviews.md

표준 라이브러리 + curl(macOS 기본) 만 쓴다.
"""
import argparse
import json
import subprocess
import sys

APP_ID = "6761267379"  # 모아+ 키보드
COUNTRY = "kr"
MAX_PAGES = 10  # RSS 상한
URL = "https://itunes.apple.com/{country}/rss/customerreviews/page={page}/id={app}/sortby=mostrecent/json"


def fetch_page(page):
    url = URL.format(country=COUNTRY, page=page, app=APP_ID)
    # urllib 대신 curl — python.org 설치본은 루트 인증서가 없어 SSL 검증에 실패한다.
    try:
        out = subprocess.run(["curl", "-sfL", "--max-time", "20", url],
                             capture_output=True, check=True).stdout
        data = json.loads(out)
    except (subprocess.CalledProcessError, json.JSONDecodeError) as e:
        print(f"page {page} 실패: {e}", file=sys.stderr)
        return []
    entries = data.get("feed", {}).get("entry", [])
    # 결과가 1건이면 리스트가 아니라 객체 하나로 온다.
    return [entries] if isinstance(entries, dict) else entries


def label(entry, key):
    return entry.get(key, {}).get("label", "")


def parse(entry):
    return {
        "id": label(entry, "id"),
        "date": label(entry, "updated")[:10],
        "rating": int(label(entry, "im:rating") or 0),
        "version": label(entry, "im:version"),
        "author": entry.get("author", {}).get("name", {}).get("label", ""),
        "title": label(entry, "title"),
        "content": label(entry, "content").strip(),
    }


def fetch_all():
    reviews, seen = [], set()
    for page in range(1, MAX_PAGES + 1):
        entries = fetch_page(page)
        if not entries:
            break
        for e in entries:
            r = parse(e)
            if r["id"] and r["id"] not in seen:
                seen.add(r["id"])
                reviews.append(r)
    return reviews


def to_markdown(reviews):
    if not reviews:
        return "리뷰 없음\n"
    avg = sum(r["rating"] for r in reviews) / len(reviews)
    lines = [f"# 모아+ App Store 리뷰 ({len(reviews)}건, 평균 {avg:.2f}★)", ""]
    for r in reviews:
        stars = "★" * r["rating"] + "☆" * (5 - r["rating"])
        lines.append(f"## {stars} {r['title']}")
        lines.append(f"{r['date']} · v{r['version']} · {r['author']}")
        lines.append("")
        lines.append(r["content"])
        lines.append("")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--since", help="YYYY-MM-DD 이후(포함) 리뷰만")
    ap.add_argument("--version", help="이 앱 버전에 남긴 리뷰만")
    ap.add_argument("--out", help="출력 파일 (기본: 표준 출력)")
    args = ap.parse_args()

    reviews = fetch_all()
    if args.since:
        reviews = [r for r in reviews if r["date"] >= args.since]
    if args.version:
        reviews = [r for r in reviews if r["version"] == args.version]

    text = to_markdown(reviews)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text)
        print(f"{len(reviews)}건 → {args.out}", file=sys.stderr)
    else:
        sys.stdout.write(text)


if __name__ == "__main__":
    main()
