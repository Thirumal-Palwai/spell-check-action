#!/bin/bash 
set -x

export GH_TOKEN=${INPUT_CI_CD_GITHUB_TOKEN}
export BASESHA=${INPUT_BASESHA}
export HEADSHA=${INPUT_HEADSHA}
export PULLREQUEST=${INPUT_PULLREQUEST}
export PROXY=${INPUT_PROXY}
NEW="0"

if [[ -z "${GH_TOKEN}" ]] ; then
  echo "No value specified for GH_TOKEN"
  exit 1
fi

if [[ -z "${BASESHA}" ]] ; then
  echo "No value specified for BASESHA"
  exit 1
fi

if [[ -z "${HEADSHA}" ]] ; then
  echo "No value specified for HEADSHA"
  exit 1
fi

if [[ -z "${PULLREQUEST}" ]] ; then
  echo "No value specified for PULLREQUEST"
  exit 1
fi

if [[ -n "${PROXY}" ]] ; then
  export http_proxy="$PROXY"
  export https_proxy="$PROXY"
fi

if [ ! -e ".eslintrc" ]; then
  echo ".eslintrc file is missing"
  exit 1
fi

npm i eslint@latest --save-dev
npm i eslint-plugin-import --save-dev
npm i babel-eslint --save-dev
npm i eslint-plugin-angular@latest --save-dev
npm i eslint-plugin-babel@latest --save-dev

getreviewcomment()
{
  curl -H "Authorization: token $GH_TOKEN" "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/pulls/$PULLREQUEST/comments?per_page=100&page=1" > comment
}

deletereviewcomment()
{
  curl -X DELETE -H "Authorization: token $GH_TOKEN" "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/pulls/comments/$1"
}

postreviewcomment()
{
  {
  echo "{"
  echo "\"path\": \"$1\","
  echo "\"line\": $2,"
  echo "\"side\": \"$3\","
  echo "\"commit_id\": \"$HEADSHA\","
  echo "\"body\": \"$4\""
  echo "}"
  } > com.json
  curl -H "Authorization: token $GH_TOKEN" -d @com.json "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/pulls/$PULLREQUEST/comments"
  rm -rf "com.json"
}

poststatus()
{
  {
     echo "{";
     echo "\"state\": \"$1\","
     echo "\"target_url\": \"$ACTIONS_RUNTIME_URL\","
     echo "\"description\": \"$2\","
     echo "\"context\": \"$3\""
     echo "}"
  } > status.json
  curl -H "Authorization: token $GH_TOKEN" -d @status.json "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/statuses/$HEADSHA"
  rm -rf status.json
}

getreviewcomment
grep -E '^    "id"|^    "body"' comment > filtered
while read -r line
do
  if echo "$line" | grep -E '^"id": ' > /dev/null; then
    id=$(echo "$line" | awk -F": " '{print $2}')
  fi
  if echo "$line" | grep -E '^"body": ' > /dev/null; then
    body=$(echo "$line" | awk -F": " '{print $2}')
  fi
  if [[ -n "$id" && -n "$body" ]]; then
    if echo "$body" | grep -E "ESLINT" >/dev/null; then
      echo "Deleting old comment with $id"
      deletereviewcomment "$id"
    fi
    unset id
    unset body
  fi
done < filtered
rm -rf filtered comment

git diff --name-status --diff-filter=AMRC "$BASESHA".."$HEADSHA" | grep -E "*\.js$" > filelist
if [ -s filelist ]; then
  while read -r line
  do
    i=$(echo "$line" | awk '{print $NF}')
    if echo "$line" | grep -E "^M" > /dev/null;then
      changed=""
      for dd in $(git diff -U0 "$BASESHA".."$HEADSHA" -p "$i" | grep -E "^@@" | awk -F"+" '{print $2}' | awk -F" " '{print $1}')
      do
        if echo "$dd" | grep "," > /dev/null; then
          num=$(echo "$dd" | awk -F"," '{print $1}')
          iter=$(echo "$dd" | awk -F"," '{print $2}')
          END=$((num+iter))
          for (( t="$num"; t < END; t++ ));
          do
            changed="$changed,$t"
          done
        else
          changed="$changed,$dd"
        fi
        unset num
        unset iter
        unset END
      done
      changed="$changed,"
    fi
    issue=""
    eslint "$i" > withpr 2>&1
    if [[ -s withpr && "$?" -ne "0" ]]; then
      NEW=1
      while read -r list 
      do
        if echo "$list" | grep -E "^[0-9]{0,4}:[0-9]{0,3}" > /dev/null; then
          number=$(echo "$list" | awk -F":" '{print $1}')
          if echo "$line" | grep -E "^M" > /dev/null;then
            if echo "$changed" | grep -E ",$number," >/dev/null; then  
              com="ESlint Warning:\n$list"
              postreviewcomment "$i" "$number" "RIGHT" "$com"
            else 
              issue="$issue\n$list"
                   fi
          else
            com="ESlint Warning:\n$list"
            postreviewcomment "$i" "$number" "RIGHT" "$com"    
          fi    
        fi
      done < withpr
      error=$(tail -n 4 withpr | head -n 1 | awk -F" " '{print substr($4,2,10)}')
      warn=$(tail -n 4 withpr | head -n 1 | awk -F" " '{print $6 }')
      if [ -n "$warn" ]; then
        totalwarn=$((totalwarn + warn))
      fi
      if [ -n "$error" ]; then
        totalerror=$((totalerror + error))
      fi
    fi
    rm -rf withpr
    if [ -n "$issue" ]; then
      issue="$i\n$issue"
      fileissue="$fileissue\n$issue"
    fi
    unset issue
  done < filelist
else
  echo "No Js file change"
fi
rm -rf filelist

if [ "$NEW" -eq "1" ]; then
	status="failure"
	desc="Eslint issues found"
else
	status="success"
	desc="No Eslint Issue found"
fi
poststatus "$status" "$desc" ESLINT
