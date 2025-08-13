# work related sh
#!/bin/bash

keys="oms ride supper-app"

project_folder_airasia="$HOME/Desktop/projects/airasia"
project_folder="$HOME/Desktop/projects/airasia"


echo "📁 Work Projects:"
i=1
for key in $keys; do
  echo "$i) → $key"
  keys[$i]=$key
  ((i++))
done

echo -n "Enter number or project name: "
read input

# Resolve input to key
if [[ $input =~ ^[0-9]+$ ]]; then
  choice=${keys[$input]}
else
  choice=$input
fi

project_dir="${project_folder_airasia[$choice]}"

if [ -z "$project_dir" ]; then
  echo "❌ Invalid choice."
  exit 1
fi

echo "✅ Selected: $choice → $project_dir"

full_path_dir="$project_dir/$choice"

# Prompt action
echo "What do you want to do?"
select opt in "cd into" "open in VSCode" "open in IntelliJ"; do
  case $opt in
    "cd into")
      cd "$full_path_dir" || exit
      exec $SHELL
      ;;
    "open in VSCode")
      code "$full_path_dir"
      break
      ;;
    "open in IntelliJ")
      idea "$full_path_dir"
      break
      ;;
    *) echo "Invalid option";;
  esac
done
