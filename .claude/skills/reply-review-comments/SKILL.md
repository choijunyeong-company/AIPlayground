---
name: reply-review-comments
description: PR 리뷰 코멘트를 읽고, 푸쉬되지 않은 커밋과 매칭하여 답변 코멘트를 작성합니다.
---

해당 스킬은 GitHub CLI 툴인 `gh`를 활용합니다.

1. 현재 브랜치의 PR을 식별합니다. [참조](#pr-식별)
2. 특정 리뷰어의 리뷰 코멘트를 조회합니다. [참조](#리뷰-코멘트-조회)
3. 푸쉬되지 않은 로컬 커밋 목록을 조회합니다. [참조](#로컬-커밋-조회)
4. 각 리뷰 코멘트와 커밋을 매칭합니다. [참조](#코멘트-커밋-매칭)
5. 매칭 결과를 테이블로 사용자에게 확인 요청합니다. [참조](#확인-요청)
6. 승인된 코멘트들을 PR에 답변으로 작성합니다. [참조](#답변-작성)

# PR 식별

현재 브랜치명을 기준으로 PR을 검색합니다.

```sh
gh pr list --head {현재_브랜치명} --json number,title,url
```

PR이 여러 개이거나 없는 경우 사용자에게 PR 번호를 직접 입력받습니다.

# 리뷰 코멘트 조회

## 호스트 및 레포 정보 획득

```sh
gh api /repos/{owner}/{repo} --hostname {host} --jq '"\(.owner.login)/\(.name)"'
```

호스트를 식별할 수 없는 경우 사용자에게 직접 묻습니다.

## 리뷰 목록 조회

```sh
gh api /repos/{owner}/{repo}/pulls/{pr_number}/reviews --hostname {host}
```

응답에서 지정된 리뷰어(`user.login`)의 review id를 추출합니다.

## 리뷰 코멘트 상세 조회

```sh
gh api /repos/{owner}/{repo}/pulls/{pr_number}/reviews/{review_id}/comments \
  --hostname {host} \
  --jq '.[] | {id, path, line: .original_line, body, in_reply_to_id}'
```

`in_reply_to_id`가 null인 항목만 원본 코멘트로 취급합니다. (null이 아닌 경우 답글)

# 로컬 커밋 조회

원격에 푸쉬되지 않은 로컬 커밋 목록을 조회합니다.

```sh
git log --oneline origin/{현재_브랜치명}..HEAD
```

커밋의 full hash도 함께 조회합니다.

```sh
git log --format="%H %h %s" origin/{현재_브랜치명}..HEAD
```

# 코멘트-커밋 매칭

각 리뷰 코멘트의 내용과 로컬 커밋의 변경사항을 분석하여 매칭합니다.

매칭 기준:
- 리뷰 코멘트가 지적한 파일과 커밋이 수정한 파일의 일치 여부
- 리뷰 코멘트의 요청 내용과 커밋의 변경 내용의 의미적 일치 여부

## 답변 메시지 결정

리뷰 코멘트의 요청 유형에 따라 적절한 답변을 선택합니다:
- 코드 수정/개선 요청 -> "반영했습니다."
- 삭제 요청 -> "요청에 따라 삭제했습니다."
- 이동/이전 요청 -> "반영했습니다."
- 복잡한 리뷰 사항에 대해서는 그 요청에 맞게 답변 메시지를 작성합니다, 명확한 답변 생성이 어려운 경우 사용자에게 직접 입력받도록 합니다.
- 사용자가 별도 답변 형식을 지정한 경우 해당 형식을 따릅니다.

## 커밋 해시 링크 작성

답변 메시지 끝에 커밋 해시를 마크다운 링크로 첨부합니다.
리뷰어가 해시를 클릭하면 해당 커밋의 변경사항을 바로 확인할 수 있도록 PR 커밋 페이지로 연결합니다.
불필요한 경우 커밋 링크 생략도 가능합니다.

형식:
```
{답변 메시지} [{short_hash}]({commit_url})
```

- `short_hash`: 커밋 해시의 앞 7자리
- `commit_url`: `https://{host}/{owner}/{repo}/pull/{pr_number}/commits/{full_hash}`

예시:
```
반영했습니다. [e4b5e47](https://github.nhnent.com/dooray/ios-dooray-service/pull/478/commits/e4b5e474a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6)
```

# 확인 요청

매칭 결과를 아래 형식의 테이블로 사용자에게 보여줍니다.

```
| # | 파일 | 리뷰 내용 | 답변 | 커밋 |
|---|------|-----------|------|------|
| 1 | File.swift | p2) 요청 요약 | 반영했습니다. | abc1234 |
| 2 | View.swift | p3) 요청 요약 | 요청에 따라 삭제했습니다. | def5678 |
```

사용자가 전체 승인하거나, 특정 번호를 선택/제외할 수 있도록 합니다.

# 답변 작성

승인된 코멘트들을 각각 PR의 리뷰 코멘트에 답글로 작성합니다.

```sh
gh api -X POST \
  /repos/{owner}/{repo}/pulls/{pr_number}/comments \
  --hostname {host} \
  -f body="{답변 메시지} [{short_hash}]({commit_url})" \
  -F in_reply_to={comment_id}
```

주의: `/pulls/comments/{comment_id}/replies` 엔드포인트는 GitHub Enterprise에서 동작하지 않을 수 있습니다. `/pulls/{pr_number}/comments`에 `in_reply_to` 파라미터를 사용하는 방식이 안정적입니다.
