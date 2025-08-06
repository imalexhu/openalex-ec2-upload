#!/bin/bash
for session in $(screen -ls | grep -o '[0-9]*\.[a-zA-Z_]*'); do
    echo "Killing session: $session"
    screen -X -S $session quit
done
echo "All screen sessions terminated"
