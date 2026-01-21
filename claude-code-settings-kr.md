# Claude Code 설정 가이드

> 전역 및 프로젝트 수준의 설정과 환경 변수를 통해 Claude Code를 자유롭게 구성해보세요.

Claude Code는 여러분의 필요에 맞게 동작을 조정할 수 있는 다양한 설정을 제공합니다. 대화형 REPL을 사용할 때 `/config` 명령을 실행하면 탭 형태의 설정 인터페이스가 열리며, 여기서 상태 정보를 확인하고 설정 옵션을 변경할 수 있습니다.

## 설정 범위(Scope) 이해하기

Claude Code는 **범위(Scope) 시스템**을 사용하여 설정이 어디에 적용되고 누구와 공유되는지를 결정합니다. 각 범위를 이해하면 개인 사용, 팀 협업, 또는 기업 배포에 맞는 최적의 설정 방법을 선택할 수 있습니다.

### 사용 가능한 범위

| 범위 | 위치 | 적용 대상 | 팀과 공유 여부 |
| :--- | :--- | :--- | :--- |
| **Managed (관리됨)** | 시스템 수준 `managed-settings.json` | 해당 머신의 모든 사용자 | 예 (IT 부서에서 배포) |
| **User (사용자)** | `~/.claude/` 디렉토리 | 본인의 모든 프로젝트 | 아니오 |
| **Project (프로젝트)** | 저장소 내 `.claude/` | 해당 저장소의 모든 협업자 | 예 (git에 커밋됨) |
| **Local (로컬)** | `.claude/*.local.*` 파일들 | 본인만, 해당 저장소에서만 | 아니오 (gitignore 처리됨) |

### 각 범위의 적절한 사용 시점

**Managed 범위**는 다음과 같은 경우에 적합합니다:
* 조직 전체에 반드시 적용해야 하는 보안 정책
* 예외 없이 준수해야 하는 컴플라이언스 요구사항
* IT/DevOps 팀에서 배포하는 표준화된 설정

**User 범위**는 다음과 같은 경우에 적합합니다:
* 모든 프로젝트에서 일관되게 사용하고 싶은 개인 환경설정 (테마, 에디터 설정 등)
* 여러 프로젝트에서 공통으로 사용하는 도구와 플러그인
* API 키 및 인증 정보 (안전하게 저장됨)

**Project 범위**는 다음과 같은 경우에 적합합니다:
* 팀 전체가 공유해야 하는 설정 (권한, 훅, MCP 서버 등)
* 팀 전체가 사용해야 하는 플러그인
* 협업자 간 도구 사용의 표준화

**Local 범위**는 다음과 같은 경우에 적합합니다:
* 특정 프로젝트에서만 적용할 개인 설정 덮어쓰기
* 팀과 공유하기 전에 테스트해볼 설정
* 다른 팀원의 환경에서는 동작하지 않을 수 있는 머신별 특수 설정

### 범위 간 상호작용

동일한 설정이 여러 범위에서 구성된 경우, 더 구체적인 범위가 우선적으로 적용됩니다:

1. **Managed** (최상위) - 다른 어떤 설정으로도 덮어쓸 수 없음
2. **명령줄 인자** - 해당 세션에서만 임시로 적용되는 덮어쓰기
3. **Local** - 프로젝트 및 사용자 설정을 덮어씀
4. **Project** - 사용자 설정을 덮어씀
5. **User** (최하위) - 다른 곳에서 지정하지 않은 경우에만 적용

예를 들어, 사용자 설정에서 특정 권한을 허용했더라도 프로젝트 설정에서 해당 권한을 거부하면, 프로젝트 설정이 우선 적용되어 해당 권한이 차단됩니다.

### 범위가 적용되는 기능들

범위는 Claude Code의 다양한 기능에 적용됩니다:

| 기능 | User 위치 | Project 위치 | Local 위치 |
| :--- | :--- | :--- | :--- |
| **Settings** | `~/.claude/settings.json` | `.claude/settings.json` | `.claude/settings.local.json` |
| **Subagents** | `~/.claude/agents/` | `.claude/agents/` | — |
| **MCP servers** | `~/.claude.json` | `.mcp.json` | `~/.claude.json` (프로젝트별) |
| **Plugins** | `~/.claude/settings.json` | `.claude/settings.json` | `.claude/settings.local.json` |
| **CLAUDE.md** | `~/.claude/CLAUDE.md` | `CLAUDE.md` 또는 `.claude/CLAUDE.md` | `CLAUDE.local.md` |

---

## 설정 파일

`settings.json` 파일은 계층적 설정을 통해 Claude Code를 구성하는 공식적인 방법입니다:

* **User 설정**은 `~/.claude/settings.json`에 정의되며 모든 프로젝트에 적용됩니다.
* **Project 설정**은 프로젝트 디렉토리에 저장됩니다:
  * `.claude/settings.json` - 소스 컨트롤에 커밋되어 팀과 공유되는 설정
  * `.claude/settings.local.json` - 커밋되지 않는 설정으로, 개인 환경설정이나 실험용으로 유용합니다. Claude Code는 이 파일이 생성될 때 자동으로 git이 무시하도록 설정합니다.
* **Managed 설정**: 중앙 집중식 제어가 필요한 조직을 위해, Claude Code는 시스템 디렉토리에 배포할 수 있는 `managed-settings.json` 및 `managed-mcp.json` 파일을 지원합니다:

  * macOS: `/Library/Application Support/ClaudeCode/`
  * Linux 및 WSL: `/etc/claude-code/`
  * Windows: `C:\Program Files\ClaudeCode\`

  > **참고**: 이 경로들은 시스템 전체 경로입니다 (`~/Library/...`와 같은 사용자 홈 디렉토리가 아님). 관리자 권한이 필요하며 IT 관리자가 배포하도록 설계되었습니다.

  자세한 내용은 [Managed 설정](/en/iam#managed-settings) 및 [Managed MCP 구성](/en/mcp#managed-mcp-configuration)을 참조하세요.

  > **참고**: Managed 배포에서는 `strictKnownMarketplaces`를 사용하여 **플러그인 마켓플레이스 추가를 제한**할 수도 있습니다. 자세한 내용은 [Managed 마켓플레이스 제한](/en/plugin-marketplaces#managed-marketplace-restrictions)을 참조하세요.

* **기타 구성**은 `~/.claude.json`에 저장됩니다. 이 파일에는 환경설정(테마, 알림 설정, 에디터 모드), OAuth 세션, User 및 Local 범위의 [MCP 서버](/en/mcp) 구성, 프로젝트별 상태(허용된 도구, 신뢰 설정), 그리고 다양한 캐시가 포함됩니다. Project 범위의 MCP 서버는 별도로 `.mcp.json`에 저장됩니다.

```json
// settings.json 예시
{
  "permissions": {
    "allow": [
      "Bash(npm run lint)",
      "Bash(npm run test:*)",
      "Read(~/.zshrc)"
    ],
    "deny": [
      "Bash(curl:*)",
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./secrets/**)"
    ]
  },
  "env": {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
    "OTEL_METRICS_EXPORTER": "otlp"
  },
  "companyAnnouncements": [
    "Acme Corp에 오신 것을 환영합니다! docs.acme.com에서 코드 가이드라인을 확인하세요",
    "알림: 모든 PR에는 코드 리뷰가 필요합니다",
    "새로운 보안 정책이 시행 중입니다"
  ]
}
```

### 사용 가능한 설정 항목

`settings.json`은 다양한 옵션을 지원합니다:

| 키 | 설명 | 예시 |
| :--- | :--- | :--- |
| `apiKeyHelper` | 인증 값을 생성하기 위해 `/bin/sh`에서 실행되는 커스텀 스크립트. 이 값은 모델 요청 시 `X-Api-Key` 및 `Authorization: Bearer` 헤더로 전송됩니다 | `/bin/generate_temp_api_key.sh` |
| `cleanupPeriodDays` | 지정된 기간보다 오래 비활성 상태인 세션은 시작 시 삭제됩니다. `0`으로 설정하면 모든 세션이 즉시 삭제됩니다 (기본값: 30일) | `20` |
| `companyAnnouncements` | 시작 시 사용자에게 표시할 공지사항. 여러 공지사항이 제공되면 무작위로 순환하여 표시됩니다 | `["Acme Corp에 오신 것을 환영합니다! docs.acme.com에서 코드 가이드라인을 확인하세요"]` |
| `env` | 모든 세션에 적용될 환경 변수 | `{"FOO": "bar"}` |
| `attribution` | git 커밋 및 풀 리퀘스트에 대한 저작자 표시를 커스터마이즈합니다. [저작자 표시 설정](#저작자-표시-설정) 참조 | `{"commit": "🤖 Claude Code로 생성됨", "pr": ""}` |
| `includeCoAuthoredBy` | **사용 중단됨**: 대신 `attribution`을 사용하세요. git 커밋 및 풀 리퀘스트에 `co-authored-by Claude` 문구 포함 여부 (기본값: `true`) | `false` |
| `permissions` | 권한 구조는 아래 표를 참조하세요 | |
| `hooks` | 도구 실행 전후에 실행할 커스텀 명령을 구성합니다. [훅 문서](/en/hooks) 참조 | `{"PreToolUse": {"Bash": "echo '명령 실행 중...'"}}` |
| `disableAllHooks` | 모든 [훅](/en/hooks)을 비활성화합니다 | `true` |
| `allowManagedHooksOnly` | (Managed 설정 전용) User, Project, 플러그인 훅의 로딩을 방지합니다. Managed 훅과 SDK 훅만 허용됩니다. [훅 구성](#훅-구성) 참조 | `true` |
| `model` | Claude Code에서 사용할 기본 모델을 덮어씁니다 | `"claude-sonnet-4-5-20250929"` |
| `otelHeadersHelper` | 동적 OpenTelemetry 헤더를 생성하는 스크립트. 시작 시 및 주기적으로 실행됩니다 ([동적 헤더](/en/monitoring-usage#dynamic-headers) 참조) | `/bin/generate_otel_headers.sh` |
| `statusLine` | 컨텍스트를 표시할 커스텀 상태 라인을 구성합니다. [`statusLine` 문서](/en/statusline) 참조 | `{"type": "command", "command": "~/.claude/statusline.sh"}` |
| `fileSuggestion` | `@` 파일 자동완성을 위한 커스텀 스크립트를 구성합니다. [파일 제안 설정](#파일-제안-설정) 참조 | `{"type": "command", "command": "~/.claude/file-suggestion.sh"}` |
| `respectGitignore` | `@` 파일 선택기가 `.gitignore` 패턴을 준수할지 여부를 제어합니다. `true`(기본값)면 `.gitignore` 패턴과 일치하는 파일이 제안에서 제외됩니다 | `false` |
| `outputStyle` | 시스템 프롬프트를 조정하는 출력 스타일을 구성합니다. [출력 스타일 문서](/en/output-styles) 참조 | `"Explanatory"` |
| `forceLoginMethod` | `claudeai`로 설정하면 Claude.ai 계정으로만 로그인을 제한하고, `console`로 설정하면 Claude Console(API 사용 과금) 계정으로만 제한합니다 | `claudeai` |
| `forceLoginOrgUUID` | 로그인 시 조직 선택 단계를 건너뛰고 자동으로 선택할 조직의 UUID를 지정합니다. `forceLoginMethod`가 설정되어 있어야 합니다 | `"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"` |
| `enableAllProjectMcpServers` | 프로젝트 `.mcp.json` 파일에 정의된 모든 MCP 서버를 자동으로 승인합니다 | `true` |
| `enabledMcpjsonServers` | `.mcp.json` 파일에서 승인할 특정 MCP 서버 목록 | `["memory", "github"]` |
| `disabledMcpjsonServers` | `.mcp.json` 파일에서 거부할 특정 MCP 서버 목록 | `["filesystem"]` |
| `allowedMcpServers` | managed-settings.json에서 설정 시, 사용자가 구성할 수 있는 MCP 서버의 허용 목록. 정의되지 않으면 제한 없음, 빈 배열이면 완전 차단. 모든 범위에 적용됩니다. 거부 목록이 우선합니다. [Managed MCP 구성](/en/mcp#managed-mcp-configuration) 참조 | `[{ "serverName": "github" }]` |
| `deniedMcpServers` | managed-settings.json에서 설정 시, 명시적으로 차단되는 MCP 서버의 거부 목록. Managed 서버를 포함한 모든 범위에 적용됩니다. 거부 목록이 허용 목록보다 우선합니다. [Managed MCP 구성](/en/mcp#managed-mcp-configuration) 참조 | `[{ "serverName": "filesystem" }]` |
| `strictKnownMarketplaces` | managed-settings.json에서 설정 시, 사용자가 추가할 수 있는 플러그인 마켓플레이스의 허용 목록. 정의되지 않으면 제한 없음, 빈 배열이면 완전 차단. 마켓플레이스 추가에만 적용됩니다. [Managed 마켓플레이스 제한](/en/plugin-marketplaces#managed-marketplace-restrictions) 참조 | `[{ "source": "github", "repo": "acme-corp/plugins" }]` |
| `awsAuthRefresh` | `.aws` 디렉토리를 수정하는 커스텀 스크립트 ([고급 자격 증명 구성](/en/amazon-bedrock#advanced-credential-configuration) 참조) | `aws sso login --profile myprofile` |
| `awsCredentialExport` | AWS 자격 증명이 포함된 JSON을 출력하는 커스텀 스크립트 ([고급 자격 증명 구성](/en/amazon-bedrock#advanced-credential-configuration) 참조) | `/bin/generate_aws_grant.sh` |
| `alwaysThinkingEnabled` | 모든 세션에서 기본적으로 [확장 사고](/en/common-workflows#use-extended-thinking-thinking-mode)를 활성화합니다. 일반적으로 직접 편집하기보다 `/config` 명령을 통해 구성합니다 | `true` |
| `plansDirectory` | 계획 파일이 저장되는 위치를 커스터마이즈합니다. 경로는 프로젝트 루트 기준 상대 경로입니다. 기본값: `~/.claude/plans` | `"./plans"` |
| `showTurnDuration` | 응답 후 턴 지속 시간 메시지를 표시합니다 (예: "1분 6초 동안 작업함"). `false`로 설정하면 이 메시지를 숨깁니다 | `true` |
| `language` | Claude가 응답할 때 선호하는 언어를 구성합니다 (예: `"japanese"`, `"spanish"`, `"french"`). Claude는 기본적으로 이 언어로 응답합니다 | `"japanese"` |
| `autoUpdatesChannel` | 업데이트를 따를 릴리스 채널. `"stable"`은 일반적으로 약 1주일 된 버전으로 주요 회귀가 있는 버전은 건너뛰고, `"latest"`(기본값)는 가장 최신 릴리스입니다 | `"stable"` |
| `spinnerTipsEnabled` | Claude가 작업 중일 때 스피너에 팁을 표시합니다. `false`로 설정하면 팁을 비활성화합니다 (기본값: `true`) | `false` |
| `terminalProgressBarEnabled` | Windows Terminal 및 iTerm2와 같은 지원되는 터미널에서 진행 상황을 표시하는 터미널 진행률 표시줄을 활성화합니다 (기본값: `true`) | `false` |

### 권한 설정

| 키 | 설명 | 예시 |
| :--- | :--- | :--- |
| `allow` | 도구 사용을 허용하는 권한 규칙 배열. 패턴 매칭에 대한 자세한 내용은 아래 [권한 규칙 문법](#권한-규칙-문법) 참조 | `[ "Bash(git diff:*)" ]` |
| `ask` | 도구 사용 시 확인을 요청하는 권한 규칙 배열. 아래 [권한 규칙 문법](#권한-규칙-문법) 참조 | `[ "Bash(git push:*)" ]` |
| `deny` | 도구 사용을 거부하는 권한 규칙 배열. Claude Code 접근에서 민감한 파일을 제외하는 데 사용합니다. [권한 규칙 문법](#권한-규칙-문법) 및 [Bash 권한 제한사항](/en/iam#tool-specific-permission-rules) 참조 | `[ "WebFetch", "Bash(curl:*)", "Read(./.env)", "Read(./secrets/**)" ]` |
| `additionalDirectories` | Claude가 접근할 수 있는 추가 [작업 디렉토리](/en/iam#working-directories) | `[ "../docs/" ]` |
| `defaultMode` | Claude Code를 열 때의 기본 [권한 모드](/en/iam#permission-modes) | `"acceptEdits"` |
| `disableBypassPermissionsMode` | `"disable"`로 설정하면 `bypassPermissions` 모드 활성화를 방지합니다. 이는 `--dangerously-skip-permissions` 명령줄 플래그를 비활성화합니다. [managed 설정](/en/iam#managed-settings) 참조 | `"disable"` |

### 권한 규칙 문법

권한 규칙은 `Tool` 또는 `Tool(specifier)` 형식을 따릅니다. 문법을 이해하면 의도한 대로 정확히 매칭되는 규칙을 작성할 수 있습니다.

#### 규칙 평가 순서

여러 규칙이 동일한 도구 사용에 매칭될 수 있는 경우, 규칙은 다음 순서로 평가됩니다:

1. **Deny** 규칙이 먼저 확인됨
2. **Ask** 규칙이 두 번째로 확인됨
3. **Allow** 규칙이 마지막으로 확인됨

첫 번째로 매칭되는 규칙이 동작을 결정합니다. 즉, 동일한 명령에 deny와 allow 규칙이 모두 매칭되더라도 deny 규칙이 항상 우선합니다.

#### 도구의 모든 사용에 매칭하기

도구의 모든 사용에 매칭하려면 괄호 없이 도구 이름만 사용합니다:

| 규칙 | 효과 |
| :--- | :--- |
| `Bash` | **모든** Bash 명령에 매칭 |
| `WebFetch` | **모든** 웹 페치 요청에 매칭 |
| `Read` | **모든** 파일 읽기에 매칭 |

> **주의**: `Bash(*)`는 모든 Bash 명령에 매칭되지 **않습니다**. `*` 와일드카드는 specifier 컨텍스트 내에서만 매칭됩니다. 도구의 모든 사용을 허용하거나 거부하려면 `Bash(*)`가 아닌 `Bash`만 사용하세요.

#### 세밀한 제어를 위한 specifier 사용

특정 도구 사용에 매칭하려면 괄호 안에 specifier를 추가합니다:

| 규칙 | 효과 |
| :--- | :--- |
| `Bash(npm run build)` | 정확히 `npm run build` 명령에 매칭 |
| `Read(./.env)` | 현재 디렉토리의 `.env` 파일 읽기에 매칭 |
| `WebFetch(domain:example.com)` | example.com에 대한 페치 요청에 매칭 |

#### 와일드카드 패턴

Bash 규칙에는 두 가지 와일드카드 문법이 있습니다:

| 와일드카드 | 위치 | 동작 | 예시 |
| :--- | :--- | :--- | :--- |
| `:*` | 패턴 끝에만 | 단어 경계가 있는 **접두사 매칭**. 접두사 뒤에 공백이나 문자열 끝이 와야 합니다. | `Bash(ls:*)` 는 `ls -la`에 매칭되지만 `lsof`에는 매칭되지 않음 |
| `*` | 패턴 어디든 | 단어 경계 없는 **글로브 매칭**. 해당 위치에서 임의의 문자 시퀀스에 매칭됩니다. | `Bash(ls*)` 는 `ls -la`와 `lsof` 모두에 매칭 |

**`:*`를 사용한 접두사 매칭**

`:*` 접미사는 지정된 접두사로 시작하는 모든 명령에 매칭됩니다. 여러 단어 명령에서도 작동합니다. 다음 설정은 npm과 git commit 명령을 허용하면서 git push와 rm -rf를 차단합니다:

```json
{
  "permissions": {
    "allow": [
      "Bash(npm run:*)",
      "Bash(git commit:*)",
      "Bash(docker compose:*)"
    ],
    "deny": [
      "Bash(git push:*)",
      "Bash(rm -rf:*)"
    ]
  }
}
```

**`*`를 사용한 글로브 매칭**

`*` 와일드카드는 패턴의 시작, 중간, 또는 끝에 나타날 수 있습니다. 다음 설정은 main을 대상으로 하는 모든 git 명령(`git checkout main`, `git merge main` 등)과 모든 버전 확인 명령(`node --version`, `npm --version` 등)을 허용합니다:

```json
{
  "permissions": {
    "allow": [
      "Bash(git * main)",
      "Bash(* --version)"
    ]
  }
}
```

> **주의**: 명령 인자를 제한하려는 Bash 권한 패턴은 취약합니다. 예를 들어 `Bash(curl http://github.com/:*)`는 curl을 GitHub URL로 제한하려는 의도이지만, `curl -X GET http://github.com/...`(URL 앞에 플래그), `curl https://github.com/...`(다른 프로토콜), 또는 셸 변수를 사용하는 명령에는 매칭되지 않습니다. 인자를 제한하는 패턴을 보안 경계로 의존하지 마세요. 대안은 [Bash 권한 제한사항](/en/iam#tool-specific-permission-rules)을 참조하세요.

도구별 권한 패턴에 대한 자세한 정보(Read, Edit, WebFetch, MCP, Task 규칙 및 Bash 권한 제한사항 포함)는 [도구별 권한 규칙](/en/iam#tool-specific-permission-rules)을 참조하세요.

### 샌드박스 설정

고급 샌드박싱 동작을 구성합니다. 샌드박싱은 bash 명령을 파일 시스템 및 네트워크로부터 격리합니다. 자세한 내용은 [샌드박싱](/en/sandboxing)을 참조하세요.

**파일 시스템 및 네트워크 제한**은 이 샌드박스 설정이 아닌 Read, Edit, WebFetch 권한 규칙을 통해 구성됩니다.

| 키 | 설명 | 예시 |
| :--- | :--- | :--- |
| `enabled` | bash 샌드박싱 활성화 (macOS/Linux 전용). 기본값: false | `true` |
| `autoAllowBashIfSandboxed` | 샌드박스 상태일 때 bash 명령 자동 승인. 기본값: true | `true` |
| `excludedCommands` | 샌드박스 외부에서 실행해야 하는 명령 | `["git", "docker"]` |
| `allowUnsandboxedCommands` | `dangerouslyDisableSandbox` 매개변수를 통해 명령이 샌드박스 외부에서 실행되도록 허용합니다. `false`로 설정하면 `dangerouslyDisableSandbox` 탈출 장치가 완전히 비활성화되어 모든 명령이 샌드박스 내에서 실행되거나 `excludedCommands`에 있어야 합니다. 엄격한 샌드박싱이 필요한 기업 정책에 유용합니다. 기본값: true | `false` |
| `network.allowUnixSockets` | 샌드박스에서 접근 가능한 Unix 소켓 경로 (SSH 에이전트 등) | `["~/.ssh/agent-socket"]` |
| `network.allowLocalBinding` | localhost 포트 바인딩 허용 (macOS 전용). 기본값: false | `true` |
| `network.httpProxyPort` | 자체 프록시를 사용하려는 경우 HTTP 프록시 포트. 지정하지 않으면 Claude가 자체 프록시를 실행합니다 | `8080` |
| `network.socksProxyPort` | 자체 프록시를 사용하려는 경우 SOCKS5 프록시 포트. 지정하지 않으면 Claude가 자체 프록시를 실행합니다 | `8081` |
| `enableWeakerNestedSandbox` | 권한이 없는 Docker 환경에서 더 약한 샌드박스 활성화 (Linux 전용). **보안이 약화됩니다.** 기본값: false | `true` |

**구성 예시:**

```json
{
  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true,
    "excludedCommands": ["docker"],
    "network": {
      "allowUnixSockets": [
        "/var/run/docker.sock"
      ],
      "allowLocalBinding": true
    }
  },
  "permissions": {
    "deny": [
      "Read(.envrc)",
      "Read(~/.aws/**)"
    ]
  }
}
```

**파일 시스템 및 네트워크 제한**은 표준 권한 규칙을 사용합니다:

* `Read` deny 규칙을 사용하여 Claude가 특정 파일이나 디렉토리를 읽지 못하도록 차단
* `Edit` allow 규칙을 사용하여 Claude가 현재 작업 디렉토리 이외의 디렉토리에 쓸 수 있도록 허용
* `Edit` deny 규칙을 사용하여 특정 경로에 대한 쓰기를 차단
* `WebFetch` allow/deny 규칙을 사용하여 Claude가 접근할 수 있는 네트워크 도메인을 제어

### 저작자 표시 설정

Claude Code는 git 커밋과 풀 리퀘스트에 저작자 표시를 추가합니다. 이들은 별도로 구성됩니다:

* 커밋은 기본적으로 [git trailers](https://git-scm.com/docs/git-interpret-trailers)(`Co-Authored-By` 등)를 사용하며, 커스터마이즈하거나 비활성화할 수 있습니다
* 풀 리퀘스트 설명은 일반 텍스트입니다

| 키 | 설명 |
| :--- | :--- |
| `commit` | trailer를 포함한 git 커밋의 저작자 표시. 빈 문자열이면 커밋 저작자 표시를 숨깁니다 |
| `pr` | 풀 리퀘스트 설명의 저작자 표시. 빈 문자열이면 풀 리퀘스트 저작자 표시를 숨깁니다 |

**기본 커밋 저작자 표시:**

```
🤖 Generated with [Claude Code](https://claude.com/claude-code)

   Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**기본 풀 리퀘스트 저작자 표시:**

```
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

**예시:**

```json
{
  "attribution": {
    "commit": "AI로 생성됨\n\nCo-Authored-By: AI <ai@example.com>",
    "pr": ""
  }
}
```

> **참고**: `attribution` 설정은 사용 중단된 `includeCoAuthoredBy` 설정보다 우선합니다. 모든 저작자 표시를 숨기려면 `commit`과 `pr`을 빈 문자열로 설정하세요.

### 파일 제안 설정

`@` 파일 경로 자동완성을 위한 커스텀 명령을 구성합니다. 내장 파일 제안은 빠른 파일 시스템 탐색을 사용하지만, 대규모 모노레포는 미리 빌드된 파일 인덱스나 커스텀 도구와 같은 프로젝트별 인덱싱의 이점을 얻을 수 있습니다.

```json
{
  "fileSuggestion": {
    "type": "command",
    "command": "~/.claude/file-suggestion.sh"
  }
}
```

명령은 [훅](/en/hooks)과 동일한 환경 변수로 실행되며, `CLAUDE_PROJECT_DIR`을 포함합니다. stdin을 통해 `query` 필드가 포함된 JSON을 받습니다:

```json
{"query": "src/comp"}
```

stdout으로 개행으로 구분된 파일 경로를 출력합니다 (현재 15개로 제한):

```
src/components/Button.tsx
src/components/Modal.tsx
src/components/Form.tsx
```

**예시:**

```bash
#!/bin/bash
query=$(cat | jq -r '.query')
your-repo-file-index --query "$query" | head -20
```

### 훅 구성

**Managed 설정 전용**: 어떤 훅이 실행되도록 허용할지 제어합니다. 이 설정은 [managed 설정](#설정-파일)에서만 구성할 수 있으며 관리자에게 훅 실행에 대한 엄격한 제어를 제공합니다.

**`allowManagedHooksOnly`가 `true`일 때의 동작:**

* Managed 훅과 SDK 훅이 로드됨
* User 훅, Project 훅, 플러그인 훅은 차단됨

**구성:**

```json
{
  "allowManagedHooksOnly": true
}
```

### 설정 우선순위

설정은 우선순위 순서로 적용됩니다. 높은 것부터 낮은 순서로:

1. **Managed 설정** (`managed-settings.json`)
   * IT/DevOps가 시스템 디렉토리에 배포한 정책
   * User나 Project 설정으로 덮어쓸 수 없음

2. **명령줄 인자**
   * 특정 세션에 대한 임시 덮어쓰기

3. **Local project 설정** (`.claude/settings.local.json`)
   * 개인 프로젝트별 설정

4. **공유 Project 설정** (`.claude/settings.json`)
   * 소스 컨트롤에 있는 팀 공유 프로젝트 설정

5. **User 설정** (`~/.claude/settings.json`)
   * 개인 전역 설정

이 계층 구조는 조직 정책이 항상 적용되면서도 팀과 개인이 자신의 경험을 커스터마이즈할 수 있도록 보장합니다.

예를 들어, User 설정에서 `Bash(npm run:*)`를 허용하더라도 프로젝트의 공유 설정에서 이를 거부하면, 프로젝트 설정이 우선하여 명령이 차단됩니다.

### 구성 시스템의 핵심 사항

* **메모리 파일 (`CLAUDE.md`)**: Claude가 시작 시 로드하는 지침과 컨텍스트를 포함
* **설정 파일 (JSON)**: 권한, 환경 변수, 도구 동작을 구성
* **Skills**: `/skill-name`으로 호출하거나 Claude가 자동으로 로드할 수 있는 커스텀 프롬프트
* **MCP 서버**: 추가 도구 및 통합으로 Claude Code를 확장
* **우선순위**: 상위 수준 구성(Managed)이 하위 수준(User/Project)을 덮어씀
* **상속**: 설정이 병합되며, 더 구체적인 설정이 더 넓은 설정에 추가되거나 덮어씀

### 시스템 프롬프트

Claude Code의 내부 시스템 프롬프트는 공개되지 않습니다. 커스텀 지침을 추가하려면 `CLAUDE.md` 파일이나 `--append-system-prompt` 플래그를 사용하세요.

### 민감한 파일 제외하기

API 키, 시크릿, 환경 파일과 같은 민감한 정보가 포함된 파일에 Claude Code가 접근하지 못하도록 하려면 `.claude/settings.json` 파일의 `permissions.deny` 설정을 사용하세요:

```json
{
  "permissions": {
    "deny": [
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./secrets/**)",
      "Read(./config/credentials.json)",
      "Read(./build)"
    ]
  }
}
```

이는 사용 중단된 `ignorePatterns` 구성을 대체합니다. 이 패턴과 일치하는 파일은 Claude Code에 완전히 보이지 않게 되어 민감한 데이터의 우발적 노출을 방지합니다.

## 서브에이전트 구성

Claude Code는 User 및 Project 수준에서 구성할 수 있는 커스텀 AI 서브에이전트를 지원합니다. 이러한 서브에이전트는 YAML 프론트매터가 있는 마크다운 파일로 저장됩니다:

* **User 서브에이전트**: `~/.claude/agents/` - 모든 프로젝트에서 사용 가능
* **Project 서브에이전트**: `.claude/agents/` - 프로젝트에 특정하며 팀과 공유할 수 있음

서브에이전트 파일은 커스텀 프롬프트와 도구 권한을 가진 전문화된 AI 어시스턴트를 정의합니다. 서브에이전트 생성 및 사용에 대한 자세한 내용은 [서브에이전트 문서](/en/sub-agents)를 참조하세요.

## 플러그인 구성

Claude Code는 skills, 에이전트, 훅, MCP 서버로 기능을 확장할 수 있는 플러그인 시스템을 지원합니다. 플러그인은 마켓플레이스를 통해 배포되며 User 및 저장소 수준에서 구성할 수 있습니다.

### 플러그인 설정

`settings.json`의 플러그인 관련 설정:

```json
{
  "enabledPlugins": {
    "formatter@acme-tools": true,
    "deployer@acme-tools": true,
    "analyzer@security-plugins": false
  },
  "extraKnownMarketplaces": {
    "acme-tools": {
      "source": "github",
      "repo": "acme-corp/claude-plugins"
    }
  }
}
```

#### `enabledPlugins`

어떤 플러그인이 활성화되어 있는지 제어합니다. 형식: `"plugin-name@marketplace-name": true/false`

**범위**:

* **User 설정** (`~/.claude/settings.json`): 개인 플러그인 환경설정
* **Project 설정** (`.claude/settings.json`): 팀과 공유되는 프로젝트별 플러그인
* **Local 설정** (`.claude/settings.local.json`): 머신별 덮어쓰기 (커밋되지 않음)

**예시**:

```json
{
  "enabledPlugins": {
    "code-formatter@team-tools": true,
    "deployment-tools@team-tools": true,
    "experimental-features@personal": false
  }
}
```

#### `extraKnownMarketplaces`

저장소에서 사용 가능하게 할 추가 마켓플레이스를 정의합니다. 일반적으로 팀원들이 필요한 플러그인 소스에 접근할 수 있도록 저장소 수준 설정에서 사용됩니다.

**저장소에 `extraKnownMarketplaces`가 포함된 경우**:

1. 팀원이 폴더를 신뢰할 때 마켓플레이스 설치 메시지가 표시됨
2. 그 다음 해당 마켓플레이스의 플러그인 설치 메시지가 표시됨
3. 사용자는 원하지 않는 마켓플레이스나 플러그인을 건너뛸 수 있음 (User 설정에 저장됨)
4. 설치는 신뢰 경계를 준수하며 명시적 동의가 필요함

**예시**:

```json
{
  "extraKnownMarketplaces": {
    "acme-tools": {
      "source": {
        "source": "github",
        "repo": "acme-corp/claude-plugins"
      }
    },
    "security-plugins": {
      "source": {
        "source": "git",
        "url": "https://git.example.com/security/plugins.git"
      }
    }
  }
}
```

**마켓플레이스 소스 유형**:

* `github`: GitHub 저장소 (`repo` 사용)
* `git`: 모든 git URL (`url` 사용)
* `directory`: 로컬 파일 시스템 경로 (`path` 사용, 개발용으로만)

#### `strictKnownMarketplaces`

**Managed 설정 전용**: 사용자가 추가할 수 있는 플러그인 마켓플레이스를 제어합니다. 이 설정은 [`managed-settings.json`](/en/iam#managed-settings)에서만 구성할 수 있으며 관리자에게 마켓플레이스 소스에 대한 엄격한 제어를 제공합니다.

**Managed 설정 파일 위치**:

* **macOS**: `/Library/Application Support/ClaudeCode/managed-settings.json`
* **Linux 및 WSL**: `/etc/claude-code/managed-settings.json`
* **Windows**: `C:\Program Files\ClaudeCode\managed-settings.json`

**주요 특성**:

* Managed 설정에서만 사용 가능 (`managed-settings.json`)
* User나 Project 설정으로 덮어쓸 수 없음 (최상위 우선순위)
* 네트워크/파일 시스템 작업 전에 적용됨 (차단된 소스는 실행되지 않음)
* 소스 사양에 대해 정확한 매칭 사용 (git 소스의 `ref`, `path` 포함)

**허용 목록 동작**:

* `undefined` (기본값): 제한 없음 - 사용자가 모든 마켓플레이스 추가 가능
* 빈 배열 `[]`: 완전 차단 - 사용자가 새 마켓플레이스 추가 불가
* 소스 목록: 사용자는 정확히 일치하는 마켓플레이스만 추가 가능

**지원되는 모든 소스 유형**:

허용 목록은 6가지 마켓플레이스 소스 유형을 지원합니다. 각 소스는 사용자의 마켓플레이스 추가가 허용되려면 정확히 일치해야 합니다.

1. **GitHub 저장소**:

```json
{ "source": "github", "repo": "acme-corp/approved-plugins" }
{ "source": "github", "repo": "acme-corp/security-tools", "ref": "v2.0" }
{ "source": "github", "repo": "acme-corp/plugins", "ref": "main", "path": "marketplace" }
```

필드: `repo` (필수), `ref` (선택: 브랜치/태그/SHA), `path` (선택: 하위 디렉토리)

2. **Git 저장소**:

```json
{ "source": "git", "url": "https://gitlab.example.com/tools/plugins.git" }
{ "source": "git", "url": "https://bitbucket.org/acme-corp/plugins.git", "ref": "production" }
{ "source": "git", "url": "ssh://git@git.example.com/plugins.git", "ref": "v3.1", "path": "approved" }
```

필드: `url` (필수), `ref` (선택: 브랜치/태그/SHA), `path` (선택: 하위 디렉토리)

3. **URL 기반 마켓플레이스**:

```json
{ "source": "url", "url": "https://plugins.example.com/marketplace.json" }
{ "source": "url", "url": "https://cdn.example.com/marketplace.json", "headers": { "Authorization": "Bearer ${TOKEN}" } }
```

필드: `url` (필수), `headers` (선택: 인증된 접근을 위한 HTTP 헤더)

> **참고**: URL 기반 마켓플레이스는 `marketplace.json` 파일만 다운로드합니다. 서버에서 플러그인 파일을 다운로드하지 않습니다. URL 기반 마켓플레이스의 플러그인은 상대 경로가 아닌 외부 소스(GitHub, npm, 또는 git URL)를 사용해야 합니다. 상대 경로가 있는 플러그인의 경우 Git 기반 마켓플레이스를 대신 사용하세요. 자세한 내용은 [문제 해결](/en/plugin-marketplaces#plugins-with-relative-paths-fail-in-url-based-marketplaces)을 참조하세요.

4. **NPM 패키지**:

```json
{ "source": "npm", "package": "@acme-corp/claude-plugins" }
{ "source": "npm", "package": "@acme-corp/approved-marketplace" }
```

필드: `package` (필수, 스코프드 패키지 지원)

5. **파일 경로**:

```json
{ "source": "file", "path": "/usr/local/share/claude/acme-marketplace.json" }
{ "source": "file", "path": "/opt/acme-corp/plugins/marketplace.json" }
```

필드: `path` (필수: marketplace.json 파일의 절대 경로)

6. **디렉토리 경로**:

```json
{ "source": "directory", "path": "/usr/local/share/claude/acme-plugins" }
{ "source": "directory", "path": "/opt/acme-corp/approved-marketplaces" }
```

필드: `path` (필수: `.claude-plugin/marketplace.json`을 포함하는 디렉토리의 절대 경로)

**구성 예시**:

예시 - 특정 마켓플레이스만 허용:

```json
{
  "strictKnownMarketplaces": [
    {
      "source": "github",
      "repo": "acme-corp/approved-plugins"
    },
    {
      "source": "github",
      "repo": "acme-corp/security-tools",
      "ref": "v2.0"
    },
    {
      "source": "url",
      "url": "https://plugins.example.com/marketplace.json"
    },
    {
      "source": "npm",
      "package": "@acme-corp/compliance-plugins"
    }
  ]
}
```

예시 - 모든 마켓플레이스 추가 비활성화:

```json
{
  "strictKnownMarketplaces": []
}
```

**정확한 매칭 요구사항**:

마켓플레이스 소스는 사용자의 추가가 허용되려면 **정확히** 일치해야 합니다. git 기반 소스(`github` 및 `git`)의 경우 모든 선택적 필드가 포함됩니다:

* `repo` 또는 `url`이 정확히 일치해야 함
* `ref` 필드가 정확히 일치해야 함 (또는 둘 다 정의되지 않음)
* `path` 필드가 정확히 일치해야 함 (또는 둘 다 정의되지 않음)

일치하지 **않는** 소스의 예:

```json
// 이들은 다른 소스입니다:
{ "source": "github", "repo": "acme-corp/plugins" }
{ "source": "github", "repo": "acme-corp/plugins", "ref": "main" }

// 이들도 다른 소스입니다:
{ "source": "github", "repo": "acme-corp/plugins", "path": "marketplace" }
{ "source": "github", "repo": "acme-corp/plugins" }
```

**`extraKnownMarketplaces`와의 비교**:

| 측면 | `strictKnownMarketplaces` | `extraKnownMarketplaces` |
| --- | --- | --- |
| **목적** | 조직 정책 적용 | 팀 편의성 |
| **설정 파일** | `managed-settings.json`만 | 모든 설정 파일 |
| **동작** | 허용 목록에 없는 추가 차단 | 누락된 마켓플레이스 자동 설치 |
| **적용 시점** | 네트워크/파일 시스템 작업 전 | 사용자 신뢰 프롬프트 후 |
| **덮어쓰기 가능** | 아니오 (최상위 우선순위) | 예 (더 높은 우선순위 설정에 의해) |
| **소스 형식** | 직접 소스 객체 | 중첩된 소스가 있는 이름 있는 마켓플레이스 |
| **사용 사례** | 컴플라이언스, 보안 제한 | 온보딩, 표준화 |

**형식 차이**:

`strictKnownMarketplaces`는 직접 소스 객체를 사용합니다:

```json
{
  "strictKnownMarketplaces": [
    { "source": "github", "repo": "acme-corp/plugins" }
  ]
}
```

`extraKnownMarketplaces`는 이름 있는 마켓플레이스가 필요합니다:

```json
{
  "extraKnownMarketplaces": {
    "acme-tools": {
      "source": { "source": "github", "repo": "acme-corp/plugins" }
    }
  }
}
```

**중요 사항**:

* 제한은 모든 네트워크 요청이나 파일 시스템 작업 전에 확인됩니다
* 차단되면 사용자에게 소스가 managed 정책에 의해 차단되었음을 나타내는 명확한 오류 메시지가 표시됩니다
* 제한은 새 마켓플레이스 추가에만 적용됩니다; 이전에 설치된 마켓플레이스는 계속 접근 가능합니다
* Managed 설정은 최상위 우선순위를 가지며 덮어쓸 수 없습니다

사용자 대상 문서는 [Managed 마켓플레이스 제한](/en/plugin-marketplaces#managed-marketplace-restrictions)을 참조하세요.

### 플러그인 관리

`/plugin` 명령을 사용하여 플러그인을 대화형으로 관리합니다:

* 마켓플레이스에서 사용 가능한 플러그인 탐색
* 플러그인 설치/제거
* 플러그인 활성화/비활성화
* 플러그인 세부 정보 보기 (제공되는 명령, 에이전트, 훅)
* 마켓플레이스 추가/제거

플러그인 시스템에 대한 자세한 내용은 [플러그인 문서](/en/plugins)를 참조하세요.

## 환경 변수

Claude Code는 동작을 제어하기 위해 다음 환경 변수를 지원합니다:

> **참고**: 모든 환경 변수는 [`settings.json`](#사용-가능한-설정-항목)에서도 구성할 수 있습니다. 이는 각 세션에 대해 자동으로 환경 변수를 설정하거나 전체 팀이나 조직에 환경 변수 세트를 배포하는 방법으로 유용합니다.

| 변수 | 목적 |
| :--- | :--- |
| `ANTHROPIC_API_KEY` | `X-Api-Key` 헤더로 전송되는 API 키, 일반적으로 Claude SDK용 (대화형 사용의 경우 `/login` 실행) |
| `ANTHROPIC_AUTH_TOKEN` | `Authorization` 헤더의 커스텀 값 (여기서 설정한 값은 `Bearer ` 접두사가 붙음) |
| `ANTHROPIC_CUSTOM_HEADERS` | 요청에 추가하려는 커스텀 헤더 (`Name: Value` 형식) |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | [모델 구성](/en/model-config#environment-variables) 참조 |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | [모델 구성](/en/model-config#environment-variables) 참조 |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | [모델 구성](/en/model-config#environment-variables) 참조 |
| `ANTHROPIC_FOUNDRY_API_KEY` | Microsoft Foundry 인증용 API 키 ([Microsoft Foundry](/en/microsoft-foundry) 참조) |
| `ANTHROPIC_MODEL` | 사용할 모델 설정의 이름 ([모델 구성](/en/model-config#environment-variables) 참조) |
| `ANTHROPIC_SMALL_FAST_MODEL` | \[사용 중단됨\] [백그라운드 작업용 Haiku 급 모델](/en/costs)의 이름 |
| `ANTHROPIC_SMALL_FAST_MODEL_AWS_REGION` | Bedrock 사용 시 Haiku 급 모델의 AWS 리전 덮어쓰기 |
| `AWS_BEARER_TOKEN_BEDROCK` | 인증용 Bedrock API 키 ([Bedrock API 키](https://aws.amazon.com/blogs/machine-learning/accelerate-ai-development-with-amazon-bedrock-api-keys/) 참조) |
| `BASH_DEFAULT_TIMEOUT_MS` | 장시간 실행 bash 명령의 기본 타임아웃 |
| `BASH_MAX_OUTPUT_LENGTH` | 중간 잘림 전 bash 출력의 최대 문자 수 |
| `BASH_MAX_TIMEOUT_MS` | 모델이 장시간 실행 bash 명령에 설정할 수 있는 최대 타임아웃 |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | 자동 압축이 트리거되는 컨텍스트 용량 백분율(1-100)을 설정합니다. 기본적으로 자동 압축은 약 95% 용량에서 트리거됩니다. `50`과 같은 낮은 값을 사용하면 더 일찍 압축합니다. 기본 임계값보다 높은 값은 효과가 없습니다. 메인 대화와 서브에이전트 모두에 적용됩니다. 이 백분율은 [상태 라인](/en/statusline)에서 사용 가능한 `context_window.used_percentage` 필드와 일치합니다 |
| `CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR` | 각 Bash 명령 후 원래 작업 디렉토리로 복귀 |
| `CLAUDE_CODE_API_KEY_HELPER_TTL_MS` | 자격 증명을 새로 고쳐야 하는 간격(밀리초) (`apiKeyHelper` 사용 시) |
| `CLAUDE_CODE_CLIENT_CERT` | mTLS 인증용 클라이언트 인증서 파일 경로 |
| `CLAUDE_CODE_CLIENT_KEY_PASSPHRASE` | 암호화된 CLAUDE_CODE_CLIENT_KEY의 암호문 (선택사항) |
| `CLAUDE_CODE_CLIENT_KEY` | mTLS 인증용 클라이언트 개인 키 파일 경로 |
| `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS` | `1`로 설정하면 Anthropic API 전용 `anthropic-beta` 헤더를 비활성화합니다. 타사 제공업체와 LLM 게이트웨이 사용 시 "`anthropic-beta` 헤더에 예상치 못한 값" 같은 문제가 발생할 때 사용하세요 |
| `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` | `1`로 설정하면 Bash 및 서브에이전트 도구의 `run_in_background` 매개변수, 자동 백그라운드 처리, Ctrl+B 단축키를 포함한 모든 백그라운드 작업 기능을 비활성화합니다 |
| `CLAUDE_CODE_EXIT_AFTER_STOP_DELAY` | 쿼리 루프가 유휴 상태가 된 후 자동으로 종료되기까지 대기하는 시간(밀리초). SDK 모드를 사용하는 자동화된 워크플로우와 스크립트에 유용합니다 |
| `CLAUDE_CODE_PROXY_RESOLVES_HOSTS` | `true`로 설정하면 호출자 대신 프록시가 DNS 확인을 수행하도록 허용합니다. 프록시가 호스트 이름 확인을 처리해야 하는 환경을 위한 옵트인 |
| `CLAUDE_CODE_TMPDIR` | 내부 임시 파일에 사용되는 임시 디렉토리를 덮어씁니다. Claude Code는 이 경로에 `/claude/`를 추가합니다. 기본값: Unix/macOS에서 `/tmp`, Windows에서 `os.tmpdir()` |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | `DISABLE_AUTOUPDATER`, `DISABLE_BUG_COMMAND`, `DISABLE_ERROR_REPORTING`, `DISABLE_TELEMETRY` 설정과 동등 |
| `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` | `1`로 설정하면 대화 컨텍스트에 기반한 자동 터미널 제목 업데이트를 비활성화합니다 |
| `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS` | 파일 읽기의 기본 토큰 제한을 덮어씁니다. 더 큰 파일을 전체로 읽어야 할 때 유용합니다 |
| `CLAUDE_CODE_HIDE_ACCOUNT_INFO` | `1`로 설정하면 Claude Code UI에서 이메일 주소와 조직 이름을 숨깁니다. 스트리밍이나 녹화 시 유용합니다 |
| `CLAUDE_CODE_IDE_SKIP_AUTO_INSTALL` | IDE 확장의 자동 설치를 건너뜁니다 |
| `CLAUDE_CODE_MAX_OUTPUT_TOKENS` | 대부분의 요청에 대한 최대 출력 토큰 수를 설정합니다. 기본값: 32,000. 최대값: 64,000. 이 값을 늘리면 [자동 압축](/en/costs#reduce-token-usage) 트리거 전에 사용 가능한 유효 컨텍스트 창이 줄어듭니다 |
| `CLAUDE_CODE_OTEL_HEADERS_HELPER_DEBOUNCE_MS` | 동적 OpenTelemetry 헤더 새로 고침 간격(밀리초) (기본값: 1740000 / 29분). [동적 헤더](/en/monitoring-usage#dynamic-headers) 참조 |
| `CLAUDE_CODE_SHELL` | 자동 셸 감지를 덮어씁니다. 로그인 셸이 선호하는 작업 셸과 다를 때 유용합니다 (예: `bash` vs `zsh`) |
| `CLAUDE_CODE_SHELL_PREFIX` | 모든 bash 명령을 래핑하는 명령 접두사 (예: 로깅 또는 감사용). 예: `/path/to/logger.sh`는 `/path/to/logger.sh <command>`를 실행합니다 |
| `CLAUDE_CODE_SKIP_BEDROCK_AUTH` | Bedrock용 AWS 인증 건너뛰기 (예: LLM 게이트웨이 사용 시) |
| `CLAUDE_CODE_SKIP_FOUNDRY_AUTH` | Microsoft Foundry용 Azure 인증 건너뛰기 (예: LLM 게이트웨이 사용 시) |
| `CLAUDE_CODE_SKIP_VERTEX_AUTH` | Vertex용 Google 인증 건너뛰기 (예: LLM 게이트웨이 사용 시) |
| `CLAUDE_CODE_SUBAGENT_MODEL` | [모델 구성](/en/model-config) 참조 |
| `CLAUDE_CODE_USE_BEDROCK` | [Bedrock](/en/amazon-bedrock) 사용 |
| `CLAUDE_CODE_USE_FOUNDRY` | [Microsoft Foundry](/en/microsoft-foundry) 사용 |
| `CLAUDE_CODE_USE_VERTEX` | [Vertex](/en/google-vertex-ai) 사용 |
| `CLAUDE_CONFIG_DIR` | Claude Code가 구성 및 데이터 파일을 저장하는 위치를 커스터마이즈 |
| `DISABLE_AUTOUPDATER` | `1`로 설정하면 자동 업데이트를 비활성화합니다 |
| `DISABLE_BUG_COMMAND` | `1`로 설정하면 `/bug` 명령을 비활성화합니다 |
| `DISABLE_COST_WARNINGS` | `1`로 설정하면 비용 경고 메시지를 비활성화합니다 |
| `DISABLE_ERROR_REPORTING` | `1`로 설정하면 Sentry 오류 보고를 옵트아웃합니다 |
| `DISABLE_NON_ESSENTIAL_MODEL_CALLS` | `1`로 설정하면 플레이버 텍스트와 같은 비중요 경로의 모델 호출을 비활성화합니다 |
| `DISABLE_PROMPT_CACHING` | `1`로 설정하면 모든 모델에 대해 프롬프트 캐싱을 비활성화합니다 (모델별 설정보다 우선) |
| `DISABLE_PROMPT_CACHING_HAIKU` | `1`로 설정하면 Haiku 모델에 대해 프롬프트 캐싱을 비활성화합니다 |
| `DISABLE_PROMPT_CACHING_OPUS` | `1`로 설정하면 Opus 모델에 대해 프롬프트 캐싱을 비활성화합니다 |
| `DISABLE_PROMPT_CACHING_SONNET` | `1`로 설정하면 Sonnet 모델에 대해 프롬프트 캐싱을 비활성화합니다 |
| `DISABLE_TELEMETRY` | `1`로 설정하면 Statsig 텔레메트리를 옵트아웃합니다 (Statsig 이벤트에는 코드, 파일 경로, bash 명령과 같은 사용자 데이터가 포함되지 않음) |
| `ENABLE_TOOL_SEARCH` | [MCP 도구 검색](/en/mcp#scale-with-mcp-tool-search)을 제어합니다. 값: `auto` (기본값, 컨텍스트 10%에서 활성화), `auto:N` (커스텀 임계값, 예: 5%의 경우 `auto:5`), `true` (항상 켜짐), `false` (비활성화) |
| `FORCE_AUTOUPDATE_PLUGINS` | `true`로 설정하면 `DISABLE_AUTOUPDATER`로 메인 자동 업데이터가 비활성화되어도 플러그인 자동 업데이트를 강제합니다 |
| `HTTP_PROXY` | 네트워크 연결용 HTTP 프록시 서버 지정 |
| `HTTPS_PROXY` | 네트워크 연결용 HTTPS 프록시 서버 지정 |
| `IS_DEMO` | `true`로 설정하면 데모 모드 활성화: UI에서 이메일과 조직을 숨기고, 온보딩을 건너뛰고, 내부 명령을 숨깁니다. 스트리밍이나 세션 녹화에 유용합니다 |
| `MAX_MCP_OUTPUT_TOKENS` | MCP 도구 응답에서 허용되는 최대 토큰 수. 출력이 10,000 토큰을 초과하면 Claude Code가 경고를 표시합니다 (기본값: 25000) |
| `MAX_THINKING_TOKENS` | [확장 사고](https://docs.claude.com/en/docs/build-with-claude/extended-thinking) 토큰 예산을 덮어씁니다. 사고는 기본적으로 최대 예산(31,999 토큰)으로 활성화됩니다. 예산을 제한하려면 이것을 사용하세요 (예: `MAX_THINKING_TOKENS=10000`) 또는 사고를 완전히 비활성화하려면 (`MAX_THINKING_TOKENS=0`). 확장 사고는 복잡한 추론 및 코딩 작업의 성능을 향상시키지만 [프롬프트 캐싱 효율성](https://docs.claude.com/en/docs/build-with-claude/prompt-caching#caching-with-thinking-blocks)에 영향을 미칩니다 |
| `MCP_TIMEOUT` | MCP 서버 시작 타임아웃(밀리초) |
| `MCP_TOOL_TIMEOUT` | MCP 도구 실행 타임아웃(밀리초) |
| `NO_PROXY` | 프록시를 우회하여 직접 요청할 도메인 및 IP 목록 |
| `SLASH_COMMAND_TOOL_CHAR_BUDGET` | [Skill 도구](/en/skills#control-who-invokes-a-skill)에 표시되는 skill 메타데이터의 최대 문자 수 (기본값: 15000). 하위 호환성을 위해 레거시 이름 유지 |
| `USE_BUILTIN_RIPGREP` | `0`으로 설정하면 Claude Code에 포함된 `rg` 대신 시스템에 설치된 `rg`를 사용 |
| `VERTEX_REGION_CLAUDE_3_5_HAIKU` | Vertex AI 사용 시 Claude 3.5 Haiku의 리전 덮어쓰기 |
| `VERTEX_REGION_CLAUDE_3_7_SONNET` | Vertex AI 사용 시 Claude 3.7 Sonnet의 리전 덮어쓰기 |
| `VERTEX_REGION_CLAUDE_4_0_OPUS` | Vertex AI 사용 시 Claude 4.0 Opus의 리전 덮어쓰기 |
| `VERTEX_REGION_CLAUDE_4_0_SONNET` | Vertex AI 사용 시 Claude 4.0 Sonnet의 리전 덮어쓰기 |
| `VERTEX_REGION_CLAUDE_4_1_OPUS` | Vertex AI 사용 시 Claude 4.1 Opus의 리전 덮어쓰기 |

## Claude에서 사용 가능한 도구

Claude Code는 코드베이스를 이해하고 수정하는 데 도움이 되는 강력한 도구 세트에 접근할 수 있습니다:

| 도구 | 설명 | 권한 필요 |
| :--- | :--- | :--- |
| **AskUserQuestion** | 요구사항을 수집하거나 모호함을 명확히 하기 위한 객관식 질문 | 아니오 |
| **Bash** | 환경에서 셸 명령 실행 (아래 [Bash 도구 동작](#bash-도구-동작) 참조) | 예 |
| **TaskOutput** | 백그라운드 작업(bash 셸 또는 서브에이전트)의 출력을 가져옴 | 아니오 |
| **Edit** | 특정 파일에 대상 지정 편집 수행 | 예 |
| **ExitPlanMode** | 사용자에게 계획 모드 종료 및 코딩 시작 프롬프트 | 예 |
| **Glob** | 패턴 매칭을 기반으로 파일 찾기 | 아니오 |
| **Grep** | 파일 내용에서 패턴 검색 | 아니오 |
| **KillShell** | ID로 실행 중인 백그라운드 bash 셸 종료 | 아니오 |
| **MCPSearch** | [도구 검색](/en/mcp#scale-with-mcp-tool-search)이 활성화되어 있을 때 MCP 도구 검색 및 로드 | 아니오 |
| **NotebookEdit** | Jupyter 노트북 셀 수정 | 예 |
| **Read** | 파일 내용 읽기 | 아니오 |
| **Skill** | 메인 대화 내에서 [skill](/en/skills#control-who-invokes-a-skill) 실행 | 예 |
| **Task** | 복잡한 다단계 작업을 처리하기 위한 서브에이전트 실행 | 아니오 |
| **TodoWrite** | 구조화된 작업 목록 생성 및 관리 | 아니오 |
| **WebFetch** | 지정된 URL에서 콘텐츠 가져오기 | 예 |
| **WebSearch** | 도메인 필터링으로 웹 검색 수행 | 예 |
| **Write** | 파일 생성 또는 덮어쓰기 | 예 |

권한 규칙은 `/allowed-tools`를 사용하거나 [권한 설정](/en/settings#available-settings)에서 구성할 수 있습니다. [도구별 권한 규칙](/en/iam#tool-specific-permission-rules)도 참조하세요.

### Bash 도구 동작

Bash 도구는 다음과 같은 지속성 동작으로 셸 명령을 실행합니다:

* **작업 디렉토리는 지속됨**: Claude가 작업 디렉토리를 변경하면 (예: `cd /path/to/dir`) 후속 Bash 명령이 해당 디렉토리에서 실행됩니다. `CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=1`을 사용하면 각 명령 후 프로젝트 디렉토리로 재설정됩니다.
* **환경 변수는 지속되지 않음**: 하나의 Bash 명령에서 설정한 환경 변수 (예: `export MY_VAR=value`)는 후속 Bash 명령에서 사용할 수 **없습니다**. 각 Bash 명령은 새로운 셸 환경에서 실행됩니다.

Bash 명령에서 환경 변수를 사용하려면 **세 가지 옵션**이 있습니다:

**옵션 1: Claude Code 시작 전에 환경 활성화** (가장 간단한 방법)

Claude Code를 시작하기 전에 터미널에서 가상 환경을 활성화합니다:

```bash
conda activate myenv
# 또는: source /path/to/venv/bin/activate
claude
```

이것은 셸 환경에서 작동하지만 Claude의 Bash 명령 내에서 설정된 환경 변수는 명령 간에 지속되지 않습니다.

**옵션 2: Claude Code 시작 전에 CLAUDE_ENV_FILE 설정** (영구적인 환경 설정)

환경 설정이 포함된 셸 스크립트 경로를 내보냅니다:

```bash
export CLAUDE_ENV_FILE=/path/to/env-setup.sh
claude
```

여기서 `/path/to/env-setup.sh`는 다음을 포함합니다:

```bash
conda activate myenv
# 또는: source /path/to/venv/bin/activate
# 또는: export MY_VAR=value
```

Claude Code는 각 Bash 명령 전에 이 파일을 소스하여 환경이 모든 명령에서 영구적으로 적용됩니다.

**옵션 3: SessionStart 훅 사용** (프로젝트별 구성)

`.claude/settings.json`에서 구성:

```json
{
  "hooks": {
    "SessionStart": [{
      "matcher": "startup",
      "hooks": [{
        "type": "command",
        "command": "echo 'conda activate myenv' >> \"$CLAUDE_ENV_FILE\""
      }]
    }]
  }
}
```

훅이 `$CLAUDE_ENV_FILE`에 쓰고, 이 파일은 각 Bash 명령 전에 소스됩니다. 팀 공유 프로젝트 구성에 이상적입니다.

옵션 3에 대한 자세한 내용은 [SessionStart 훅](/en/hooks#persisting-environment-variables)을 참조하세요.

### 훅으로 도구 확장하기

[Claude Code 훅](/en/hooks-guide)을 사용하여 도구 실행 전후에 커스텀 명령을 실행할 수 있습니다.

예를 들어, Claude가 Python 파일을 수정한 후 자동으로 Python 포매터를 실행하거나, 특정 경로에 대한 Write 작업을 차단하여 프로덕션 구성 파일 수정을 방지할 수 있습니다.

## 관련 문서

* [신원 및 접근 관리](/en/iam#configuring-permissions) - 권한 시스템 개요 및 allow/ask/deny 규칙 상호작용 방식
* [도구별 권한 규칙](/en/iam#tool-specific-permission-rules) - Bash, Read, Edit, WebFetch, MCP, Task 도구의 상세 패턴, 보안 제한사항 포함
* [Managed 설정](/en/iam#managed-settings) - 조직용 Managed 정책 구성
* [문제 해결](/en/troubleshooting) - 일반적인 구성 문제에 대한 해결책


---

> 이 문서의 네비게이션 및 기타 페이지를 찾으려면 https://code.claude.com/docs/llms.txt 에서 llms.txt 파일을 가져오세요.
