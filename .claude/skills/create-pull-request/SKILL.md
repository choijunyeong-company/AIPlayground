---
name: create-pull-request
description: 작업 사항에 대해 Pull request 생성 요청시 해당 스킬을 사용하여 생성합니다.
---

1. 베이스 브렌치를 식별합니다. 컨텍스트를 통해서 알아낼 수 없는 경우 사용자에게 직접 묻습니다.
2. Pull request 타이틀을 생성합니다. [참조](#pull-request-타이틀-생성)
3. 템플릿 파일을 기반으로 Pull request 본문을 생성합니다. [참조](#pull-request-본문-생성)
4. Pull request의 설정사항을 반영해줘 [참조](#pull-request-설정-사항)
5. `gh` 툴과 생성한 정보들을 사용하여 Pull request를 생성합니다. [참조](#pull-request-생성)

# Pull request 타이틀 생성 

Pull request 타이틀은 변경 내역에 대해 알 수 있는 Prefix를 가집니다.
- Feat: 새로운 기능의 추가
- Refactor: 기존 기능을 유지한 채로 코드 베이스 유지 보수
- Fix: 버그 및 오류 기능을 수정
- Docs: 코드 베이스와 무관한 문서 수정

현재 컨텍스트의 작업 명세와 브렌치 변경점을 추적하여 제목 본문을 생성하고 앞서 Prefix를 붙여 완성합니다.

## Example

1. [Feat] 로그인 화면 UI 구현
2. [Refactor] 로그인 실행 로직 리팩토링
3. [Fix] 페이코 로그인 실패 문제 해결
4. [Docs] 클로드 코드 PR 생성 스킬 명세 수정

# Pull request 본문 생성

1. 작업과 관련된 계획 및 변경사항을 컨텍스트를 통해 인지합니다. 브랜치 변경사항을 추적하여 어떤 작업이 진행되었는지 파악합니다.
2. 이를 바탕으로 본문을 작성하며 [작성 가이드](./references/body.md)를 반드시 준수합니다.

# Pull request 설정 사항

1. Assignee를 나로 지정해줘
2. 추가예정

# Pull request 생성

`context7` mcp서버를 통해 gh 사용법을 학습합니다.
해당 mcp서버를 사용할 수 없다면, `gh pr create --help`명령어를 통해 직접 학습합니다.