# 길동무 키즈 iOS — HANDOFF

최종 갱신: 2026-11-07 (Claude Sonnet 5.5, 인계 세션에서 시작)

## 0. 상시 규칙
- 100% 최신 네이티브(SwiftUI · Core Haptics · CoreLocation · Keychain). WebView · 레거시 금지. 메인 스레드 부하 0, 무거운 일은 백그라운드.
- **앱은 그리기만 한다.** 화면(blocks) · 글 · 알림 문구 · 판단은 서버(키즈 워커 `gildongmu-kids`, 길동무 엔진 `route-v2`)가 하고 앱은 받은 대로 그린다.
- 부모 앱(길동무)과 같은 색(Palette) · 글꼴(Noto Sans KR) · 장면 엔진을 쓴다. 키즈 ↔ 부모 연동 내용은 INTEGRATION.md 에 모아 늘 최신으로 둔다.
- 질문 없이 자율 진행. 보고는 한국어로 짧게. 부모 앱 장면 엔진(`engine/route-v2-worker.ascii.js`)이 바뀌면 최신 파일을 사용자에게 전달.

## 1. 구조 (이 저장소는 가볍다)
키즈 앱은 부모 앱 저장소(공개)의 공유 코드를 **CI가 읽기 전용으로 받아** 같이 빌드한다(안드로이드 키즈가 길동무 저장소를 받아 쓰는 것과 같은 방식).

```
tools/vendor.sh   부모 체크아웃(./parent)에서 Sources/Core · UI · Scene, Resources/chars3d · open.json, 글꼴을 Vendor/ 로 복사
project.yml       XcodeGen(Sources + Vendor/Sources + 시트 + 대본)
Sources/App       KidsApp (@main)
Sources/Kids      서버 연결 · 화면 그리개 · 탭 화면 · 위치
.github/workflows typecheck.yml(문법 검사 ~1분) · ios.yml(전체 빌드 ~10–15분 · 화면 캡처 → ios-ci-out)
```

| 파일 | 역할 |
|---|---|
| KidsServer | 키즈 워커 규약: 기기 등록 `/reg`(role c, 아이디·비밀은 Keychain), `/c/screen` · `/c/wait`(긴 대기) · `/c/act` · `/c/pair` · `/c/loc` · `/c/share` · `/c/consent` · `/c/unlink`, 그리고 길동무 `/scene`(장면·날씨, 위치는 5km 칸으로 뭉갬) |
| KidsStore | 가족대화 · 퀘스트 화면과 상태(연결 수 · 별 · 응원 문구)를 들고 긴 대기로 실시간 유지 |
| KidsBlocks | 서버 blocks 그림판: head · text · box · card · msg · input · stars · chips · btns · i |
| KidsRoot | 아래 탭(가족대화 · 노선도 · 홈 · 퀘스트 · 설정), 동의 창, 홈(응원 문구 · 별 · 장면 · 3초 꾹 누르기 인사), 설정(연결 비밀키 · QR · 위치 공유 · 테마 · 약관 · 연결 끊기 · 동의 철회) |
| KidsLocation | 동의 + 공유 켬일 때만 위치 보고. 주기: 평소 5분 · 서버 sl=8분 · 보는 중 w(1=2.5초, 2=10초, 3=15초). 항상 허용 + 백그라운드 위치 |

## 2. 현재 상태 (2026-11-07)
- 작성 완료(첫 빌드 확인 전): 위 전부. 노선도 탭은 자리만 있다.
- 동의 문구는 안드로이드 `Engine.consentScreen`(버전 2)과 같은 글이다. 동의 후 `/c/consent {v:2}` 를 서버에 알린다.
- 연결 QR 글: `gildongmu-kids://pair?c=<아이디>&k=<비밀키>` (10분 유효).

## 3. 작업 방법 (맥 없이)
- 빌드는 GitHub Actions(macos-latest). git push 가 막힌 세션에서는 GitHub 웹 업로드(`/upload/main/<폴더>`)로 올린다. 폴더마다 한 번씩.
- 빠른 검사: Kids typecheck(~1분). 전체: iOS build → 결과 스크린샷은 `ios-ci-out` 브랜치(커밋 라벨 "ios CI 결과 <해시>"가 방금 푸시한 해시인지 확인).
- 컴파일 오류는 실패한 잡 페이지에서 단계를 펼쳐 읽는다.
- 커밋 꼬리말: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`, `Claude-Session: https://claude.ai/code/session_01LeKFQLrsPkuhpvtgc2kMmp`.
- CI 캡처는 실행할 때마다 새 기기로 키즈 서버에 등록한다(시험용 기기 행이 쌓인다 — 서버 쪽 정리 필요하면 안드로이드 저장소 ENGINE.md 참고).

## 4. 남은 일 (우선순위)
1. 첫 빌드 · 캡처 확인, 컴파일 오류 수정.
2. 키즈 홈의 다마고치 동작: 안드로이드는 `Engine.java` 가 기기 안에서 배고픔 · 응가 · 공부 · 잠을 계산해 장면(kbeg/kpoop …)에 싣는다. iOS 는 판단을 서버로 옮길지(권장: "앱은 그리기만") Engine 을 이식할지 결정 필요 → 일단 서버 /scene 장면만 그린다.
3. 알림: APNs(안드로이드는 FCM). 부모 푸시 · 장소 알림 · 확인/출발 시트(`trip`/`prompt` 상태).
4. 노선도 탭(부모 앱 MapTab 재사용), 꾸미기 팝업, 꾸미기 아이템.
5. 위치: 도착 확인(100m) · 응원 문구 흐름 · 홈 5초 안내.
6. 실기기 시험(백그라운드 위치 · Core Haptics · 심사 사유서: 항상 위치 사용 설명).
