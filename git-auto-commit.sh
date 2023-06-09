#!/bin/bash

COMMIT_LINT_TYPES="build,ci,docs,feat,fix,perf,refactor,revert,style,test"
COMMIT_LINT_FORMAT="<type>(<scope>): <subject>"

jaPrompt() {
    cat <<-END
あなたは日本人のエンジニアです。
これからGitの差分をお見せしますので、コミットメッセージを考えてください。
条件:
- 出力は、Commitlintに準拠した1行のテキストでなければなりません。
- 出力は、コミットメッセージのみで、他は何も出力する必要はありません。
- コミットメッセージは、簡潔で説明的で、1文でなければなりません。
- フォーマットは\`${COMMIT_LINT_FORMAT}\`でなければなりません。
<type> は次のいずれかでなければなりません: ${COMMIT_LINT_TYPES}
<scope> はオプションですが、含まれている場合は丸括弧で囲み、英語でなければなりません。
<subject> は日本語でなければなりません。
END
}

enPrompt() {
    cat <<-END
You are an engineer.
I will show you the diff of Git, so please think about the commit message.
Conditions:
- The output must be a single line of text that complies with Commitlint.
- The output must be only the commit message, and nothing else.
- The commit message must be concise and descriptive, and must be a single sentence.
- The format must be \`${COMMIT_LINT_FORMAT}\`.
<type> must be one of: ${COMMIT_LINT_TYPES}
<scope> is optional, but if included, it must be enclosed in parentheses and be in English.
<subject> must be in English.
END
}

generateCommitMessage() {
    lang=$1
    diffString=$2
    openaiApiKey=$3
    if [ "${lang}" = "ja" ]; then
        prompt=$(jaPrompt)
    else
        prompt=$(enPrompt)
    fi
    prompt=$(echo ${prompt} | jq -R . | sed -e 's/^"//' -e 's/"$//')
    diffString=$(echo ${diffString} | jq -R . | sed -e 's/^"//' -e 's/"$//')
    payload='{"messages": [{"content": "'\`\`\`diff\\n${prompt}\\n\`\`\`'", "role": "system"},{"content": "'${diffString}'", "role": "user"}],"model": "gpt-3.5-turbo"}'
    jsonPayload=$(echo "${payload}" | jq -c .)
    response=$(curl -s -X POST \
        -H "Authorization: Bearer ${openaiApiKey}" \
        -H "Content-Type: application/json" \
        -d "${jsonPayload}" \
        "https://api.openai.com/v1/chat/completions")
    commitMessage=$(echo "$response" | jq -r '.choices[0].message.content')
    commitMessage=$(echo "${commitMessage}" | head -n 1)
    echo "${commitMessage}"
}

green() {
    message=$1
    echo -e "\033[32m${message}\033[0m"
}

red() {
    message=$1
    echo -e "\033[31m${message}\033[0m"
}

blue() {
    message=$1
    echo -e "\033[34m${message}\033[0m"
}

commit() {
    commitMessage=$1
    git commit -m "${commitMessage}"
    echo "$(green Success! committed)"
}

editAndCommit() {
    commitMessage=$1
    editor=${EDITOR:-vi}
    echo "${commitMessage}" >.git/COMMIT_EDITMSG
    "${editor}" .git/COMMIT_EDITMSG
    if [ $? -eq 0 ]; then
        editedCommitMessage=$(cat .git/COMMIT_EDITMSG)
        commit "${editedCommitMessage}"
    else
        echo "$(red Commit cancelled.)"
    fi
}

main() {
    lang=${1:-en}
    if [ "${lang}" != "en" ] && [ "${lang}" != "ja" ]; then
        echo "$(red Error:) Invalid language. Please specify 'en' or 'ja'."
        return
    fi
    diffString=$(git diff --cached)
    openaiApiKey=${OPENAI_API_KEY}
    if [ -z "${openaiApiKey}" ]; then
        echo "$(red Error:) No OpenAI API key found. Please set the OPENAI_API_KEY environment variable."
        echo -e "$(green Hint:) export OPENAI_API_KEY=<your-api-key>"
        return
    fi
    if [ -n "${diffString}" ]; then
        while true; do
            echo -e "$(blue generating\ commit\ message...)"
            commitMessage=$(generateCommitMessage "${lang}" "${diffString}" "${openaiApiKey}")
            echo -e "$(green 'Commit Message:')\n$(blue [\ )${commitMessage}$(blue \ ])"
            read -p "Commit? [y/e/r/n] " answer
            case ${answer} in
            y)
                commit "${commitMessage}"
                break
                ;;
            e)
                editAndCommit "${commitMessage}"
                break
                ;;
            r) ;; # retry
            *)
                echo "Commit cancelled."
                break
                ;;
            esac
        done
    else
        echo "$(red Error:) No staged changes found."
    fi
}

main "${@}"
