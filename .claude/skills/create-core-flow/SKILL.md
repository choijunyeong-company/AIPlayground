---
name: create-core-flow
description: CoreFlow를 생성하는 경우 해당 스킬 활용하여 생성합니다.
---

# Work flow

1. 적절한 Feature이름과 Feature디렉토리 생성위치를 컨텍스트를 통해 추론합니다. 알 수 없는 경우 사용자에게 물어봅니다.
2. 요구사항에 따라 화면(Screen 객체)이 필요한 CoreFlow인지 아닌지 판단합니다.
- 화면이 필요하다면 [Default](./Template/Default) 디렉토리 내부에 존재하는 템플릿을 사용합니다.
- 화면이 필요하지 않고 로직만 존재한다면, [ScreenLess](./Template/ScreenLess) 디렉토리 내부에 존재하는 템플릿을 사용합니다.
3. 특정된 위치에 Feature명으로 디레토리를 생성합니다.
4. 해당 디렉토리 내부에 Feature명을 Prefix로 가지는 CoreFlow 구성요소들을 생성합니다.