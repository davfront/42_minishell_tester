#!/bin/bash

# Get the directory containing this script
DIR="/mnt/FT/c3/minishell/test"

# Get the directory containing minishell
MS_DIR="/mnt/FT/c3/minishell"

# Move to minishell directory
cd $DIR

# Initialize log file
log="$DIR/log.txt"
printf "" > "$log"

function test_commands() {

    # Get the commands file path from the function arguments
    test="$1"
    test_file="$DIR/tests/${test}.txt"
    echo ""
    echo -n "$test"| tr '[:lower:]' '[:upper:]'
    if [ ! -r "$test_file" ]; then
        echo ": no file found"
        return 1
    fi
    
    # Read the commands from the file
    commands=()
    while read -r cmd; do
    commands+=("$cmd")
    done < "$test_file"

    # Get the total number of commands
    total=${#commands[@]}
    printf " (%s tests)\n" "$total"
    
    # Initialize counters
    passed=0
    failed=0

    # Initialize command ID
    id=1

    # Initialize result string
    result="OK"

    # Loop over the list of commands
    for cmd in "${commands[@]}"; do

        cmd="${cmd//' && '/$'\n'}"

		# Capture output and exit code of minishell in file out1
		cd $MS_DIR
        "$MS_DIR/minishell" <<< $cmd$'\n'exit 2> "$DIR/err1" > "$DIR/out1"
		exit1=$?
        cd $DIR

        # Capture output and exit code of /bin/bash in file out2
		cd $MS_DIR
        bash <<< $cmd$'\n'exit 2> "$DIR/err2" > "$DIR/out2"
        exit2=$?
        cd $DIR

        # Clean out1
        sed -i 's/\x1b\[[0-9;]*[mG]//g' out1 # remove colors
        sed -i '/^exit$/d' out1 # remove exit output
        sed -zi 's/minishell> exit\n//g' out1 # remove exit prompt
        sed -i '/^minishell> /d' out1 # remove prompts

        # Clean err1
        sed -i 's/^minishell: //' err1 # remove prompt string
        sed -i '/^$/d' err1 # remove empty lines

        # Clean err2
        sed -ri 's/^bash: line [0-9]+: //' err2 # remove prompt string
        sed -i "s/^\`.*//" err2 # remove command
        sed -i '/^$/d' err2 # remove empty lines

        # Compare the contents of files out1 and out2
        if cmp -s out1 out2 && [[ "$exit1" -eq "$exit2" ]] && cmp -s err1 err2; then
            result="OK"
            passed=$((passed+1))
            printf "\033[32m%s.%s\033[0m " "$id" "$result"
        else
            result="KO"
            failed=$((failed+1))
            printf "\033[31m%s.%s\033[0m " "$id" "$result"

            
            printf "==============================================================\n" >> "$log"
            printf "%3s. [KO] %s\n" "$id" "$cmd" >> "$log"
            printf "==============================================================\n\n" >> "$log"

            if ! cmp -s out1 out2; then
                printf "OUTPUT MISMATCH !!!\n\n" >> "$log"
                printf "minishell output:\n" >> "$log"
                cat out1 | cat -e >> "$log"
                printf "\n" >> "$log"
                printf "bash output:\n" >> "$log"
                cat out2 | cat -e >> "$log"
                printf "\n" >> "$log"
            fi

            if [[ "$exit1" -ne "$exit2" ]]; then
                printf "EXIT CODE MISMATCH !!!\n\n" >> "$log"
                printf "minishell exit code: %s\n" "$exit1" >> "$log"
                printf "bash exit code: %s\n" "$exit2" >> "$log"
                printf "\n" >> "$log"
            fi
            
            if ! cmp -s err1 err2; then
                printf "STDERR MISMATCH !!!\n\n" >> "$log"
                printf "minishell stderr:\n" >> "$log"
                cat err1 >> "$log"
                printf "\n" >> "$log"
                printf "bash stderr:\n" >> "$log"
                cat err2 >> "$log"
                printf "\n" >> "$log"
            fi
        fi

		# Increment command ID
		id=$((id+1))
	done

	# Print breakline
	echo ""

	# Clean up temporary files
	rm -f $DIR/out1 $DIR/out1.tmp $DIR/out2 $DIR/err1 $DIR/err2

	# Compute and print summary
	percentage=$(awk "BEGIN {printf \"%.0f\", $passed / $total * 100}")
	echo "Passed: $passed / $total ($percentage%)"
	
	# Print breakline
	echo -ne "\n"
}

# Test the commands using the test_commands function
if [ $# -eq 0 ]; then
    test_files=$(ls tests/*.txt | xargs -I {} basename {} .txt)
else
    test_files=$@
fi

for test_file in $test_files; do
    test_commands $test_file
done
