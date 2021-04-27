#!/bin/bash

# Base indent
IS=( 2 )
WIDTH="$( tput cols )"

while getopts "w:f:i:" opt; do
  case "${opt}" in
    w)
      WIDTH="${OPTARG}"
      ;;
    f)
      FILE="${OPTARG}"
      ;;
    i)
      IS=( "${OPTARG}" )
      ;;
    *)
      ;;
  esac
done

calc_indent() {
  local i indent
  for i in "${IS[@]}" ; do
    indent=$(( indent + i ))
  done
  if ((PARAGRAPH)) ; then
    indent=$(( indent + 2 ))
  fi
  echo "${indent}"
}

parse_token() {
  local TOKEN INDENT
  TOKEN="${1}"
  INDENT="$( calc_indent )"

  # This is a giant shitty hack
  if ((SKIP_INDENT)) ; then
    DO_INDENT=0
    SKIP_INDENT=0
  fi

  if ((FIRST)) && ((DO_INDENT)) ; then
    #shellcheck disable=SC2183,2086
    SPACE="$(printf '%*s' ${INDENT} )"
    echo -n "${SPACE}"
    FIRST=0
    LENGTH=${INDENT}
  fi

  case "${TOKEN}" in
    I\<*)
      if [[ "${TOKEN}" =~ \<([[:print:]]+)\>(.)? ]] ; then
        echo -e -n "\033[33m"
        parse_token "${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
        echo -e -n "\033[0m"
      elif [[ "${TOKEN}" =~ \<([[:print:]]+) ]] ; then
        echo -e -n "\033[33m"
        parse_token "${BASH_REMATCH[1]}"
      fi
      ;;
    B\<*)
      if [[ "${TOKEN}" =~ \<([[:print:]]+)\>(.)? ]] ; then
        echo -e -n "\033[1m"
        parse_token "${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
        echo -e -n "\033[0m"
      elif [[ "${TOKEN}" =~ \<([[:print:]]+) ]] ; then
        echo -e -n "\033[1m"
        parse_token "${BASH_REMATCH[1]}"
      fi
      ;;
    F\<*)
      if [[ "${TOKEN}" =~ \<([[:print:]]+)\>(.)? ]] ; then
        echo -e -n "\033[36m"
        parse_token "${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
        echo -e -n "\033[0m"
      elif [[ "${TOKEN}" =~ \<([[:print:]]+) ]] ; then
        echo -e -n "\033[36m"
        parse_token "${BASH_REMATCH[1]}"
      fi
      ;;
    C\<*)
      if [[ "${TOKEN}" =~ \<([[:print:]]+)\>(.)? ]] ; then
        echo -e -n "\""
        parse_token "${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
        echo -e -n "\""
      fi
      ;;
    L\<*)
      if [[ "${TOKEN}" =~ \<([[:print:]]+)\> ]] ; then
        echo -n "${BASH_REMATCH[1]}"
      fi
      ;;
    E\<*)
      if [[ "${TOKEN}" =~ \<([[:alpha:]]+)\> ]] ; then
        case "${BASH_REMATCH[1]}" in
          gt)
            echo -n "> "
            ;;
          lt)
            echo -n "< "
            ;;
          verbar)
            echo -n "| "
            ;;
          sol)
            echo -n "/ "
            ;;
          *)
            echo -n "${BASH_REMATCH[1]} "
            ;;
        esac
        if [ -n "${BASH_REMATCH[2]}" ]; then
          parse_token "${BASH_REMATCH[2]}"
        fi
      fi
      ;;
    *)
      if [[ "${TOKEN}" =~ ([[:print:]]+)\>(\.)? ]] ; then
        TOKEN="${BASH_REMATCH[1]}"
        CLOSE="\033[0m"
      fi

      T="${#TOKEN}"
      LENGTH=$((LENGTH + T))
      if [ "${LENGTH}" -gt "${WIDTH}" ]; then
        echo -n -e "\n"
        #shellcheck disable=SC2183,2086
        SPACE="$(printf '%*s' $INDENT)"
        echo -n "${SPACE}"
        if ((PARAGRAPH)) && ((DO_INDENT)); then
          #shellcheck disable=SC2183,2086
          SPACE="$(printf '%*s' $BASE_INDENT)"
          echo -n "${SPACE}"
        fi
        LENGTH=0
      fi
      echo -e -n "${TOKEN} "
      echo -e -n "${CLOSE}"
  esac
}


while read -r line ; do
  FIRST=1
  PARAGRAPH=0
  DO_INDENT=1
  # special-case *, because bash sucks
  line="${line/item \*/emptyitem}"
  case "${line}" in
    =head*)
      NL=0
      SPACE=
      if [[ "${line}" =~ head(.)\ ([[:print:]]+) ]] ; then
        if [ "${BASH_REMATCH[1]}" -gt 1 ]; then
          IS+=( $(( BASH_REMATCH[1] - 1 )) )
          #shellcheck disable=SC2183,2086
          SPACE="$(printf '%*s' "${BASH_REMATCH[1]}" )"
        fi
        echo -e "${SPACE}\033[1m${BASH_REMATCH[2]}\033[0m"
      fi
      ;;
    =over*)
      NL=0
      IS+=( "${line/=over /}" )
      if [ "${#IS}" -gt 0 ] ; then
        NL_ON_BACK=1
      fi
      ;;
    =emptyitem)
      NL=0
      parse_token '*'
      FIRST_AFTER=0
      SKIP_INDENT=1
      NL_ON_BACK=0
      continue
      ;;
    =item*)
      NL=1
      item=${line/=item /}
      oifs=$ifs
      ifs=$'\x20'
      for token in ${item} ; do
        parse_token "${token}"
      done
      ifs=$oifs
      FIRST_AFTER=1
      ;;
    =back)
      NL=0
      unset "IS[-1]"
      if ((NL_ON_BACK)) ; then
        NL_ON_BACK=0
        echo -n -e "\n"
      fi
      ;;
    =cut|=pod)
      NL=0
      # no-ops for now
      ;;
    "")
      if ((FIRST_AFTER)) ; then
        FIRST_AFTER=0
        continue
      fi
      if ((PARAGRAPH)) ; then
        NL=1
      fi
      ;;
    *)
      PARAGRAPH=1
      NL=1
      OIFS=$IFS
      IFS=$'\x20'
      for token in ${line} ; do
        parse_token "${token}"
      done
      IFS=$OIFS
      ;;
  esac

  if ((NL)); then
    echo -n -e "\n"
  fi
done <"${FILE}"
