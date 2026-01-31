#!/bin/bash

# Get weather from wttr.in
# Change location if needed (auto-detect by default or set your city/zip)
LOCATION=""  # Leave empty for auto-detect, or set like "NewYork" or "90210"

# Fetch weather data
weather=$(curl -s "wttr.in/${LOCATION}?format=%c%t")
location=$(curl -s "wttr.in/${LOCATION}?format=%l" | sed 's/,.*$//')

if [ -z "$weather" ]; then
    echo '{"text":"󰼱 N/A","tooltip":"Weather unavailable"}'
else
    echo "{\"text\":\"$weather\",\"tooltip\":\"$location\"}"
fi
