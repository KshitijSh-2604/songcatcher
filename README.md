<p align="center">
  <img align="center" width="220" height="220" alt="SongCatcher Logo" src="assets/images/logo1.png" />
</p>

# SongCatcher.io 🎵 🚀

> Hear the beat. Catch the song.

**SongCatcher.io** is a high-octane, real-time multiplayer music guessing game. Compete with friends and music lovers worldwide to identify tracks from tiny audio snippets. The faster you catch it, the higher you climb!

---

## 🎮 Core Gameplay

### ⚡ The Progressive Challenge
Every round starts with a tiny **2-second** clip. If no one catches it, the clip length increases, giving you more clues but fewer points.

| Round Stage | Clip Length | Scoring Potential |
|---|---|---|
| 🏎️ **Fast Catch** | 2 Seconds | ⭐⭐⭐⭐⭐ (Max Points) |
| 🛡️ **Stable Catch** | 3-5 Seconds | ⭐⭐⭐ |
| 🐢 **Final Clue** | 8 Seconds | ⭐ |

### 🏆 Arena Features
- **Public & Private Lobbies**: Host your own Arena or join global matches instantly.
- **Real-Time Multiplayer**: Built on Firebase Firestore for sub-second synchronization.
- **Dynamic Skip Logic**: Democratic skipping — requires more than half the players to vote. Skips are limited based on game length.
- **Interactive Chat & Reactions**: 
    - **Lobby Chat**: Strategize before the game starts.
    - **In-Game Chat**: Chat with others even after you've caught the song (Green messages).
    - **Reactions**: Long-press any message to react with emojis (👌😂🤣❤️😭🤓💀😦😎🤖). Reactions stack for visibility.
- **Customization**: 
    - **Dice Button**: Randomize your avatar config instantly in the lobby.
    - **Consistent Identity**: Your chosen name and avatar follow you throughout the match.

---

## 🌍 Music Categories & Eras
Choose your vibe and era to battle in your favorite genre:
- 🇮🇳 **Bollywood** (Retro Classics to Modern Hits)
- 🌾 **Punjabi** (Bhangra & Pop)
- 🇺🇸 **English / International** (Global Chart-toppers)
- 🗓️ **Smart Era Filtering**: Play hits from the **1950s** all the way to **Now**. Our smart filter detects original release years even in modern compilations.

---

## 🌟 Daily Challenges
Test your skills against the world in the **Global Daily Arena**.
- **5 Mystery Songs**: Everyone gets the same songs every day.
- **Global Leaderboard**: Optimized sorting (Correct Count > Tries > Time).
- **Daily Rewards**: The top 20 players earn **MusCoins** at 11:59 PM IST.
- **lockout Period**: Maintenance from 11:55 PM to 12:00 AM for payout processing.

---

## 🪙 MusCoins & Economy
Earn **MusCoins** by winning matches and dominating the Daily Challenges.
- **Current Uses**: Track your standing and prestige.
- **Planned Marketplace**: Spend your coins on custom avatars, profile themes, and exclusive SFX.

---

## 🛠️ Tech Stack & Optimization
- **Frontend**: Flutter (3.24+) with **Riverpod** for rock-solid state management.
- **Backend**: Firebase Firestore (Real-time DB) & Firebase Auth.
- **Networking**: Path-based URL strategy (No `#` in URLs) with custom SPA routing for GitHub Pages.
- **Audio**: `just_audio` with smart pre-loading and silence-offset detection.
- **Performance**: High-frequency UI elements (Visualizers, Timers) are isolated with `RepaintBoundary` to maintain 60FPS.

---

## 🚀 Deployment (Beta Testing)
The project is optimized for **GitHub Pages**.
- **Direct Join Links**: Copy the lobby URL and share it. Friends can join instantly—even without an account (Auto-Guest login).
- **SPA Support**: Custom `404.html` handling ensures direct links and refreshes work perfectly.

---

## 🤝 Community & Vision
SongCatcher is built for the community. Our vision is to create the ultimate social platform for music discovery and fandom competition.

**Catch the song before anyone else.** 🏆🎤✨
