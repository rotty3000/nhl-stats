#!/usr/bin/bash

current_year=$(date +"%Y")
draft_years=()
current_year_draft_key="$((current_year-1))${current_year}"

echo "current_year=$current_year"
echo "current_year_draft_key=$current_year_draft_key"

for i in $(seq 1963 $current_year); do
    # echo $i
    draft_years+=("$i")
done

# draft_years=("1970")
# echo "draft_years=${draft_years[*]}"

rm -rf generated output
mkdir -p generated output
echo "Year, Games Played" >> generated/games_played_per_draft_year.csv

for draft_year in "${draft_years[@]}"; do
    start=0
    limit=50

    until [ "$start" -eq -1 ]; do
        # echo "Fetching $draft_year ($start:$limit)"

        result=$(
            curl \
                -s \
                --get \
                -H "Origin: https://www.nhl.com" \
                -H "Referer: https://www.nhl.com" \
                -H "User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/114.0" \
                --data-urlencode "isAggregate=true" \
                --data-urlencode "isGame=false" \
                --data-urlencode "start=${start}" \
                --data-urlencode "limit=${limit}" \
                --data-urlencode "factCayenneExp=gamesPlayed>=1" \
                --data-urlencode "cayenneExp=draftRound>=1 and draftYear=${draft_year} and gameTypeId=2 and seasonId<=${current_year_draft_key} and seasonId>=19171918" \
                "https://api.nhle.com/stats/rest/en/skater/summary" \
            | jq '.'
        )

        if [ "$start" -eq 0 ]; then
            echo "$result" > "output/skater-$draft_year.json"
        else
            DATA=$(jq '.data' <<< $result)
            # echo "DATA=$DATA"
            result=$(jq --argjson newData "$DATA" '.data += $newData' "output/skater-$draft_year.json")
            echo "$result" > "output/skater-$draft_year.json"
        fi

        total_number_of_results=$(jq -r '.total' "output/skater-$draft_year.json")
        actual_number_of_results=$(jq -r '.data | length' "output/skater-$draft_year.json")

        # echo " total_number_of_results=$total_number_of_results"
        # echo " actual_number_of_results=$actual_number_of_results"

        if [ "$total_number_of_results" -gt "$actual_number_of_results" ]; then
            start=$((start+50))
            limit=$((limit+50))

            if [ "$limit" -gt "$total_number_of_results" ]; then
                limit=$total_number_of_results
            fi
        else
            start=-1
        fi
    done

    # games played
    games_played=$(jq -r '[.data[].gamesPlayed | tonumber] | add' "output/skater-$draft_year.json")
    echo " Season games played by players drafted in $draft_year: $games_played"
    echo $draft_year, $games_played >> generated/games_played_per_draft_year.csv
done

gnuplot gnuplot.txt