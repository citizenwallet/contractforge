#!/bin/bash

# Ensure we're in the project root
# cd "$(dirname "$0")"

# Create a directory for the ABIs if it doesn't exist
mkdir -p abi

# Loop through all contract files
for contract in $(find src -name '*.sol')
do
  # Get the contract name (filename without extension)
  name=$(basename "$contract" .sol)
  
  # Generate ABI and save to file
  forge inspect "$name" abi > "abi/$name.json"
  
  echo "Generated ABI for $name"
done