#!/bin/bash

# Clone the Flutter repository
git clone https://github.com/flutter/flutter.git

# Add Flutter to the PATH
export PATH="$PATH:`pwd`/flutter/bin"

# Run flutter doctor to verify the installation
flutter doctor

# Build the web app
flutter build web
