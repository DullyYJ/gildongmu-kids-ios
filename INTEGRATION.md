# 길동무 ↔ 길동무 키즈 연동 (iOS)

서버 규약은 안드로이드 키즈 저장소 `ENGINE.md` / `INTEGRATION.md` 가 원본이다. 이 문서는 iOS 두 앱이 맞물리는 지점만 적는다.

## 연결
- 키즈 설정 → "연결 비밀키 만들기": `POST /c/pair` → `XXXXX-XXXXX`(10분). QR 글 `gildongmu-kids://pair?c=<child_id>&k=<code>`.
- 부모(길동무 iOS): QR 스캔 또는 비밀키 입력 → `POST /p/join {code}` → `{cid}`. 부모 앱의 해당 화면은 부모 저장소(subway-app-ios)에서 만든다(아직 없음).
- 부모 앱도 키즈 앱의 URL 스킴 `gildongmu-kids://` 를 열 수 있어야 한다(카메라 QR → 길동무 열기).

## 위치
- 키즈 `KidsLocation` → `POST /c/loc`(정확한 좌표 · 배터리). 보는 중 `w`, 느리게 `sl` 은 서버가 정한다. 동의 전 · 공유 끔 · 연결 끊김이면 보내지 않는다.
- 부모 홈의 위치 알약은 서버 계산 결과만 그린다.

## 가족대화 · 퀘스트
- 키즈: `/c/screen` · `/c/wait` 의 blocks 를 그대로 그린다. 보내기 `chat.send` · `quest.send` · 승낙/거절/완료/확인은 `/c/act`.
- 부모: `/p/chat` · `/p/quest*`(부모 앱 서버 주도 화면).

## iOS 에서 달라지는 것
- 푸시: FCM → **APNs**. 키즈 서버가 보내는 푸시(부모 알림, `k=watch` 등)를 iOS 토큰으로 받으려면 `/c/ft` 와 같은 등록 경로에 APNs 토큰 종류 구분이 필요하다(서버 변경 → 엔진 파일이 바뀌면 사용자에게 전달).
- 백그라운드 위치: "항상 허용" 심사 사유서 필요. 위치 사용 표시(파란 막대)가 자동으로 뜬다.
- 오버레이 없음: 안드로이드의 상단 알림 줄 대신 Live Activity / 로컬 알림.

## 공유 코드 (같이 고쳐야 하는 곳)
- 장면 엔진(Scene) · 화면 그리개(Core · UI)는 부모 저장소 것을 CI가 받아 쓴다. 부모 저장소의 `Sources/Core|UI|Scene`, `Resources/chars3d|open.json`, `scripts/make_fonts.py` 이름 · 위치를 바꾸면 이 저장소 `tools/vendor.sh` 도 같이 고친다.
