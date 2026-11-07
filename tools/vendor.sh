#!/bin/bash
# 부모 앱(subway-app-ios) 체크아웃(기본 ./parent)에서 키즈 앱이 같이 쓰는 것만 Vendor/ 로 복사한다.
#  - Sources/Core · UI · Scene : 화면 그리개 · 글꼴 · 장면 엔진(그림 · 움직임 · 진동)
#  - Resources/chars3d · open.json : 캐릭터 시트 · 인사 대본
#  - 글꼴(Noto Sans KR)은 부모의 scripts/make_fonts.py 로 만든다
set -euo pipefail
P="${1:-parent}"
rm -rf Vendor && mkdir -p Vendor/Sources Vendor/Fonts
cp -R "$P/Sources/Core" "$P/Sources/UI" "$P/Sources/Scene" Vendor/Sources/
rm -f Vendor/Sources/UI/RootView.swift            # 부모 앱의 탭 묶음(Tabs/Ride 에 기대는 곳) — 키즈는 자기 KidsRoot 를 쓴다
cp -R "$P/Resources/chars3d" Vendor/chars3d
cp "$P/Resources/open.json" Vendor/open.json
if [ -d "$P/Resources/Fonts" ]; then cp "$P"/Resources/Fonts/*.ttf Vendor/Fonts/ 2>/dev/null || true; fi
find Vendor -type f | wc -l
