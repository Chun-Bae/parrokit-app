---
name: github-ghost-branch-cleanup
description: >-
  Diagnoses and removes "ghost" branches that GitHub's Branches page still lists
  (usually `claude/*` branches from cloud sessions) although the git ref is gone
  (404, `remote ref does not exist`, trash icon does nothing). Use when the user
  says a remote branch will not disappear, shows a 404 but is still listed, or
  asks to clean up leftover claude/* branches.
---
# GitHub Ghost Branch Cleanup

원격에서 브랜치가 안 지워진다는 말을 로컬 `origin/*` 추적 ref 문제로 단정하지 않는다.
먼저 서버 상태와 UI 화면을 구분해서 본다.

## 겪었던 상황

- 머지된 PR의 `claude/*` 브랜치(자동 삭제됨)와 PR 없는 `claude/*` 브랜치가
  웹 Branches 페이지에만 남았다.
- 그 브랜치를 열면 404, 휴지통 아이콘은 반응 없음, `git push --delete`는
  `remote ref does not exist`.
- 로컬 추적 ref 문제라고 먼저 답했다가 틀렸다. 스크린샷으로 UI에 보이는 걸 확인한 뒤에야 GitHub 쪽 목록 불일치로 판단했다.

## 진단

1. 서버 실제 상태: `git ls-remote --heads origin`, GitHub MCP `list_branches`.
2. 특정 브랜치 ref: `get_file_contents`에 `ref=refs/heads/<branch>`로 조회해 404인지 본다.
3. 사용자 화면(스크린샷)에는 보이는데 1~2에 없으면 UI 인덱스만 남은 유령 항목이다.
4. 1~2에도 있으면 진짜 브랜치다. 일반 삭제 절차를 따른다.
5. 로컬에서만 보이면(`git branch -r`) `git fetch --prune`이면 된다.
   자동화는 `git config --global fetch.prune true`.

## 해결: 만들었다 지우기

유령 항목은 같은 이름의 ref를 잠깐 만들었다 지우면 목록이 정리된다
(이 저장소에서 실제로 정리됨).

1. 사용자에게 먼저 확인받는다. 원격을 건드리는 작업이다.
2. GitHub MCP `create_branch`로 기본 브랜치에서 같은 이름을 만든다(새 코드 없음, 포인터만).
3. 삭제는 **사용자가** 한다. 웹 UI 휴지통이나 로컬에서:
   `git push origin --delete <branch> [<branch> ...]`
4. 클라우드 세션에서는 지정 브랜치 외 삭제 push가 프록시 403으로 막힌다.
   정책 거부이므로 재시도·우회하지 않는다. 그래서 2번만 하고 3번을 사용자에게 넘긴다.
5. 사용자가 목록이 깨끗해졌는지 확인하면 끝이다.

## 주의

- 만들기만 하고 삭제를 못 하면 진짜 브랜치가 남는다. 반드시 사용자에게 삭제를 안내하고 상태를 명시한다.
- 기존 브랜치, PR, 사용자 데이터는 건드리지 않는다.
- 그래도 안 되면 GitHub Support에 문의한다. 첨부할 것: UI에는 보이고
  API·`ls-remote`에는 없음, git delete는 `remote ref does not exist`, 저장소와 브랜치 이름.
