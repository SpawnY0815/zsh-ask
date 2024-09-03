# A lightweight Zsh plugin serves as a ChatGPT API frontend, enabling you to interact with ChatGPT directly from the Zsh.
# https://github.com/Licheam/zsh-ask
# Copyright (c) 2023 Leachim

#--------------------------------------------------------------------#
# Global Configuration Variables                                     #
#--------------------------------------------------------------------#

0=${(%):-%N}
typeset -g ZSH_ASK_PREFIX=${0:A:h}

(( ! ${+ZSH_ASK_REPO} )) &&
typeset -g ZSH_ASK_REPO="https://github.com/Licheam/zsh-ask"

# Get the corresponding endpoint for your desired model.
(( ! ${+ZSH_ASK_API_URL} )) &&
typeset -g ZSH_ASK_API_URL="https://api.openai.com/v1/chat/completions"

# Fill up your OpenAI api key here.
(( ! ${+ZSH_ASK_API_KEY} )) &&
typeset -g ZSH_ASK_API_KEY="sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Default configurations
(( ! ${+ZSH_ASK_MODEL} )) &&
typeset -g ZSH_ASK_MODEL="chatgpt-4o-latest"
(( ! ${+ZSH_ASK_CONVERSATION} )) &&
typeset -g ZSH_ASK_CONVERSATION=false
(( ! ${+ZSH_ASK_INHERITS} )) &&
typeset -g ZSH_ASK_INHERITS=false
(( ! ${+ZSH_ASK_MARKDOWN} )) &&
typeset -g ZSH_ASK_MARKDOWN=false
(( ! ${+ZSH_ASK_STREAM} )) &&
typeset -g ZSH_ASK_STREAM=false
(( ! ${+ZSH_ASK_TOKENS} )) &&
typeset -g ZSH_ASK_TOKENS=800
(( ! ${+ZSH_ASK_HISTORY} )) &&
typeset -g ZSH_ASK_HISTORY=""
(( ! ${+ZSH_ASK_INITIALROLE} )) &&
typeset -g ZSH_ASK_INITIALROLE="system"
(( ! ${+ZSH_ASK_INITIALPROMPT} )) &&
typeset -g ZSH_ASK_INITIALPROMPT="You are a large language model trained by OpenAI. Answer as concisely as possible.\nKnowledge cutoff: {knowledge_cutoff} Current date: {current_date}"

function _zsh_ask_show_help() {
  echo "A lightweight Zsh plugin serves as a ChatGPT API frontend, enabling you to interact with ChatGPT directly from the Zsh."
  echo "Usage: ask [options...]"
  echo "       ask [options...] '<your-question>'"
  echo "Options:"
  echo "  -h                Display this help message."
  echo "  -v                Display the version number."
  echo "  -i                Inherits conversation from ZSH_ASK_HISTORY."
  echo "  -c                Enable conversation."
  echo "  -f <path_to_file> Enable file as query suffix (testing feature)."
  echo "  -m                Enable markdown rendering (glow required)."
  echo "  -M <openai_model> Set OpenAI model to <openai_model>, default sets to gpt-3.5-turbo."
  echo "                    Models can be found at https://platform.openai.com/docs/models."
  echo "  -s                Enable streaming (Doesn't work with -m yet)."
  echo "  -t <max_tokens>   Set max tokens to <max_tokens>, default sets to 800."
  echo "  -u                Upgrade this plugin."
  echo "  -r                Print raw output."
  echo "  -d                Print debug information."
}

function _zsh_ask_upgrade() {
  git -C $ZSH_ASK_PREFIX remote set-url origin $ZSH_ASK_REPO
  if git -C $ZSH_ASK_PREFIX pull; then
    source $ZSH_ASK_PREFIX/zsh-ask.zsh
    return 0
  else
    echo "Failed to upgrade."
    return 1
  fi
}

function _zsh_ask_show_version() {
  cat "$ZSH_ASK_PREFIX/VERSION"
}

function ki() {
    local api_url=$ZSH_ASK_API_URL
    local api_key=$ZSH_ASK_API_KEY
    local conversation=$ZSH_ASK_CONVERSATION
    local makrdown=$ZSH_ASK_MARKDOWN
    local stream=$ZSH_ASK_STREAM
    local tokens=$ZSH_ASK_TOKENS
    local inherits=$ZSH_ASK_INHERITS
    local model=$ZSH_ASK_MODEL
    local history=""
    

    local usefile=false
    local filepath=""
    local requirements=("curl" "jq")
    local debug=false
    local satisfied=true
    local input=""
    local raw=false
    while getopts ":hvcdmsiurM:f:t:" opt; do
        case $opt in
            h)
                _zsh_ask_show_help
                return 0
                ;;
            v)
                _zsh_ask_show_version
                return 0
                ;;
            u)
                if ! which "git" > /dev/null; then
                    echo "git is required for upgrade."
                    return 1
                fi
                if _zsh_ask_upgrade; then
                    return 0
                else
                    return 1
                fi
                ;;
            c)
                conversation=true
                ;;
            d)
                debug=true
                ;;
            i)
                inherits=true
                ;;
            t)
                if ! [[ $OPTARG =~ ^[0-9]+$ ]]; then
                    echo "Max tokens has to be an valid numbers."
                    return 1
                else
                    tokens=$OPTARG
                fi
                ;;
            f)
                usefile=true
                if ! [ -f $OPTARG ]; then
                    echo "$OPTARG does not exist."
                    return 1
                else
                    if ! which "xargs" > /dev/null; then
                        echo "xargs is required for file."
                        satisfied=false
                    fi
                    filepath=$OPTARG
                fi
                ;;
            M)
                model=$OPTARG
                ;;
            m)
                makrdown=true
                if ! which "glow" > /dev/null; then
                    echo "glow is required for markdown rendering."
                    satisfied=false
                fi
                ;;
            s)
                stream=true
                ;;
            r)
                raw=true
                ;;
            :)
                echo "-$OPTARG needs a parameter"
                return 1
                ;;
        esac
    done

    for i in "${requirements[@]}"
    do
    if ! which $i > /dev/null; then
        echo "$i is required."
        satisfied=false
    fi
    done
    if ! $satisfied; then
        return 1
    fi

    if $inherits; then
        history=$ZSH_ASK_HISTORY
    fi
    
    if [ "$history" = "" ]; then
        history='{"role":"'$ZSH_ASK_INITIALROLE'", "content":"'$ZSH_ASK_INITIALPROMPT'"}, '
    fi

    shift $((OPTIND-1))

    input=$*

    if $usefile; then
        input="$input$(cat "$filepath")"
    elif [ "$input" = "" ]; then
        echo -n "\033[32muser: \033[0m"
        read -r input
    fi


    while true; do
        history=$history' {"role":"user", "content":"'"$input"'"}'
        if $debug; then
            echo -E "$history"
        fi
        local data='{"messages":['$history'], "model":"'$model'", "stream":'$stream', "max_tokens":'$tokens'}'
        if ! $raw; then
          echo -n "\033[0;36massistant: \033[0m"
        fi
        local message=""
        local generated_text=""
        if $stream; then
            local begin=true
            local token=""
            
            curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $api_key" -d $data $api_url | while read -r token; do
                if [ "$token" = "" ]; then
                    continue
                fi
                if $debug; then
                    echo -E $token
                fi
                token=${token:6}
                local delta_text=""
                if delta_text=$(echo -E $token | jq -re '.choices[].delta.content'); then
                    begin=false
                    echo -E $token | jq -je '.choices[].delta.content'
                    generated_text=$generated_text$delta_text
                fi
                if (echo -E $token | jq -re '.choices[].finish_reason' > /dev/null); then
                    echo ""
                    break
                fi
            done
            message='{"role":"assistant", "content":"'"$generated_text"'"}'
        else
            local response=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $api_key" -d $data $api_url)
            if $debug; then
                echo -E "$response"
            fi
            message=$(echo -E $response | jq -r '.choices[].message');  
            generated_text=$(echo -E $message | jq -r '.content')
            if $raw; then
                echo -E $response
            elif $makrdown; then
                echo -E $generated_text | glow
            else
                echo -E $generated_text
            fi
        fi
        history=$history', '$message', '
        ZSH_ASK_HISTORY=$history
        if ! $conversation; then
            break
        fi
        echo -n "\033[0;32muser: \033[0m"
        if ! read -r input; then
            break
        fi
    done
}
