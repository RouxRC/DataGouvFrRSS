#!/bin/bash

cd $(echo $0 | sed 's#/[^/]*$##')

touch data.gouv.fr.rss last.html
curl -s "https://www.data.gouv.fr/fr/datasets/recent" > recent.html

if ! diff last.html recent.html |
  grep "^>" > /dev/null; then
    rm -f recent.html
    exit 0
fi

now=$(date -R)
date=""
title=""
link=""
dom="data.gouv.fr"
url="https://www.$dom"

echo "<?xml version=\"1.0\"?>
<rss version=\"2.0\">
 <channel>
  <title>$dom RSS</title>
  <link>$url/fr/datasets/recent</link>
  <description>Les derniers jeux de données publiés sur $dom</description>
  <pubDate>$now</pubDate>
  <generator>RegardsCitoyens https://github.com/RouxRC/DataGouvFrRSS</generator>" > data.gouv.fr.rss

for page in $(seq 5); do

  if [ $page -ne 1 ]; then
    curl -s "$url/fr/datasets/recent?page=$page" > recent.html
  fi

  cat recent.html                                   |
    tr '\n' ' '                                     |
    sed 's/\(<li class="search-result\)/\n\1/g'     |
    sed 's/\s\+/ /g'                                |
    sed 's/<ul class="pagination">.*$//'            |
    sed 's#\(href="\)\([^"]\+\)"#\1'"$url"'\2"#g'   |
    grep 'dataset-result'                            |
    while read line; do
      author=""
      if echo $line | grep '/img/placeholder_producer.png' > /dev/null; then
        author="citoyen"
      elif echo $line | grep '<img alt="' > /dev/null; then
        author=$(echo $line | sed 's/^.*<img alt="//' | sed 's/".*$//' | sed "s/&#39;/'/g")
        if echo $line | grep '/img/certified-stamp.png' > /dev/null; then
          author="$author (certifié)"
        fi
      fi
      title=$(echo $line | sed 's/^.*<h4>\s*<a[^>]*title="//' | sed 's/".*$//' | sed "s/&#39;/'/g")
      link=$(echo $line | sed 's/^.* href="//' | sed 's/".*$//')
      desc=$(echo $line | sed 's/^.*result-description">//' | sed 's#</div>\s*</div>.*$##')
      echo "  <item>
     <title>$title</title>
     <link>$link</link>
     <description><![CDATA[$desc]]></description>
     <author>$author</author>
  </item>" >> data.gouv.fr.rss
    done

  if [ $page -eq 1 ]; then
    mv -f recent.html last.html
  else
    rm -f recent.html
  fi

done

echo " </channel>
</rss>" >> data.gouv.fr.rss

#git commit last.html data.gouv.fr.rss -m "update rss"
#git push

