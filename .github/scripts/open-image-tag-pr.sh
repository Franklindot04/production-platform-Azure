#!/usr/bin/env bash
# Commits the changed image tag to a branch and opens the pull request.
# The tag in gitops/dev/values/sample-service.yaml must already be changed in
# the working tree.
#
# Environment: TAG (full commit SHA), RUN_URL, GITHUB_REPOSITORY_OWNER,
# RUNNER_TEMP and GH_TOKEN.
#
# The branch is named after the short SHA, so it can exist already:
#   - no branch on the remote: push it.
#   - the branch holds the same change (same tree on the same parent): do not
#     push.
#   - the branch holds something else: replace it with a force push that is
#     checked against the commit that was read from the remote.
# The pull request is opened in every case. If one is already open for the
# branch, it is used. Open pull requests for earlier tags are closed.
set -euo pipefail

: "${TAG:?}" "${RUN_URL:?}" "${GITHUB_REPOSITORY_OWNER:?}" "${RUNNER_TEMP:?}"

file="gitops/dev/values/sample-service.yaml"
short="${TAG:0:7}"
branch="chore/sample-service-image-${short}"
owner="$(printf '%s' "$GITHUB_REPOSITORY_OWNER" | tr '[:upper:]' '[:lower:]')"

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git switch -c "$branch"
git add "$file"
git commit -q -m "bump the sample service image to ${short} (#34)"

remote_sha="$(git ls-remote --heads origin "refs/heads/${branch}" | cut -f1)"
if [ -z "$remote_sha" ]; then
  git push origin "$branch"
else
  git fetch -q origin "refs/heads/${branch}:refs/remotes/origin/${branch}"
  if [ "$(git rev-parse "origin/${branch}^{tree}")" = "$(git rev-parse 'HEAD^{tree}')" ] &&
    [ "$(git rev-parse "origin/${branch}^")" = "$(git rev-parse 'HEAD^')" ]; then
    echo "The branch ${branch} already holds this change. Not pushing."
  else
    echo "The branch ${branch} holds something else. Replacing it."
    git push --force-with-lease="refs/heads/${branch}:${remote_sha}" origin "$branch"
  fi
fi

existing="$(gh pr list --head "$branch" --state open --json number --jq '.[0].number // empty')"
if [ -n "$existing" ]; then
  new="$existing"
  echo "Pull request #${new} is already open for ${branch}."
else
  cat >"${RUNNER_TEMP}/body.md" <<EOF
## Linked issue

Refs #34

## What changed

- The image tag in \`${file}\` changes to \`${TAG}\`. The run ${RUN_URL} built that commit and pushed it to \`ghcr.io/${owner}/sample-service\`.

## How it was tested

- The run above built the image from \`applications/sample-service\` and pushed it with this tag.
- The diff is one line in one file.

## Not tested

- That the cluster can pull the image. The package must be public for an anonymous pull.
- That Argo CD syncs the change.
- The pull request checks do not run on this pull request, because it was created with the built-in token.

## Limitations

- It changes the tag only. It does not check the image.
- An open pull request for an earlier tag is closed when this one is opened.
EOF
  url="$(gh pr create --base main --head "$branch" \
    --title "Bump the sample service image to ${short}" \
    --body-file "${RUNNER_TEMP}/body.md")"
  new="${url##*/}"
fi

for n in $(gh pr list --state open --json number,headRefName \
  --jq ".[] | select(.headRefName | startswith(\"chore/sample-service-image-\")) | select(.headRefName != \"${branch}\") | .number"); do
  gh pr close "$n" --comment "Superseded by #${new}."
done
