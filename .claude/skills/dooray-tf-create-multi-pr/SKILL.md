---
name: dooray-tf-create-multi-pr
description: ios-dooray, ios-dooray-service 서브모듈에 대한 풀리퀘스트를 생성합니다.
---

# Dooray프로젝트 구조 설명

두레이 iOS 프로젝트는 클린아키텍처를 사용합니다.
UI부분은 SwiftUI+TCA를 사용한 네이티브 코드로 작성됩니다. 해당 코드는 ios-dooray와 ios-dooray-service에 모두 존재하지만, 대부분 후자에 존재합니다.
Domain, Data등 프레젠테이션 레이어를 제외한 부분은 KMP로 구현되어 사용됩니다.
KMP레포지토리와 ios-dooray-service레포지토리는 ios-dooray레포지토리의 서브 모듈로 등록되어 있습니다.

작업은 대부분 ios-dooray-service브렌치에서 진행되며, 해당 레포지토리에 커밋을 생성합니다.
작업을 완료한 이후 메인 저장소의 develop브렌치가 서브모듈 저장소의 마지막 작업 PR을 바라보도록 설정해야합니다.

그렇기 때문에, ios-dooray-service원격 저장소의 기본 브렌치 업데이트를 위한 PR과 ios-dooray의 서브모듈 커밋업데이트를 위한 PR 총 2가지가 필요합니다.

# 워크 플로우

스킬 호출시 아래 워크플로우에 따라 작업을 수행합니다.

## 1. ios-dooray, ios-dooray-service브렌치 존재 여부 확인

ios-dooray-service는 다음과 같은 브렌치 이름 템플릿을 사용합니다.
```
feature/dooray-D-TF/{Task번호}
```
- prefix인 feature는 작업 성향에 따라 fix, refactor와 같은 이름이 사용될 수 있지만, 특별한 경우를 제외하면 대부분 feature입니다.
- Task번호는 "2110"같은 정수를 사용하지만, 작업량이 많을 경우 "2110-1", "2110-2"와 같은 형식으로 표현되기도 합니다.

ios-dooray는 ios-dooray-service와 동일한 브렌치 명을 사용해야합니다.
두 저장소의 HEAD가 동일한 브렌치명을 가지는 브렌치에 위치하는지 확인합니다.
그렇지 않다면, 작업을 종료하고 사용자에게 브렌치 동기화를 요청합니다.

## 2. Rebase필요성 확인 및 Rebase

두레이 프로젝트는 KMP와 ios변경사항을 동기화 해야하기 때문에
항상 최신 develop을 기준으로 변경사항을 적용해야합니다. 현재 병합되는 브렌치의 변경사항과 최신 KMP의 변경사항이 상이할 수 있기 때문입니다.

이를 해결하는 방법으로 최신 origin/develop을 기준으로 현 브렌치를 리베이스 합니다.
먼저 ios-dooray-service를 일반 rebase합니다.
커밋 되지 않은 변경사항들이 존재할 경우 모두 unstage 하고 stash 합니다.
rebase 충돌이 발생하는 경우 작업을 중단하고 사용자에게 직접 rebase 충돌을 해소할 것을 요구합니다.
충돌 없이 rebase를 완료했다면, stash 했던 내역을 재방영하고 stash 내역은 삭제합니다.

ios-dooray-service의 rebase가 정상적으로 진행되었다면 곧바로 해당 브렌치를 force-push합니다. ios-dooray-service푸쉬 발생시 현재 구현되어 있는 pre-push훅이 ios-dooray저장소의 서브모듈 커밋을 업데이트하고 자동으로 푸쉬합니다.

이후 ios-dooray를 origin/develop기준 interactive-rebase합니다.
해당 브렌치의 변경사항은 단순히 ios-dooray-service의 서브모듈 업데이트이기 때문에, 가장 최신 commit을 남긴 나머지 커밋은 전부 drop합니다.
충돌이 발생한 경우 우리 브랜치의 최신 서브모듈 커밋을 택해 충돌을 resolve합니다.
그후 rebase변경사항을 force-push합니다.

## 3. PR작성

ios-dooray-service에 대한 풀리퀘스트를 작성합니다.
해당 브렌치에 대한 PR이 이미존재하는 경우 PR본문만 업데이트합니다.
풀리퀘스트의 제목은 다음 템플릿을 따릅니다.
```
#dooray-D-TF/{업무번호} 업무제목 (완료)
```
업무 번호의 경우 브렌치 이름의 suffix로 획득합니다. (마지막 '/'이후)
업무 제목의 경우 dooray-mcp를 사용하여 실제 업무를 조회후 획득합니다.
dooray-mcp를 사용하기 위해선 업무 링크가 필요함으로 컨텍스트를 통해 업무 링크 혹은 번호(업무번호와 다름)를 획득할 수 없는 경우 사용자에게 입력을 요청합니다.
제목 획득후 "[iOS]"같은 플랫폼 특화 prefix가 있다면 제거후 사용합니다.

ios-dooray-service PR의 본문 템플릿은 다음과 같습니다.
현재 HEAD와 origin/develop간의 diff를 파악 및 컨텍스트를 통해 변경사항을 인지합니다.
변경사항들을 최대한 간결하게 PR 본문에 담는 것을 목표로 합니다.
작성후 사용자를 PR의 Assignee로 지정합니다.
```
### 업무링크

* [#dooray-D-TF/{업무번호}](실제 업무 링크)

# 수정내역

## 요약

## 변경내역 상세

### 1. 일정 상세화면 스켈레톤 (EventDetailSkeletonView)

- **AS-IS**: 별도 로딩 표현 없음.
- **TO-BE**: ...

### 2. 일정 상세 로딩 상태 정비 (CalendarEventDetailReducer)

- **AS-IS**: 별도 로딩 표현 없음.
- **TO-BE**: ...

### 3. 참석자 리스트 화면 스켈레톤 (EventParticipantListSkeletonView)

- **AS-IS**: 별도 로딩 표현 없음.
- **TO-BE**: 등록자 셀 · 섹션 헤더 · 참석자 셀 스켈레톤을 피그마 디자인대로 구성.

# 리뷰어 요청사항

- 트레이드 오프에 대한 의사 결정이 없는 경우 작성하지 않습니다.
- 업무에 벗어나는 변경사항들의 경우, "변경내역 상세"부분 보다 리뷰어 요청사항에 해당 부분을 언급해주세요.
```

ios-dooray의 PR을 작성합니다.
PR제목의 경우 ios-dooray-service와 동일합니다.
본문 템플릿은 다음과 같습니다. 단순 서브모듈 업데이트이기 때문에 별다른 내용입력이 없이 업무관련 정보만 표시합니다.
작성후 사용자를 PR의 Assignee로 지정합니다.
```
# 업무 링크

* [#dooray-D-TF/{업무번호}](실제 업무 링크)

# 수정내역

* [Sync] Submodule Update
```