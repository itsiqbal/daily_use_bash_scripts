#!/bin/bash

while true; do
  echo -n "Enter port number to kill (or 0 to exit): "
  read port

  if [[ "$port" == "0" ]]; then
    echo "Exiting script."
    break
  fi

  pid=$(lsof -t -i :$port)

  if [[ -z "$pid" ]]; then
    echo "⚠️  No process found running on port $port."
  else
    kill -9 $pid
    echo "✅ Port $port cleared successfully (PID: $pid)."
  fi

  echo "---------------------------------------"
done
