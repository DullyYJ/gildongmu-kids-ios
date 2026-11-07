# 길동무 키즈 iOS — 설계 메모

- 키즈 앱은 부모 앱과 같은 테마(색 · 글꼴)와 같은 3D 캐릭터 장면 엔진을 쓴다. 장면 엔진은 안드로이드 SceneCore(Java)를 1:1로 옮긴 Swift 판(부모 저장소 Sources/Scene, 상세는 그쪽 HANDOFF.md).
- 서버 주도: 키즈 서버가 blocks 로 화면을 만들어 주면 KidsBlocks 가 그린다. 열 가지 블록(head · text · box · card · msg · input · stars · chips · btns · i)만 안다. 새 블록이 생기면 여기와 KidsBlocks 에 추가.
- 개인정보 · 위치: 법적 검토와 보관 규칙은 안드로이드 키즈 저장소 `docs/legal/` 이 원본이다(동의 v2 · 위치 3일 · 지난 길 7일 · 머문 곳 30일). iOS 동의 창은 같은 글을 쓰고, 동의 전에는 위치 · 서버 보고를 하지 않는다.
- 만 9살 이상 + 보호자 동의 두 칸(부모 · 아이)을 모두 켜야 시작할 수 있다.
