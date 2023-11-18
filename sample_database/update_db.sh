#!/bin/bash

# Variables
CSV_FILE="players.csv"
CMD_FILE="sql_cmd"

# Overwrite the cmd file, delete all Players
echo "DELETE FROM Players; " > "$CMD_FILE"

# Append player insertion commands
echo -n "INSERT INTO Players (PlayerId, Firstname, Surname, Email, Gender, Handicap) VALUES " >> "$CMD_FILE"

# Read the CSV file and process each line
while IFS=, read -r playerId firstname surname email gender handicap || [[ -n "$playerId" ]]
do
  echo -n "($playerId, '$firstname', '$surname', '$email', '$gender', $handicap)," >> "$CMD_FILE"
done < "$CSV_FILE"

# Finalise SQL command for players, delete all Games
sed -i '$ s/,$/;/' "$CMD_FILE"
echo "DELETE FROM Games; " >> "$CMD_FILE"

# Declare an associative array to hold player data
declare -A playerData

# Read player data into associative array
while IFS=, read -r playerId firstname surname email gender handicap
do
  playerData["$playerId"]="$firstname $surname $gender/$handicap"
done < "$CSV_FILE"

# Append game creation commands
echo -n "INSERT INTO Games (GameId, Captain, Player2, Player3, Player4, GameTime, GameCard) VALUES " >> "$CMD_FILE"
for i in {1..12}
do
    readarray -t playerIds < <(shuf -i 1-36 -n 4)
    game_date=$(date -d "$((RANDOM % 30)) days" +"%Y-%m-%d")
    game_time=$(printf "%02d:%02d:00" $((8 + RANDOM % 8)) $((RANDOM % 60)))
    
    # Create game card string
    gameCard="Game Id: $i\nGame Time: $game_date at $game_time\n\n"
    gameCard+="Captain Id: ${playerIds[0]} ${playerData[${playerIds[0]}]}\n"
    gameCard+="Player2 Id: ${playerIds[1]} ${playerData[${playerIds[1]}]}\n"
    gameCard+="Player3 Id: ${playerIds[2]} ${playerData[${playerIds[2]}]}\n"
    gameCard+="Player4 Id: ${playerIds[3]} ${playerData[${playerIds[3]}]}"
    
    echo -n "($i, ${playerIds[0]}, ${playerIds[1]}, ${playerIds[2]}, ${playerIds[3]}, '$game_date $game_time', '$gameCard')," >> "$CMD_FILE"
done

# Remove last comma from the INSERT INTO Games command
sed -i '$ s/,$/;/' "$CMD_FILE"

# Remove all Windows (CRLF) and Linux (LF) newlines from the file
tr -d '\r\n' < "$CMD_FILE" > "${CMD_FILE}_temp" && mv "${CMD_FILE}_temp" "$CMD_FILE"
