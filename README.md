# Stream v3

PC Remote + Screen Stream + Game Controller for iPhone.

**Server**: `cd server && pip install -r requirements.txt && python server.py`

**Build IPA**: Push to GitHub → Actions → "Build IPA" → download artifact.

Or on a Mac: `brew install xcodegen && xcodegen generate && open Stream.xcodeproj`

Info.plist is at the project root, not in sources — no more duplicate output error.
